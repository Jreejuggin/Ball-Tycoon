-- Avatar throwable station: existing plot-relative Activated save contract,
-- Coil purchase presentation, and sword-style Backpack/StarterGear rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("ThrowableBallConfig"))
local PlotTheme = require(ReplicatedStorage:WaitForChild("PlotTheme"))
local PurchaseEffect = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSound = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))
local Combat = require(script.Parent:WaitForChild("ThrowableBallCombatService"))
local template = ServerStorage:WaitForChild("Tools"):WaitForChild(Config.ToolName)
local states = {}
local playerConnections = {}
local refreshing = {}
local GREEN = Color3.fromRGB(30, 255, 75)
local RED = Color3.fromRGB(215, 28, 38)

local function findStation(plot)
	local centres = plot and plot:FindFirstChild("CentreSlots")
	local avatar = centres and centres:FindFirstChild("Centre03_Avatar")
	local upgrades = avatar and avatar:FindFirstChild("Upgrades")
	return upgrades and upgrades:FindFirstChild(Config.StationName), avatar
end

local function findOwnedStation(player)
	if not player:GetAttribute("DataLoaded") then return nil end
	for index = 1, 10 do
		local plot = workspace:FindFirstChild("P" .. index)
		if plot and tonumber(plot:GetAttribute("Owner")) == player.UserId then
			if plot:GetAttribute("RestoringProgress") then return nil end
			local station, avatar = findStation(plot)
			local active = station and station:FindFirstChild("Activated")
			local centreActive = avatar and avatar:FindFirstChild("Activated")
			if active and active.Value and centreActive and centreActive.Value then
				return station
			end
		end
	end
	return nil
end

local function getCash(player)
	local stats = player and player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	return cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) and cash or nil
end

local function getContainers(player)
	local containers = {}
	if player.Character then table.insert(containers, player.Character) end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then table.insert(containers, backpack) end
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then table.insert(containers, starterGear) end
	return containers
end

local function configureTool(tool, level)
	local data = Config.Levels[level]
	tool.TextureId = data.Icon
	tool:SetAttribute("InventoryIcon", data.Icon)
	tool.ToolTip = data.DisplayName .. " — " .. data.Damage .. " damage"
	tool:SetAttribute("WeaponLevel", level)
	tool:SetAttribute("InventoryLevel", level)
	tool:SetAttribute("InventoryDisplayName", data.DisplayName)
	tool:SetAttribute("ItemId", "ThrowableBall_Level" .. level)
	tool:SetAttribute("GrantedByThrowableBallStation", true)
	for _,key in ipairs({"HorizontalKnockback", "VerticalKnockback", "AngularKnockback", "RagdollSeconds"}) do
		tool:SetAttribute(key, data[key])
	end
end

local function refreshPlayer(player)
	if not player.Parent then return end
	local station = findOwnedStation(player)
	local levelValue = station and station.Config:FindFirstChild("Level")
	local level = levelValue and levelValue.Value or 1
	local liveTool, starterTool
	-- Prefer the equipped copy, then Backpack, and reconcile respawn clones.
	for _,container in ipairs(getContainers(player)) do
		for _,child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child.Name == Config.ToolName then
				if not station or child:GetAttribute("WeaponLevel") ~= level then child:Destroy()
				elseif container.Name == "StarterGear" then
					if starterTool then child:Destroy() else starterTool = child end
				elseif liveTool then child:Destroy()
				else liveTool = child end
			end
		end
	end
	if not station then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not liveTool and backpack then
		liveTool = template:Clone()
		configureTool(liveTool, level)
		liveTool.Parent = backpack
	end
	if liveTool then configureTool(liveTool, level) Combat.WireTool(liveTool, player) end
	local starterGear = player:FindFirstChild("StarterGear")
	if not starterTool and starterGear then
		starterTool = template:Clone()
		configureTool(starterTool, level)
		starterTool.Parent = starterGear
	end
end

local function scheduleRefresh(player)
	if refreshing[player] then return end
	refreshing[player] = true
	task.defer(function()
		refreshing[player] = nil
		refreshPlayer(player)
	end)
end

Combat.Configure(template, function(player)
	return findOwnedStation(player) ~= nil
end)

local function connectPlayer(player)
	local connections = {}
	playerConnections[player] = connections
	local characterConnections = {}
	local backpackConnections = {}
	local watchedBackpack
	local function watchBackpack(backpack)
		if watchedBackpack == backpack then return end
		for _,connection in ipairs(backpackConnections) do connection:Disconnect() end
		table.clear(backpackConnections)
		watchedBackpack = backpack
		if backpack then
			for _,signal in ipairs({backpack.ChildAdded, backpack.ChildRemoved}) do
				table.insert(backpackConnections, signal:Connect(function(child)
					if child:IsA("Tool") and child.Name == Config.ToolName then scheduleRefresh(player) end
				end))
			end
		end
		scheduleRefresh(player)
	end
	local function watchCharacter(character)
		for _,connection in ipairs(characterConnections) do connection:Disconnect() end
		table.clear(characterConnections)
		table.insert(characterConnections, character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == Config.ToolName then scheduleRefresh(player) end
		end))
		table.insert(characterConnections, character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child.Name == Config.ToolName then scheduleRefresh(player) end
		end))
		scheduleRefresh(player)
	end
	table.insert(connections, player.CharacterAdded:Connect(watchCharacter))
	table.insert(connections, player.CharacterRemoving:Connect(function()
		Combat.RemovePlayer(player)
	end))
	connections.characterConnections = characterConnections
	connections.backpackConnections = backpackConnections
	table.insert(connections, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then watchBackpack(child) end
	end))
	table.insert(connections, player.ChildRemoved:Connect(function(child)
		if child == watchedBackpack then watchBackpack(nil) end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		scheduleRefresh(player)
	end))
	if player.Character then watchCharacter(player.Character) end
	task.spawn(function()
		local backpack = player:WaitForChild("Backpack", 10)
		if not backpack or not player.Parent then return end
		watchBackpack(backpack)
	end)
end
Players.PlayerAdded:Connect(connectPlayer)
for _,player in ipairs(Players:GetPlayers()) do connectPlayer(player) end
Players.PlayerRemoving:Connect(function(player)
	Combat.RemovePlayer(player)
	refreshing[player] = nil
	local connections = playerConnections[player]
	if connections then
		for _,connection in ipairs(connections) do connection:Disconnect() end
		for _,connection in ipairs(connections.characterConnections) do connection:Disconnect() end
		for _,connection in ipairs(connections.backpackConnections) do connection:Disconnect() end
	end
	playerConnections[player] = nil
end)

local function wirePlot(plot)
	local station, avatar = findStation(plot)
	assert(station and avatar, "Missing throwable station in " .. plot.Name)
	local active = station.Activated
	local centreActive = avatar.Activated
	local price = station.Config.Price
	local pad, pedestal, display = station.BuyPad, station.Pedestal, station.BallDisplay
	local owner, cashConnection, cashBindToken
	local processing = false
	local applyState

	local function getOwner()
		local id = tonumber(plot:GetAttribute("Owner"))
		return id and Players:GetPlayerByUserId(id) or nil
	end
	local function setLabels(enabled, status, color)
		pad.PriceLabel.Enabled = enabled
		pad.UpgradeLabel.Enabled = enabled
		pad.PriceLabel.PriceText.Text = status
		pad.PriceLabel.PriceText.TextColor3 = color
		local data = Config.Levels[station.Config.Level.Value]
		pad.UpgradeLabel.WorkerText.Text = data.DisplayName
		pad.UpgradeLabel.SpeedText.Text = data.Damage .. " Damage • Throw"
	end

	applyState = function()
		local currentOwner = getOwner()
		if currentOwner ~= owner then
			local oldOwner = owner
			owner = currentOwner
			if cashConnection then cashConnection:Disconnect() cashConnection = nil end
			cashBindToken = {}
			local token = cashBindToken
			if oldOwner and oldOwner.Parent then scheduleRefresh(oldOwner) Combat.RemovePlayer(oldOwner) end
			if owner then
				local cash = getCash(owner)
				if cash then cashConnection = cash.Changed:Connect(applyState)
				else
					local waitingOwner = owner
					task.spawn(function()
						local stats = waitingOwner:WaitForChild("leaderstats", 10)
						local value = stats and stats:WaitForChild("Cash", 10)
						if token == cashBindToken and value then
							cashConnection = value.Changed:Connect(applyState)
							applyState()
						end
					end)
				end
			end
		end
		local unlocked = owner ~= nil and centreActive.Value
		pedestal.Transparency = unlocked and 0 or 1
		pedestal.CanCollide = unlocked
		pedestal.CanTouch = false
		pedestal.CanQuery = unlocked
		pedestal.CastShadow = unlocked
		pedestal.Color = Color3.fromRGB(36, 39, 43)
		display.Transparency = unlocked and (active.Value and 0 or 0.55) or 1
		display.CanCollide = unlocked
		display.CanTouch = false
		display.CanQuery = false
		display.CastShadow = unlocked and active.Value
		pad.CanCollide = false
		local available = unlocked and not active.Value
		pad.Transparency = available and 0.45 or 1
		pad.CanTouch = available
		pad.CanQuery = available
		pad.Material = Enum.Material.Neon
		local cash = getCash(owner)
		local color = cash and cash.Value >= price.Value and GREEN or RED
		pad.Color = color
		setLabels(available, active.Value and "OWNED" or ("$" .. price.Value), color)
		if owner then scheduleRefresh(owner) end
	end

	pad.Touched:Connect(function(hit)
		if processing or active.Value or not centreActive.Value or plot:GetAttribute("RestoringProgress") then return end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not player or player ~= getOwner() or not player:GetAttribute("DataLoaded")
			or not humanoid or humanoid.Health <= 0 or not root
			or (root.Position - pad.Position).Magnitude > 9 then return end
		local cash = getCash(player)
		if not cash or cash.Value < price.Value or price.Value < 0 then applyState() return end
		-- No yielding between validation, debit and ownership commit.
		processing = true
		cash.Value -= price.Value
		active.Value = true
		refreshPlayer(player)
		PurchaseEffect.PlayAcrossParts({display}, {color = PlotTheme.GetPlotColor(plot)})
		PurchaseSound.PlayPurchaseForTarget(player, pad)
		task.delay(0.6, function() processing = false applyState() end)
	end)
	active.Changed:Connect(applyState)
	centreActive.Changed:Connect(applyState)
	price.Changed:Connect(applyState)
	station.Config.Level.Changed:Connect(applyState)
	plot:GetAttributeChangedSignal("Owner"):Connect(applyState)
	plot:GetAttributeChangedSignal("PlotColor"):Connect(applyState)
	plot:GetAttributeChangedSignal("RestoringProgress"):Connect(applyState)
	states[plot] = applyState
	applyState()
end

for index = 1, 10 do wirePlot(workspace:WaitForChild("P" .. index)) end
print("[ThrowableBallStationService] Wired 10 Avatar throwable ball stations.")

