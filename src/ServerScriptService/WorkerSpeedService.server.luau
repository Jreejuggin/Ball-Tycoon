-- Server-authoritative, plot-wide worker speed upgrades.
-- The service only wires plots that contain a WorkerSpeedUpgrade model, allowing
-- the P1 build to be tested before it is deliberately cloned to other plots.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorkerSpeedConfig = require(ReplicatedStorage:WaitForChild("WorkerSpeedConfig"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local COLOR_GREEN = Color3.new(0, 1, 0)
local COLOR_RED = Color3.new(0.8, 0.1, 0.1)
local AVAILABLE_PREVIEW_TRANSPARENCY = 0.6
local PURCHASE_COOLDOWN_SECONDS = 0.75
local WIRED_ATTRIBUTE = "WorkerSpeedServiceWired"

local function formatCash(amount)
	local text = tostring(math.floor(amount))
	while true do
		local updated, replacements = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = updated
		if replacements == 0 then
			break
		end
	end
	return "$" .. text
end

local function getPlayerFromHit(hit)
	if not hit then
		return nil
	end

	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getCash(player)
	local leaderstats = player and player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
		return cash
	end
	return nil
end

local function getPlotOwner(plot)
	return tonumber(plot:GetAttribute("Owner"))
end

local function isOwnedBy(plot, player)
	return player ~= nil and getPlotOwner(plot) == player.UserId
end

local function getWorkerHumanoid(instance)
	if not instance:IsA("Model") or instance:GetAttribute("ActivationName") == nil then
		return nil
	end
	return instance:FindFirstChildOfClass("Humanoid")
end

local function wirePlot(plot, upgrade)
	if upgrade:GetAttribute(WIRED_ATTRIBUTE) then
		return false
	end

	local centreSlots = plot:FindFirstChild("CentreSlots")
	local workerCentre = centreSlots and centreSlots:FindFirstChild("Centre01_Worker")
	local upgrades = workerCentre and workerCentre:FindFirstChild("Upgrades")
	local activations = workerCentre and workerCentre:FindFirstChild("WorkerActivations")
	local firstWorker = activations and activations:FindFirstChild("Worker1")
	local pad = upgrade:FindFirstChild("BuyPad")
	local levelValue = upgrade:FindFirstChild("UpgradeLevel")
	local speedSign = upgrade:FindFirstChild("WorkerSpeedSign")
	local signCollisionFolder = speedSign and speedSign:FindFirstChild("Collision")

	if not (upgrades and activations and firstWorker and pad and pad:IsA("BasePart") and levelValue and levelValue:IsA("IntValue") and speedSign and speedSign:IsA("Model")) then
		warn("[WorkerSpeedService] Incomplete WorkerSpeedUpgrade under " .. plot:GetFullName())
		return false
	end

	upgrade:SetAttribute(WIRED_ATTRIBUTE, true)
	levelValue.Value = math.clamp(levelValue.Value, 1, WorkerSpeedConfig.MaxLevel)

	local priceValue = pad:FindFirstChild("Price")
	if not priceValue then
		priceValue = Instance.new("IntValue")
		priceValue.Name = "Price"
		priceValue.Parent = pad
	end

	local priceLabel = pad:FindFirstChild("PriceLabel")
	local priceText = priceLabel and priceLabel:FindFirstChild("PriceText", true)
	local upgradeLabel = pad:FindFirstChild("UpgradeLabel")
	local upgradeText = upgradeLabel and upgradeLabel:FindFirstChildWhichIsA("TextLabel", true)
	local speedText = upgradeLabel and upgradeLabel:FindFirstChild("SpeedText")

	local function styleLabel(textLabel, color)
		if not textLabel or not textLabel:IsA("TextLabel") then
			return
		end
		textLabel.BackgroundTransparency = 1
		textLabel.TextScaled = true
		textLabel.TextWrapped = true
		textLabel.FontFace = Font.new(
			"rbxasset://fonts/families/GothamSSm.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		)
		textLabel.TextColor3 = color
		textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		textLabel.TextStrokeTransparency = 0
	end

	if upgradeLabel and upgradeLabel:IsA("BillboardGui") then
		upgradeLabel.Adornee = pad
		upgradeLabel.Size = UDim2.new(4, 0, 2, 0)
		upgradeLabel.StudsOffset = Vector3.new(0, 5, 0)
		upgradeLabel.AlwaysOnTop = true
		upgradeLabel.LightInfluence = 0

		if not speedText or not speedText:IsA("TextLabel") then
			if speedText then
				speedText:Destroy()
			end
			speedText = Instance.new("TextLabel")
			speedText.Name = "SpeedText"
			speedText.Parent = upgradeLabel
		end
	end

	if upgradeText and upgradeText:IsA("TextLabel") then
		styleLabel(upgradeText, Color3.new(1, 1, 1))
		upgradeText.Size = UDim2.new(1, 0, 0.55, 0)
		upgradeText.Position = UDim2.new(0, 0, 0, 0)
	end
	if speedText and speedText:IsA("TextLabel") then
		styleLabel(speedText, Color3.fromRGB(255, 235, 90))
		speedText.Size = UDim2.new(1, 0, 0.48, 0)
		speedText.Position = UDim2.new(0, 0, 0.52, 0)
	end

	if priceLabel and priceLabel:IsA("BillboardGui") then
		priceLabel.Adornee = pad
		priceLabel.Size = UDim2.new(4, 0, 1.5, 0)
		priceLabel.StudsOffset = Vector3.new(0, 3, 0)
		priceLabel.AlwaysOnTop = true
		priceLabel.LightInfluence = 0
	end
	if priceText and priceText:IsA("TextLabel") then
		styleLabel(priceText, COLOR_GREEN)
		priceText.Size = UDim2.fromScale(1, 1)
		priceText.Position = UDim2.fromScale(0, 0)
	end

	-- Current worker-speed status displayed above the statue. This is separate
	-- from the buy pad, which continues to preview the next upgrade.
	local statusAnchor = upgrade:FindFirstChild("SpeedStatusAnchor")
	if statusAnchor and not statusAnchor:IsA("BasePart") then
		statusAnchor:Destroy()
		statusAnchor = nil
	end
	if not statusAnchor then
		statusAnchor = Instance.new("Part")
		statusAnchor.Name = "SpeedStatusAnchor"
		statusAnchor.Parent = upgrade
	end

	local signBoxCFrame, signBoxSize = speedSign:GetBoundingBox()
	statusAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	statusAnchor.CFrame = signBoxCFrame * CFrame.new(0, (signBoxSize.Y / 2) + 0.9, 0)
	statusAnchor.Transparency = 1
	statusAnchor.Anchored = true
	statusAnchor.CanCollide = false
	statusAnchor.CanTouch = false
	statusAnchor.CanQuery = false
	statusAnchor.CastShadow = false

	local statusGui = statusAnchor:FindFirstChild("SpeedStatusLabel")
	if statusGui and not statusGui:IsA("BillboardGui") then
		statusGui:Destroy()
		statusGui = nil
	end
	if not statusGui then
		statusGui = Instance.new("BillboardGui")
		statusGui.Name = "SpeedStatusLabel"
		statusGui.Parent = statusAnchor
	end
	statusGui.Adornee = statusAnchor
	statusGui.Size = UDim2.new(5, 0, 1.65, 0)
	statusGui.AlwaysOnTop = true
	statusGui.LightInfluence = 0
	statusGui.Enabled = false

	local levelText = statusGui:FindFirstChild("LevelText")
	if levelText and not levelText:IsA("TextLabel") then
		levelText:Destroy()
		levelText = nil
	end
	if not levelText then
		levelText = Instance.new("TextLabel")
		levelText.Name = "LevelText"
		levelText.Parent = statusGui
	end
	styleLabel(levelText, Color3.fromRGB(0, 225, 255))
	levelText.Size = UDim2.new(1, 0, 0.48, 0)
	levelText.Position = UDim2.new(0, 0, 0, 0)

	local currentSpeedText = statusGui:FindFirstChild("CurrentSpeedText")
	if currentSpeedText and not currentSpeedText:IsA("TextLabel") then
		currentSpeedText:Destroy()
		currentSpeedText = nil
	end
	if not currentSpeedText then
		currentSpeedText = Instance.new("TextLabel")
		currentSpeedText.Name = "CurrentSpeedText"
		currentSpeedText.Parent = statusGui
	end
	styleLabel(currentSpeedText, Color3.fromRGB(255, 235, 90))
	currentSpeedText.Size = UDim2.new(1, 0, 0.52, 0)
	currentSpeedText.Position = UDim2.new(0, 0, 0.48, 0)

	local processing = false
	local cooldownUntil = 0
	local signVisualStates = {}
	local signCollisionStates = {}

	for _, descendant in ipairs(speedSign:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local original = {
				Transparency = descendant.Transparency,
				CanCollide = descendant.CanCollide,
				CanTouch = descendant.CanTouch,
				CanQuery = descendant.CanQuery,
				CastShadow = descendant.CastShadow,
			}
			if signCollisionFolder and descendant:IsDescendantOf(signCollisionFolder) then
				signCollisionStates[descendant] = original
			else
				signVisualStates[descendant] = original
			end
		end
	end

	local function applySignPart(part, original, mode)
		if mode == "Purchased" then
			part.Transparency = original.Transparency
			part.CanCollide = original.CanCollide
			part.CanTouch = original.CanTouch
			part.CanQuery = original.CanQuery
			part.CastShadow = original.CastShadow
		elseif mode == "Available" then
			part.Transparency = math.max(original.Transparency, AVAILABLE_PREVIEW_TRANSPARENCY)
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		else
			part.Transparency = 1
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end

	local function updateSpeedSign()
		local workerPurchased = getPlotOwner(plot) ~= nil and firstWorker.Value
		local purchased = workerPurchased and levelValue.Value >= 2
		local mode = purchased and "Purchased" or (workerPurchased and "Available" or "Hidden")

		for part, original in pairs(signVisualStates) do
			applySignPart(part, original, mode)
		end
		for part, original in pairs(signCollisionStates) do
			applySignPart(part, original, purchased and "Purchased" or "Hidden")
		end

		local currentData = WorkerSpeedConfig.GetLevel(levelValue.Value)
		statusGui.Enabled = workerPurchased
		levelText.Text = "Lvl " .. tostring(levelValue.Value)
		levelText.TextColor3 = Color3.fromRGB(0, 225, 255)
		currentSpeedText.Text = "⚡ " .. tostring(currentData.WalkSpeed) .. " km/h"
		currentSpeedText.TextColor3 = Color3.fromRGB(255, 235, 90)

		upgrade:SetAttribute("Unlocked", workerPurchased)
		upgrade:SetAttribute("Purchased", purchased)
		upgrade:SetAttribute("Status", mode)
	end

	local function currentWalkSpeed()
		return WorkerSpeedConfig.GetLevel(levelValue.Value).WalkSpeed
	end

	local function applyToWorker(worker)
		local humanoid = getWorkerHumanoid(worker)
		if humanoid then
			humanoid.WalkSpeed = currentWalkSpeed()
		end
	end

	local function applyToAllWorkers()
		for _, child in ipairs(plot:GetChildren()) do
			applyToWorker(child)
		end
	end

	local function canPlayerAffordOwner()
		local ownerUserId = getPlotOwner(plot)
		if not ownerUserId then
			return false
		end

		local owner = Players:GetPlayerByUserId(ownerUserId)
		local cash = getCash(owner)
		local _, nextData = WorkerSpeedConfig.GetNextLevel(levelValue.Value)
		return cash ~= nil and nextData ~= nil and cash.Value >= nextData.Cost
	end

	local function setGuiEnabled(gui, enabled)
		if gui and (gui:IsA("SurfaceGui") or gui:IsA("BillboardGui")) then
			gui.Enabled = enabled
		end
	end

	local function updatePad()
		updateSpeedSign()
		local _, nextData = WorkerSpeedConfig.GetNextLevel(levelValue.Value)
		local unlocked = getPlotOwner(plot) ~= nil and firstWorker.Value
		local purchasable = unlocked and nextData ~= nil and os.clock() >= cooldownUntil
		local affordable = canPlayerAffordOwner()
		local statusColor = affordable and COLOR_GREEN or COLOR_RED

		pad.Transparency = purchasable and 0.5 or 1
		pad.CanCollide = false
		pad.CanTouch = purchasable
		pad.CanQuery = purchasable
		pad.Material = Enum.Material.Neon
		pad.Color = statusColor
		pcall(function()
			pad.UsePartColor = true
		end)

		setGuiEnabled(priceLabel, purchasable)
		setGuiEnabled(upgradeLabel, purchasable)

		if nextData then
			priceValue.Value = nextData.Cost
			if priceText and priceText:IsA("TextLabel") then
				priceText.Text = formatCash(nextData.Cost)
				priceText.TextColor3 = statusColor
			end
			if upgradeText and upgradeText:IsA("TextLabel") then
				upgradeText.Text = levelValue.Value <= 1
					and "Worker Speed Upgrader"
					or ("Upgrade Lvl " .. tostring(levelValue.Value))
				upgradeText.TextColor3 = Color3.new(1, 1, 1)
			end
			if speedText and speedText:IsA("TextLabel") then
				speedText.Text = "⚡ " .. tostring(nextData.WalkSpeed) .. " km/h"
				speedText.TextColor3 = Color3.fromRGB(255, 235, 90)
			end
		else
			priceValue.Value = 0
		end
	end

	local function onTouched(hit)
		if processing or os.clock() < cooldownUntil or not firstWorker.Value then
			return
		end

		local player = getPlayerFromHit(hit)
		if not isOwnedBy(plot, player) then
			return
		end

		local nextLevel, nextData = WorkerSpeedConfig.GetNextLevel(levelValue.Value)
		if not nextData then
			updatePad()
			return
		end

		local cash = getCash(player)
		if not cash or cash.Value < nextData.Cost then
			updatePad()
			return
		end

		processing = true
		cash.Value -= nextData.Cost
		levelValue.Value = nextLevel
		cooldownUntil = os.clock() + PURCHASE_COOLDOWN_SECONDS

		applyToAllWorkers()
		PurchaseEffectModule.Play(pad.Position)
		PurchaseSoundModule.PlayPurchaseForTarget(player, pad)
		updatePad()

		task.delay(PURCHASE_COOLDOWN_SECONDS, function()
			processing = false
			updatePad()
		end)
	end

	pad.Touched:Connect(onTouched)
	levelValue.Changed:Connect(function()
		levelValue.Value = math.clamp(levelValue.Value, 1, WorkerSpeedConfig.MaxLevel)
		applyToAllWorkers()
		updatePad()
	end)
	firstWorker.Changed:Connect(updatePad)
	plot:GetAttributeChangedSignal("Owner"):Connect(updatePad)
	plot.ChildAdded:Connect(function(child)
		task.defer(function()
			if child.Parent == plot then
				applyToWorker(child)
			end
		end)
	end)

	applyToAllWorkers()
	updatePad()

	task.spawn(function()
		while upgrade.Parent and plot.Parent do
			updatePad()
			task.wait(0.5)
		end
	end)

	return true
end

local wiredCount = 0
for index = 1, 10 do
	local plot = workspace:FindFirstChild("P" .. index)
	local centreSlots = plot and plot:FindFirstChild("CentreSlots")
	local workerCentre = centreSlots and centreSlots:FindFirstChild("Centre01_Worker")
	local upgrades = workerCentre and workerCentre:FindFirstChild("Upgrades")
	local upgrade = upgrades and upgrades:FindFirstChild("WorkerSpeedUpgrade")

	if plot and upgrade and wirePlot(plot, upgrade) then
		wiredCount += 1
	end
end

print(string.format("[WorkerSpeedService] Wired %d worker speed upgrade(s).", wiredCount))
