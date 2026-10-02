-- Server-authoritative P1-P10 Coil stations.
-- Purchase ownership is saved through CoilStation.Activated. The reward is a
-- permanent 20% jump-height bonus while the player owns the plot; no Tool is granted.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotTheme = require(ReplicatedStorage:WaitForChild("PlotTheme"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local STATION_NAME = "CoilStation"
local LEGACY_TOOL_NAME = "Coil"
local JUMP_ATTRIBUTE = "PlayerJumpUpgradeMultiplier"
local COLOR_GREEN = Color3.fromRGB(30, 255, 75)
local COLOR_RED = Color3.fromRGB(215, 28, 38)
local COLOR_GHOST = Color3.fromRGB(105, 110, 120)
local COLOR_DARK = Color3.fromRGB(36, 39, 43)

local jumpStateByPlayer = {}
local playerConnections = {}
local lastOwnerByPlot = {}

local function formatCash(amount)
	return "$" .. tostring(math.max(0, math.floor(amount)))
end

local function getCash(player)
	local leaderstats = player and player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
		return cash
	end
	return nil
end

local function getToolContainers(player)
	local containers = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	local starterGear = player:FindFirstChild("StarterGear")
	if backpack then
		table.insert(containers, backpack)
	end
	if starterGear then
		table.insert(containers, starterGear)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end
	return containers
end

local function removeLegacyCoils(player)
	for _, container in ipairs(getToolContainers(player)) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child.Name == LEGACY_TOOL_NAME then
				child:Destroy()
			end
		end
	end
end

local function clearJumpBonus(player)
	local state = jumpStateByPlayer[player]
	if not state then
		return
	end
	jumpStateByPlayer[player] = nil

	local humanoid = state.humanoid
	if humanoid.Parent and humanoid:GetAttribute(JUMP_ATTRIBUTE) ~= nil then
		if state.propertyName == "JumpPower" then
			humanoid.JumpPower /= state.factor
		else
			humanoid.JumpHeight /= state.factor
		end
		humanoid:SetAttribute(JUMP_ATTRIBUTE, nil)
	end
end

local function applyJumpBonus(player, multiplier)
	removeLegacyCoils(player)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local existing = jumpStateByPlayer[player]
	if existing
		and existing.humanoid == humanoid
		and math.abs(existing.multiplier - multiplier) < 0.0001
		and humanoid:GetAttribute(JUMP_ATTRIBUTE) == multiplier
	then
		return
	end

	clearJumpBonus(player)

	local propertyName
	local factor
	if humanoid.UseJumpPower then
		propertyName = "JumpPower"
		-- Jump height is proportional to launch velocity squared.
		factor = math.sqrt(multiplier)
		humanoid.JumpPower *= factor
	else
		propertyName = "JumpHeight"
		factor = multiplier
		humanoid.JumpHeight *= factor
	end

	humanoid:SetAttribute(JUMP_ATTRIBUTE, multiplier)
	jumpStateByPlayer[player] = {
		humanoid = humanoid,
		propertyName = propertyName,
		factor = factor,
		multiplier = multiplier,
	}
end

local function setBasePartVisible(part, visible)
	part.Transparency = visible and 0 or 1
	part.CanCollide = visible
	part.CanTouch = false
	part.CanQuery = visible
	part.CastShadow = visible
end

local function setLabels(station, enabled, priceTextValue, color)
	local buyPad = station:FindFirstChild("BuyPad")
	if not buyPad then
		return
	end

	local priceLabel = buyPad:FindFirstChild("PriceLabel")
	local upgradeLabel = buyPad:FindFirstChild("UpgradeLabel")
	if priceLabel and priceLabel:IsA("BillboardGui") then
		priceLabel.Enabled = enabled
		local priceText = priceLabel:FindFirstChild("PriceText")
		if priceText and priceText:IsA("TextLabel") then
			priceText.Text = priceTextValue
			priceText.TextColor3 = color
		end
	end
	if upgradeLabel and upgradeLabel:IsA("BillboardGui") then
		upgradeLabel.Enabled = enabled
		local titleText = upgradeLabel:FindFirstChild("WorkerText")
		local boostText = upgradeLabel:FindFirstChild("SpeedText")
		if titleText and titleText:IsA("TextLabel") then
			titleText.Text = "Player Jump Upgrader"
			titleText.TextColor3 = Color3.new(1, 1, 1)
		end
		if boostText and boostText:IsA("TextLabel") then
			boostText.Text = "+20% Jump Boost"
			boostText.TextColor3 = Color3.fromRGB(255, 235, 90)
		end
	end
end

local function findOwnedPlot(player)
	for index = 1, 10 do
		local plot = workspace:FindFirstChild("P" .. index)
		if plot and tonumber(plot:GetAttribute("Owner")) == player.UserId then
			return plot
		end
	end
	return nil
end

local function findStation(plot)
	local centreSlots = plot and plot:FindFirstChild("CentreSlots")
	local avatarCentre = centreSlots and centreSlots:FindFirstChild("Centre03_Avatar")
	local upgrades = avatarCentre and avatarCentre:FindFirstChild("Upgrades")
	local station = upgrades and upgrades:FindFirstChild(STATION_NAME)
	return station and station:IsA("Model") and station or nil
end

local function refreshPlayerUpgrade(player)
	removeLegacyCoils(player)
	local plot = findOwnedPlot(player)
	local station = plot and findStation(plot)
	local activated = station and station:FindFirstChild("Activated")
	local config = station and station:FindFirstChild("Config")
	local multiplierValue = config and config:FindFirstChild("JumpHeightMultiplier")

	if station
		and activated
		and activated:IsA("BoolValue")
		and activated.Value
		and multiplierValue
		and multiplierValue:IsA("NumberValue")
	then
		applyJumpBonus(player, multiplierValue.Value)
	else
		clearJumpBonus(player)
	end
end

local function disconnectPlayer(player)
	local connections = playerConnections[player]
	if connections then
		for _, connection in pairs(connections) do
			if typeof(connection) == "RBXScriptConnection" then
				connection:Disconnect()
			end
		end
	end
	playerConnections[player] = nil
end

local function connectPlayer(player)
	disconnectPlayer(player)
	local connections = {}
	playerConnections[player] = connections

	local function watchCharacter(character)
		removeLegacyCoils(player)
		connections.characterChildAdded = character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == LEGACY_TOOL_NAME then
				child:Destroy()
			end
		end)
		task.defer(function()
			refreshPlayerUpgrade(player)
		end)
	end

	connections.characterAdded = player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	task.spawn(function()
		local backpack = player:WaitForChild("Backpack", 10)
		if not backpack or not player.Parent then
			return
		end
		removeLegacyCoils(player)
		connections.backpackChildAdded = backpack.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == LEGACY_TOOL_NAME then
				child:Destroy()
			end
		end)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(connectPlayer, player)
end
Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player)
	clearJumpBonus(player)
	disconnectPlayer(player)
end)

local function wirePlot(plot)
	local centreSlots = plot:FindFirstChild("CentreSlots")
	local avatarCentre = centreSlots and centreSlots:FindFirstChild("Centre03_Avatar")
	local avatarActivated = avatarCentre and avatarCentre:FindFirstChild("Activated")
	local upgrades = avatarCentre and avatarCentre:FindFirstChild("Upgrades")
	local station = upgrades and upgrades:FindFirstChild(STATION_NAME)

	if not avatarCentre
		or not avatarActivated
		or not avatarActivated:IsA("BoolValue")
		or not station
		or not station:IsA("Model")
	then
		warn(("[CoilStationService] Incomplete station in %s."):format(plot:GetFullName()))
		return false
	end

	local config = station:FindFirstChild("Config")
	local price = config and config:FindFirstChild("Price")
	local jumpHeightMultiplier = config and config:FindFirstChild("JumpHeightMultiplier")
	local activated = station:FindFirstChild("Activated")
	local buyPad = station:FindFirstChild("BuyPad")
	local pedestal = station:FindFirstChild("Pedestal")
	local coilDisplay = station:FindFirstChild("CoilDisplay")

	if not price
		or not price:IsA("IntValue")
		or not jumpHeightMultiplier
		or not jumpHeightMultiplier:IsA("NumberValue")
		or not activated
		or not activated:IsA("BoolValue")
		or not buyPad
		or not buyPad:IsA("BasePart")
		or not pedestal
		or not pedestal:IsA("BasePart")
		or not coilDisplay
		or not coilDisplay:IsA("BasePart")
	then
		warn(("[CoilStationService] Invalid station configuration in %s."):format(plot:GetFullName()))
		return false
	end

	local processing = false
	local currentOwner = nil
	local cashConnection = nil
	local cashBindPending = false
	local applyState

	local function getOwner()
		local ownerId = tonumber(plot:GetAttribute("Owner"))
		return ownerId and Players:GetPlayerByUserId(ownerId) or nil
	end

	local function reconnectCash(owner)
		if owner ~= currentOwner then
			if cashConnection then
				cashConnection:Disconnect()
				cashConnection = nil
			end
			currentOwner = owner
			cashBindPending = false
		end
		if not owner or cashConnection or cashBindPending then
			return
		end

		local function connectCash(cash)
			if currentOwner ~= owner then
				return
			end
			cashConnection = cash.Changed:Connect(function()
				applyState()
			end)
			applyState()
		end

		local cash = getCash(owner)
		if cash then
			connectCash(cash)
			return
		end

		cashBindPending = true
		task.spawn(function()
			local leaderstats = owner:WaitForChild("leaderstats", 10)
			local foundCash = leaderstats and leaderstats:WaitForChild("Cash", 10)
			cashBindPending = false
			if currentOwner == owner
				and foundCash
				and (foundCash:IsA("IntValue") or foundCash:IsA("NumberValue"))
			then
				connectCash(foundCash)
			end
		end)
	end

	applyState = function()
		local owner = getOwner()
		local previousOwner = lastOwnerByPlot[plot]
		if previousOwner and previousOwner ~= owner then
			clearJumpBonus(previousOwner)
			removeLegacyCoils(previousOwner)
		end
		lastOwnerByPlot[plot] = owner
		reconnectCash(owner)

		local centreOwned = owner ~= nil and avatarActivated.Value
		local purchased = activated.Value

		if not centreOwned then
			if owner then
				clearJumpBonus(owner)
				removeLegacyCoils(owner)
			end
			setBasePartVisible(pedestal, false)
			setBasePartVisible(coilDisplay, false)
			buyPad.Transparency = 1
			buyPad.CanCollide = false
			buyPad.CanTouch = false
			buyPad.CanQuery = false
			setLabels(station, false, "", COLOR_RED)
			return
		end

		setBasePartVisible(pedestal, true)
		pedestal.Color = COLOR_DARK
		setBasePartVisible(coilDisplay, true)
		coilDisplay.Anchored = true
		coilDisplay.CanCollide = true
		coilDisplay.CanTouch = false
		coilDisplay.CanQuery = false

		if purchased then
			coilDisplay.Color = PlotTheme.GetPlotColor(plot)
			coilDisplay.Material = Enum.Material.SmoothPlastic
			coilDisplay.Transparency = 0
			coilDisplay.CastShadow = true
			buyPad.Transparency = 1
			buyPad.CanCollide = false
			buyPad.CanTouch = false
			buyPad.CanQuery = false
			setLabels(station, false, "OWNED", COLOR_GREEN)
			applyJumpBonus(owner, jumpHeightMultiplier.Value)
			return
		end

		clearJumpBonus(owner)
		removeLegacyCoils(owner)
		coilDisplay.Color = COLOR_GHOST
		coilDisplay.Material = Enum.Material.SmoothPlastic
		coilDisplay.Transparency = 0.55
		coilDisplay.CastShadow = false

		local cash = getCash(owner)
		local affordable = cash ~= nil and cash.Value >= price.Value
		local padColor = affordable and COLOR_GREEN or COLOR_RED
		buyPad.Color = padColor
		buyPad.Material = Enum.Material.Neon
		buyPad.Transparency = 0.45
		buyPad.CanCollide = false
		buyPad.CanQuery = true
		buyPad.CanTouch = true
		setLabels(station, true, formatCash(price.Value), padColor)
	end

	buyPad.Touched:Connect(function(hit)
		if processing or activated.Value then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local owner = getOwner()
		if not player or player ~= owner then
			return
		end
		if not avatarActivated.Value then
			applyState()
			return
		end

		local cash = getCash(player)
		if not cash or cash.Value < price.Value then
			applyState()
			return
		end

		processing = true
		cash.Value -= price.Value
		activated.Value = true

		PurchaseEffectModule.PlayAcrossParts({ coilDisplay })
		PurchaseSoundModule.PlayPurchaseForTarget(player, buyPad)

		task.delay(0.6, function()
			processing = false
			applyState()
		end)
	end)

	activated.Changed:Connect(applyState)
	avatarActivated.Changed:Connect(applyState)
	price.Changed:Connect(applyState)
	jumpHeightMultiplier.Changed:Connect(function()
		local owner = getOwner()
		if owner then
			clearJumpBonus(owner)
		end
		applyState()
	end)
	plot:GetAttributeChangedSignal("Owner"):Connect(applyState)
	plot:GetAttributeChangedSignal("PlotColor"):Connect(applyState)

	applyState()
	return true
end

local wiredCount = 0
for plotIndex = 1, 10 do
	local plot = workspace:FindFirstChild("P" .. plotIndex)
	if plot and wirePlot(plot) then
		wiredCount += 1
	end
end
print(("[CoilStationService] Wired %d permanent jump upgrade(s)."):format(wiredCount))
