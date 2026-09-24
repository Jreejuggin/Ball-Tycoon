-- StructureSequenceService
-- Server-authoritative controller for the Home Centre structure sequence.
--
-- Replaces the old one-pad-per-structure model. Each plot now has a single
-- pad (Centre02_Home/StructureBuyPad) that walks through the structures in
-- a fixed order, showing the price and identity of whichever one is next.
--
-- The per-slot Slot_*/BuyPad objects still exist and still hold the
-- Activated BoolValues. Those are the paths TycoonProgressService persists
-- against, so they are deliberately left in place - only their scripts are
-- disabled and their geometry hidden.
--
-- All money handling, ownership checks and state writes happen here on the
-- server. The client never sends a purchase request; the pad is driven by
-- Touched, and clients only read state for the floating label and ghost preview.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
-- Purchase order. Index in this list IS the progression order.
local ORDER = {
	"Slot_Walls",
	"Slot_Glass",
	"Slot_LaserDoor",
	"Slot_Roof",
	"Slot_CeilingLights",
}

local COLOR_AFFORDABLE = Color3.new(0, 1, 0)
local COLOR_TOO_EXPENSIVE = Color3.new(0.8, 0.1, 0.1)
-- Match the existing Worker Speed purchase pad: Neon at 0.5 transparency.
-- The shared value keeps every Home Centre structure stage visually consistent.
local PAD_VISIBLE_TRANSPARENCY = 0.5
local PREVIEW_MODE_AVAILABLE = "CentreAvailable"
local PREVIEW_MODE_PURCHASE = "Purchase"
local PURCHASE_COOLDOWN_SECONDS = 1.5
local STEP_OFF_MARGIN = 1.5
local POLL_INTERVAL = 0.5

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------
local function getOwnerPlayer(plot)
	local ownerId = tonumber(plot:GetAttribute("Owner"))
	return ownerId and Players:GetPlayerByUserId(ownerId) or nil
end

local function getCash(player)
	local leaderstats = player and player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Cash")
end

local function getPlayerFromHit(hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character) or nil
end

-- Collect every BasePart belonging to a structure group, anywhere in the plot.
local function collectParts(plot, groupName)
	local parts = {}
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant:GetAttribute("StructureGroup") == groupName then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function setPartsVisible(parts, visible)
	for _, part in ipairs(parts) do
		if part.Parent then
			local originalCanTouch = part:GetAttribute("OrigCanTouch")
			local originalCanQuery = part:GetAttribute("OrigCanQuery")
			local originalCastShadow = part:GetAttribute("OrigCastShadow")
			if type(originalCanTouch) ~= "boolean" then
				originalCanTouch = part.CanTouch
				part:SetAttribute("OrigCanTouch", originalCanTouch)
			end
			if type(originalCanQuery) ~= "boolean" then
				originalCanQuery = part.CanQuery
				part:SetAttribute("OrigCanQuery", originalCanQuery)
			end
			if type(originalCastShadow) ~= "boolean" then
				originalCastShadow = part.CastShadow
				part:SetAttribute("OrigCastShadow", originalCastShadow)
			end

			if visible then
				part.Transparency = part:GetAttribute("OrigTransparency") or 0
				part.CanCollide = part:GetAttribute("OrigCanCollide") or false
				part.CanTouch = originalCanTouch
				part.CanQuery = originalCanQuery
				part.CastShadow = originalCastShadow
			else
				part.Transparency = 1
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.CastShadow = false
			end
		end
	end
end

--------------------------------------------------------------------
-- Per-plot controller
--------------------------------------------------------------------
local function wirePlot(plot)
	local centreSlots = plot:FindFirstChild("CentreSlots")
	local homeCentre = centreSlots and centreSlots:FindFirstChild("Centre02_Home")
	local structureSlots = homeCentre and homeCentre:FindFirstChild("StructureSlots")
	local pad = homeCentre and homeCentre:FindFirstChild("StructureBuyPad")
	local homeActivated = homeCentre and homeCentre:FindFirstChild("Activated")
	local homeStatus = homeCentre and homeCentre:FindFirstChild("Status")

	if not (structureSlots and pad and homeActivated
		and homeStatus and homeStatus:IsA("StringValue")) then
		return false
	end

	local priceLabel = pad:FindFirstChild("PriceLabel")
	local priceText = priceLabel and priceLabel:FindFirstChild("PriceText")

	-- Keep the finished-home message anchored to the retired central pad so it
	-- matches the other camera-facing purchase text in the centre quadrants.
	local completionLabel = pad:FindFirstChild("CompletionLabel")
	if completionLabel and not completionLabel:IsA("BillboardGui") then
		completionLabel:Destroy()
		completionLabel = nil
	end
	if not completionLabel then
		completionLabel = Instance.new("BillboardGui")
		completionLabel.Name = "CompletionLabel"
		completionLabel.Parent = pad
	end
	completionLabel.Adornee = pad
	completionLabel.Size = UDim2.new(7, 0, 3, 0)
	completionLabel.StudsOffset = Vector3.new(0, 5.5, 0)
	completionLabel.AlwaysOnTop = true
	completionLabel.LightInfluence = 0
	completionLabel.Brightness = 1
	completionLabel.MaxDistance = 140
	completionLabel.Enabled = false

	local function configureCompletionText(name, text, color, size, position)
		local label = completionLabel:FindFirstChild(name)
		if label and not label:IsA("TextLabel") then
			label:Destroy()
			label = nil
		end
		if not label then
			label = Instance.new("TextLabel")
			label.Name = name
			label.Parent = completionLabel
		end
		label.BackgroundTransparency = 1
		label.Size = size
		label.Position = position
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.TextWrapped = true
		label.FontFace = Font.new(
			"rbxasset://fonts/families/GothamSSm.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		)
	end

	configureCompletionText(
		"CheckmarkText",
		"✓",
		Color3.fromRGB(80, 255, 120),
		UDim2.new(1, 0, 0.42, 0),
		UDim2.fromScale(0, 0)
	)
	configureCompletionText(
		"MessageText",
		"All Level 1 Home Upgrades Implemented!",
		Color3.new(1, 1, 1),
		UDim2.new(1, 0, 0.58, 0),
		UDim2.fromScale(0, 0.42)
	)

	-- Build the stage table once. Each stage caches the objects it needs so the
	-- polling loop never re-walks the tree.
	local stages = {}
	for index, slotName in ipairs(ORDER) do
		local slot = structureSlots:FindFirstChild(slotName)
		local slotPad = slot and slot:FindFirstChild("BuyPad")
		local activated = slotPad and slotPad:FindFirstChild("Activated")
		local price = slotPad and slotPad:FindFirstChild("Price")
		local group = slot and slot:FindFirstChild("StructureGroup")

		if not (activated and group) then
			warn("[StructureSequenceService] " .. plot.Name
				.. " is missing configuration for " .. slotName .. " - skipping plot.")
			return false
		end

		stages[index] = {
			name = slotName,
			group = group.Value,
			activated = activated,
			price = price and price.Value or 0,
			parts = collectParts(plot, group.Value),
			isVisible = nil,
		}
	end

	local purchaseLocked = false
	local lastSignature

	-- Index of the first unpurchased stage, or nil when everything is bought.
	local function currentStageIndex()
		for index, stage in ipairs(stages) do
			if not stage.activated.Value then
				return index
			end
		end
		return nil
	end

	local function refresh()
		local index = currentStageIndex()
		local centrePurchased = homeActivated.Value
		local owner = getOwnerPlayer(plot)
		local centreAvailable = owner ~= nil
			and not centrePurchased
			and homeStatus.Value == "Available"
		completionLabel.Enabled = centrePurchased and index == nil

		-- Nothing inside the Home Centre is revealed until the quadrant itself
		-- is purchased. Afterwards, saved stage flags restore their geometry.
		for _, stage in ipairs(stages) do
			local shouldBeVisible = centrePurchased and stage.activated.Value
			if stage.isVisible ~= shouldBeVisible then
				stage.isVisible = shouldBeVisible
				setPartsVisible(stage.parts, shouldBeVisible)
			end
		end

		if not centrePurchased then
			-- Available centres advertise only the faint Walls preview. The
			-- structure purchase pad and its price remain fully hidden.
			pad.Transparency = 1
			pad.CanCollide = false
			pad.CanTouch = false
			pad.CanQuery = false
			pad:SetAttribute("CurrentStructure", centreAvailable and stages[1].group or "")
			pad:SetAttribute("StructurePreviewMode", centreAvailable and PREVIEW_MODE_AVAILABLE or "")
			if priceLabel then priceLabel.Enabled = false end
			lastSignature = nil
			return
		end

		if index == nil then
			-- Every structure has been bought, so retire the shared pad.
			pad.Transparency = 1
			pad.CanCollide = false
			pad.CanTouch = false
			pad.CanQuery = false
			pad:SetAttribute("CurrentStructure", "")
			pad:SetAttribute("StructurePreviewMode", "")
			if priceLabel then priceLabel.Enabled = false end
			lastSignature = nil
			return
		end

		local stage = stages[index]
		local cash = getCash(owner)
		local affordable = stage.price == 0 or (cash ~= nil and cash.Value >= stage.price)
		local color = affordable and COLOR_AFFORDABLE or COLOR_TOO_EXPENSIVE

		-- Only touch the cheap-to-change properties every poll; skip the rest
		-- unless the stage actually advanced.
		pad.Color = color
		pad.CanTouch = not purchaseLocked
		if priceText then priceText.TextColor3 = color end

		local signature = stage.name
		if signature ~= lastSignature then
			lastSignature = signature
			pad.Transparency = PAD_VISIBLE_TRANSPARENCY
			pad.CanCollide = false
			pad.CanQuery = true
			pad.Material = Enum.Material.Neon
			pad.Reflectance = 0
			pad.CastShadow = false
			if pad:IsA("UnionOperation") then
				pad.UsePartColor = true
			end
			-- The client PreviewController reads this attribute to pick which
			-- emoji and label to float above the pad.
			pad:SetAttribute("CurrentStructure", stage.group)
			pad:SetAttribute("StructurePreviewMode", PREVIEW_MODE_PURCHASE)
			if priceLabel then priceLabel.Enabled = true end
			if priceText then
				priceText.Text = stage.price == 0 and "FREE" or ("$" .. tostring(stage.price))
			end
		end
	end

	-- Prevent a character that is still standing over the central pad from
	-- buying the next stage as soon as the time cooldown ends.
	local function isCharacterOnPad(character)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return false
		end

		local localPosition = pad.CFrame:PointToObjectSpace(root.Position)
		local halfWidth = (pad.Size.X * 0.5) + STEP_OFF_MARGIN
		local halfDepth = (pad.Size.Z * 0.5) + STEP_OFF_MARGIN
		return math.abs(localPosition.X) <= halfWidth
			and math.abs(localPosition.Z) <= halfDepth
			and localPosition.Y >= -4
			and localPosition.Y <= 8
	end

	pad.Touched:Connect(function(hit)
		if purchaseLocked or not homeActivated.Value then return end

		local index = currentStageIndex()
		if index == nil then return end
		local stage = stages[index]

		local player = getPlayerFromHit(hit)
		if not player or getOwnerPlayer(plot) ~= player then return end

		local cash = getCash(player)
		if stage.price > 0 and (not cash or cash.Value < stage.price) then return end

		purchaseLocked = true
		pad.CanTouch = false
		if stage.price > 0 then
			cash.Value -= stage.price
		end
		stage.activated.Value = true
		local completedAllHomeUpgrades = currentStageIndex() == nil
		refresh()

		PurchaseSoundModule.PlayPurchaseForTarget(player, pad)
		if completedAllHomeUpgrades then
			-- Match the celebration used when a full machine section is completed.
			-- This runs only for the live final purchase, never during save restore.
			PurchaseSoundModule.PlayAreaUnlocked(player, pad)
		end
		if #stage.parts > 0 then
			PurchaseEffectModule.PlayAcrossParts(stage.parts, nil, {
				pointCount = 30,
				totalParticleBudget = 120,
			})
		else
			PurchaseEffectModule.Play(pad.Position + Vector3.new(0, 1.4, 0))
		end

		task.spawn(function()
			task.wait(PURCHASE_COOLDOWN_SECONDS)
			while pad.Parent and isCharacterOnPad(player.Character) do
				task.wait(0.1)
			end

			purchaseLocked = false
			if pad.Parent then
				refresh()
			end
		end)
	end)

	-- React immediately to external writes (save restore, admin tools) rather
	-- than waiting up to POLL_INTERVAL for the next poll.
	for _, stage in ipairs(stages) do
		stage.activated.Changed:Connect(refresh)
	end
	homeActivated.Changed:Connect(refresh)
	homeStatus.Changed:Connect(refresh)
	plot:GetAttributeChangedSignal("Owner"):Connect(refresh)

	refresh()
	task.spawn(function()
		while pad.Parent do
			refresh()
			task.wait(POLL_INTERVAL)
		end
	end)

	return true
end

--------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------
local wired = 0
for _, plot in ipairs(workspace:GetChildren()) do
	if plot.Name:match("^P%d+$") then
		if wirePlot(plot) then
			wired += 1
		end
	end
end

print("[StructureSequenceService] Wired " .. wired .. " plot(s) - "
	.. #ORDER .. "-stage structure sequence on a single pad.")
