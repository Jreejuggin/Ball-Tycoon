-- StructurePurchaseService
-- Central server-authoritative controller for every Home Centre structure slot.
-- Individual StructureBuyPadScript instances only register their own pad here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local StructurePurchaseService = {}
local wiredPads = setmetatable({}, {__mode = "k"})

local COLOR_GREEN = Color3.new(0, 1, 0)
local COLOR_RED = Color3.new(0.8, 0.1, 0.1)
local UPDATE_INTERVAL_SECONDS = 0.5

local function findPlot(instance)
	local current = instance
	while current and current.Parent ~= workspace do
		current = current.Parent
	end
	return current
end

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

function StructurePurchaseService.Wire(pad)
	if wiredPads[pad] then
		return
	end
	if not pad or not pad:IsA("BasePart") then
		warn("StructurePurchaseService requires a BasePart buy pad.")
		return
	end
	wiredPads[pad] = true

	local slot = pad.Parent
	local structureSlots = slot and slot.Parent
	local homeCentre = structureSlots and structureSlots.Parent
	local plot = findPlot(slot)
	if not slot
		or not structureSlots
		or structureSlots.Name ~= "StructureSlots"
		or not homeCentre
		or homeCentre.Name ~= "Centre02_Home"
		or not plot
	then
		warn("Invalid Home Centre structure hierarchy for " .. pad:GetFullName())
		return
	end

	local structureGroup = slot:FindFirstChild("StructureGroup")
	local dependency = slot:FindFirstChild("Dependency")
	local priceObject = pad:FindFirstChild("Price")
	local activated = pad:FindFirstChild("Activated")
	local homeActivated = homeCentre:FindFirstChild("Activated")
	if not structureGroup or not activated or not homeActivated then
		warn("Incomplete structure slot configuration for " .. slot:GetFullName())
		return
	end

	local priceValue = priceObject and priceObject.Value or 10
	local priceLabel = pad:FindFirstChild("PriceLabel")
	local priceText = priceLabel and priceLabel:FindFirstChild("PriceText")
	local nameLabel = pad:FindFirstChild("NameLabel")

	local targetParts = {}
	local originalProperties = {}
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("StructureGroup") == structureGroup.Value then
			table.insert(targetParts, descendant)
			originalProperties[descendant] = {
				Transparency = descendant.Transparency,
				CanCollide = descendant.CanCollide,
			}
		end
	end

	local currentState
	local isProcessingPurchase = false

	local function dependencyMet()
		if not homeActivated.Value then
			return false
		end
		if not dependency or dependency.Value == "" then
			return true
		end

		local dependencySlot = structureSlots:FindFirstChild(dependency.Value)
		local dependencyPad = dependencySlot and dependencySlot:FindFirstChild("BuyPad")
		local dependencyActivated = dependencyPad and dependencyPad:FindFirstChild("Activated")
		return dependencyActivated ~= nil and dependencyActivated.Value
	end

	local function hideStructure()
		for _, part in ipairs(targetParts) do
			if part.Parent then
				part.Transparency = 1
				part.CanCollide = false
			end
		end
	end

	local function revealStructure()
		for _, part in ipairs(targetParts) do
			if part.Parent then
				local original = originalProperties[part]
				part.Transparency = original and original.Transparency or 0
				part.CanCollide = original and original.CanCollide or false
			end
		end
	end

	local function setLabelsEnabled(enabled)
		if priceLabel then
			priceLabel.Enabled = enabled
		end
		if nameLabel then
			nameLabel.Enabled = enabled
		end
	end

	local function updateAffordableColor()
		local owner = getOwnerPlayer(plot)
		local cash = getCash(owner)
		local affordable = priceValue == 0 or (cash ~= nil and cash.Value >= priceValue)
		local color = affordable and COLOR_GREEN or COLOR_RED
		pad.Color = color
		if priceText then
			priceText.TextColor3 = color
		end
	end

	local function calculateState()
		if not homeActivated.Value then
			return "Hidden"
		end
		if activated.Value then
			return "Purchased"
		end
		if dependencyMet() then
			return "Available"
		end
		return "Hidden"
	end

	local function applyState(force)
		local state = calculateState()
		if not force and state == currentState then
			if state == "Available" then
				updateAffordableColor()
			end
			return
		end
		currentState = state

		if state == "Purchased" then
			pad.Transparency = 1
			pad.CanCollide = false
			pad.CanTouch = false
			setLabelsEnabled(false)
			revealStructure()
			return
		end

		hideStructure()
		if state == "Hidden" then
			pad.Transparency = 1
			pad.CanCollide = false
			pad.CanTouch = false
			setLabelsEnabled(false)
			return
		end

		pad.Transparency = 0.5
		pad.CanCollide = false
		pad.CanTouch = true
		pad.Material = Enum.Material.Neon
		setLabelsEnabled(true)
		if priceText then
			priceText.Text = priceValue == 0 and "FREE" or ("$" .. tostring(priceValue))
		end
		updateAffordableColor()
	end

	pad.Touched:Connect(function(hit)
		if isProcessingPurchase or activated.Value or not dependencyMet() then
			return
		end

		local player = getPlayerFromHit(hit)
		if not player or getOwnerPlayer(plot) ~= player then
			return
		end

		local cash = getCash(player)
		if priceValue > 0 and (not cash or cash.Value < priceValue) then
			return
		end

		isProcessingPurchase = true
		if priceValue > 0 then
			cash.Value -= priceValue
		end
		activated.Value = true
		applyState(true)

		PurchaseSoundModule.PlayPurchaseForTarget(player, pad)
		if #targetParts > 0 then
			PurchaseEffectModule.PlayAcrossParts(targetParts, nil, {
				pointCount = 30,
				totalParticleBudget = 120,
			})
		else
			PurchaseEffectModule.Play(pad.Position + Vector3.new(0, 1.4, 0))
		end

		task.delay(0.4, function()
			isProcessingPurchase = false
		end)
	end)

	applyState(true)
	task.spawn(function()
		while pad.Parent do
			applyState(false)
			task.wait(UPDATE_INTERVAL_SECONDS)
		end
		wiredPads[pad] = nil
	end)
end

return StructurePurchaseService