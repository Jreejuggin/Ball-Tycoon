local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local TycoonProgressService = require(script.Parent.TycoonProgressService)

-- Changing this version intentionally starts every player with a clean save.
-- The old v1 store remains isolated and is no longer loaded or written.
local DATA_STORE_NAME = "PlayerCashData_v2"
local playerDataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)

local AUTOSAVE_INTERVAL_SECONDS = 60
local MAX_SAVE_ATTEMPTS = 3

local function getAssignedPlot(player)
	local assignedPlotName = player:GetAttribute("AssignedPlotName")
	if type(assignedPlotName) == "string" then
		local assignedPlot = workspace:FindFirstChild(assignedPlotName)
		if assignedPlot then
			return assignedPlot
		end
	end

	for index = 1, 10 do
		local plot = workspace:FindFirstChild("P" .. index)
		if plot and plot:GetAttribute("Owner") == player.UserId then
			return plot
		end
	end
	return nil
end

local function restorePurchasedItems(player, savedItems)
	local purchasedItems = Instance.new("Folder")
	purchasedItems.Name = "PurchasedItems"
	purchasedItems.Parent = player

	if type(savedItems) ~= "table" then
		return
	end

	for itemId, quantity in pairs(savedItems) do
		if type(itemId) == "string" and type(quantity) == "number" and quantity > 0 then
			local ownedCount = Instance.new("IntValue")
			ownedCount.Name = itemId
			ownedCount.Value = math.floor(quantity)
			ownedCount.Parent = purchasedItems
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = leaderstats

	local success, savedData = pcall(function()
		return playerDataStore:GetAsync(player.UserId)
	end)

	if success and type(savedData) == "table" then
		cash.Value = tonumber(savedData.Cash) or 0
		player:SetAttribute("SavedUpgradeLevel", tonumber(savedData.UpgradeLevel) or 1)
	else
		player:SetAttribute("SavedUpgradeLevel", 1)
		if not success then
			player:SetAttribute("DataLoadFailed", true)
			warn("Failed to load data for " .. player.Name .. "; saving is disabled for this session to protect existing data.")
		end
	end

	local savedPlotColorData = success and type(savedData) == "table" and savedData.PlotColor or nil
	if type(savedPlotColorData) == "table" then
		local red = tonumber(savedPlotColorData.R)
		local green = tonumber(savedPlotColorData.G)
		local blue = tonumber(savedPlotColorData.B)
		if red and green and blue then
			player:SetAttribute("SavedPlotColor", Color3.new(
				math.clamp(red, 0, 1),
				math.clamp(green, 0, 1),
				math.clamp(blue, 0, 1)
			))
		end
	end

	local savedCentreLevel = (success and type(savedData) == "table" and tonumber(savedData.CentreLevel)) or 0
	savedCentreLevel = math.clamp(math.floor(savedCentreLevel), 0, 5)
	player:SetAttribute("SavedCentreLevel", savedCentreLevel)
	player:SetAttribute("CentreLevel", savedCentreLevel)

	local savedProgress = (success and type(savedData) == "table" and savedData.TycoonProgress) or {}
	local loadedProgressValueCount = 0
	for _ in pairs(type(savedProgress.Values) == "table" and savedProgress.Values or {}) do
		loadedProgressValueCount += 1
	end
	player:SetAttribute("LoadedProgressSchema", tonumber(savedProgress.SchemaVersion) or 0)
	player:SetAttribute("LoadedProgressValueCount", loadedProgressValueCount)
	TycoonProgressService.SetLoadedProgress(player, savedProgress)
	restorePurchasedItems(player, success and type(savedData) == "table" and savedData.PurchasedItems or nil)

	player:SetAttribute("DataLoaded", true)
end)

local function getPlayerData(player)
	local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
	local plot = getAssignedPlot(player)

	local purchasedItems = {}
	local purchasedItemsFolder = player:FindFirstChild("PurchasedItems")
	if purchasedItemsFolder then
		for _, itemValue in ipairs(purchasedItemsFolder:GetChildren()) do
			if itemValue:IsA("IntValue") and itemValue.Value > 0 then
				purchasedItems[itemValue.Name] = itemValue.Value
			end
		end
	end

	local upgradeLevel = plot and tonumber(plot:GetAttribute("UpgradeLevel")) or 1
	local centreLevel = math.clamp(math.floor(tonumber(player:GetAttribute("CentreLevel")) or 0), 0, 5)
	local plotColor = player:GetAttribute("SavedPlotColor")
	local serializedPlotColor = nil
	if typeof(plotColor) == "Color3" then
		serializedPlotColor = {
			R = plotColor.R,
			G = plotColor.G,
			B = plotColor.B,
		}
	end

	return {
		Cash = cash and cash.Value or 0,
		UpgradeLevel = upgradeLevel,
		CentreLevel = centreLevel,
		PlotColor = serializedPlotColor,
		TycoonProgress = TycoonProgressService.GetDepartureProgress(player)
			or TycoonProgressService.CapturePlot(plot),
		PurchasedItems = purchasedItems,
	}
end

local function savePlayer(player)
	if player:GetAttribute("DataLoadFailed") then
		warn("Skipped saving " .. player.Name .. " because their data did not load successfully.")
		return false
	end

	local dataToSave = getPlayerData(player)
	local lastError

	for attempt = 1, MAX_SAVE_ATTEMPTS do
		local success, err = pcall(function()
			playerDataStore:UpdateAsync(player.UserId, function()
				return dataToSave
			end)
		end)
		if success then
			player:SetAttribute("LastSaveTime", os.time())
			return true
		end

		lastError = err
		if attempt < MAX_SAVE_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end

	warn("Failed to save data for " .. player.Name .. ": " .. tostring(lastError))
	return false
end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	TycoonProgressService.ForgetPlayer(player)
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(savePlayer, player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)