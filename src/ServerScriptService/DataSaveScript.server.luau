local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local TycoonProgressService = require(script.Parent.TycoonProgressService)
local TutorialProgressService = require(script.Parent.TutorialProgressService)
local WorkerGiftCooldownService = require(script.Parent.WorkerGiftCooldownService)
local PurchaseReceiptService = require(script.Parent.PurchaseReceiptService)

-- v3 intentionally starts every player with a clean save.
-- The old v2 store remains isolated and untouched for rollback if needed.
local DATA_STORE_NAME = "PlayerCashData_v3"
local playerDataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)

local AUTOSAVE_INTERVAL_SECONDS = 60
local MAX_SAVE_ATTEMPTS = 3

-- Session locking. Each save record carries a SessionLock naming the one
-- player-session allowed to write it. Without it, a player who switches
-- servers quickly can be loaded by the new server before the old server's
-- leave-save lands, and the stale copy then overwrites the newer save --
-- which would lose Robux purchases. Every save checks it still holds the
-- lock; the leave-save releases it.
--
-- A lock untouched for this long belongs to a server that died; take it at once.
local LOCK_STALE_SECONDS = AUTOSAVE_INTERVAL_SECONDS * 5
-- Otherwise wait this long for the other server to release it, then take it
-- anyway. That server's next save sees it lost the lock and writes nothing.
local LOCK_WAIT_ATTEMPTS = 6
local LOCK_RETRY_SECONDS = 5
local SHUTDOWN_SAVE_TIMEOUT_SECONDS = 25

-- Weak-keyed so entries disappear with the Player.
local sessionIdByPlayer = setmetatable({}, { __mode = "k" })
local saveBusy = setmetatable({}, { __mode = "k" })
local sessionReleased = setmetatable({}, { __mode = "k" })
local activeSaveCount = 0

local function newLock(sessionId)
	return {
		SessionId = sessionId,
		JobId = game.JobId,
		Time = os.time(),
	}
end

local function isHeldByAnotherSession(lock, sessionId)
	return type(lock) == "table"
		and lock.SessionId ~= sessionId
		and type(lock.Time) == "number"
		and os.time() - lock.Time < LOCK_STALE_SECONDS
end

-- Every real save writes Cash. A record without it only holds a lock, e.g.
-- from a server that died before the player's first save, and must still
-- read as a brand-new player (TutorialProgressService treats any saved table
-- as a returning player).
local function hasPlayerData(record)
	return type(record) == "table" and record.Cash ~= nil
end

-- Loads the player's record and takes its session lock in one atomic write.
-- Returns (loadSucceeded, savedData), where savedData is nil for a new player.
local function loadAndLock(player, sessionId)
	for attempt = 1, LOCK_WAIT_ATTEMPTS + 1 do
		local force = attempt > LOCK_WAIT_ATTEMPTS
		local blocked = false
		local savedData = nil

		local success, err = pcall(function()
			playerDataStore:UpdateAsync(player.UserId, function(current)
				local record = type(current) == "table" and current or {}
				if not force and isHeldByAnotherSession(record.SessionLock, sessionId) then
					blocked = true
					savedData = nil
					return nil
				end
				blocked = false
				savedData = hasPlayerData(record) and record or nil
				record.SessionLock = newLock(sessionId)
				return record
			end)
		end)

		if not success then
			warn("Failed to load data for " .. player.Name .. ": " .. tostring(err))
			return false, nil
		end
		if not blocked then
			if force then
				warn("Took over " .. player.Name .. "'s save from a server that did not release it in time.")
			end
			return true, savedData
		end
		if not player.Parent then
			return false, nil
		end
		task.wait(LOCK_RETRY_SECONDS)
	end
	return false, nil
end

-- Used when the player leaves after the lock was taken but before loading
-- finished, so the next server doesn't have to wait the lock out.
local function releaseLock(player, sessionId)
	pcall(function()
		playerDataStore:UpdateAsync(player.UserId, function(current)
			if type(current) ~= "table" or type(current.SessionLock) ~= "table"
				or current.SessionLock.SessionId ~= sessionId then
				return nil
			end
			current.SessionLock = nil
			return current
		end)
	end)
end

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

	local gemData = Instance.new("Folder")
	gemData.Name = "GemData"
	gemData.Parent = player

	-- Gems the player is carrying. Earned through gameplay, not yet safe.
	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = 0
	gems.Parent = gemData

	-- Gems stored in the bank. BankZoneHandler deposits carried gems here, and
	-- PurchaseReceiptService grants bought gems here.
	local bankedGems = Instance.new("IntValue")
	bankedGems.Name = "BankedGems"
	bankedGems.Value = 0
	bankedGems.Parent = gemData

	local sessionId = HttpService:GenerateGUID(false)
	sessionIdByPlayer[player] = sessionId
	local success, savedData = loadAndLock(player, sessionId)

	if not player.Parent then
		-- Left while loading. Nothing was handed out, so nothing to save.
		if success then
			releaseLock(player, sessionId)
		end
		return
	end

	if success and type(savedData) == "table" then
		cash.Value = tonumber(savedData.Cash) or 0
		gems.Value = math.max(0, math.floor(tonumber(savedData.Gems) or 0))
		bankedGems.Value = math.max(0, math.floor(tonumber(savedData.BankedGems) or 0))
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

	-- Deliberately passes the raw pcall result rather than a "savedData == nil"
	-- test: only the service can tell a brand-new player apart from a failed
	-- load, and getting that wrong replays the tutorial for existing players.
	TutorialProgressService.Resolve(player, success, savedData)

	-- Same reasoning as above: a failed load must never look like "never
	-- claimed" (which would let a rejoin bypass an active cooldown).
	WorkerGiftCooldownService.Resolve(player, success, savedData)

	if success then
		PurchaseReceiptService.Resolve(player, savedData)
	end

	player:SetAttribute("DataLoaded", true)
end)

local function getPlayerData(player)
	local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
	local gemData = player:FindFirstChild("GemData")
	local gems = gemData and gemData:FindFirstChild("Gems")
	local bankedGems = gemData and gemData:FindFirstChild("BankedGems")
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
		Gems = gems and gems.Value or 0,
		BankedGems = bankedGems and bankedGems.Value or 0,
		UpgradeLevel = upgradeLevel,
		CentreLevel = centreLevel,
		PlotColor = serializedPlotColor,
		TycoonProgress = TycoonProgressService.GetDepartureProgress(player)
			or TycoonProgressService.CapturePlot(plot),
		PurchasedItems = purchasedItems,
		Tutorial = TutorialProgressService.Serialize(player),
		LastWorkerGiftClaim = WorkerGiftCooldownService.Serialize(player),
		ProcessedReceipts = PurchaseReceiptService.Serialize(player),
	}
end

local function onSessionLost(player)
	player:SetAttribute("DataSessionLost", true)
	warn("Stopped saving " .. player.Name .. ": their save was taken over by another session.")
	if player.Parent then
		player:Kick("Your data was opened on another server. Please rejoin.")
	end
end

-- Pass releaseLock = true for the final save of a session.
local function savePlayer(player, releaseLock)
	-- Never save before loading finished: the values would still be defaults.
	if not player:GetAttribute("DataLoaded") then
		return false
	end
	if player:GetAttribute("DataLoadFailed") then
		warn("Skipped saving " .. player.Name .. " because their data did not load successfully.")
		return false
	end
	if player:GetAttribute("DataSessionLost") or sessionReleased[player] then
		return false
	end

	activeSaveCount += 1
	-- One save per player at a time, so an older payload can never land after
	-- a newer one (e.g. an autosave racing a purchase save).
	while saveBusy[player] do
		task.wait(0.1)
	end
	if player:GetAttribute("DataSessionLost") or sessionReleased[player] then
		activeSaveCount -= 1
		return false
	end
	saveBusy[player] = true

	local sessionId = sessionIdByPlayer[player]
	local dataToSave = getPlayerData(player)
	dataToSave.SessionLock = if releaseLock then nil else newLock(sessionId)

	local saved = false
	local lostLock = false
	local lastError

	for attempt = 1, MAX_SAVE_ATTEMPTS do
		local success, err = pcall(function()
			playerDataStore:UpdateAsync(player.UserId, function(current)
				local lock = type(current) == "table" and current.SessionLock
				if type(lock) ~= "table" or lock.SessionId ~= sessionId then
					lostLock = true
					return nil
				end
				lostLock = false
				return dataToSave
			end)
		end)

		if success then
			if lostLock then
				onSessionLost(player)
			else
				saved = true
				player:SetAttribute("LastSaveTime", os.time())
				if releaseLock then
					sessionReleased[player] = true
				end
			end
			break
		end

		lastError = err
		if attempt < MAX_SAVE_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end

	if not saved and not lostLock then
		warn("Failed to save data for " .. player.Name .. ": " .. tostring(lastError))
	end

	saveBusy[player] = nil
	activeSaveCount -= 1
	return saved
end

PurchaseReceiptService.Start(savePlayer)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player, true)
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
	-- Final saves run in parallel, and this also waits for leave-saves that
	-- PlayerRemoving already started, so shutdown can't cut them off.
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(savePlayer, player, true)
	end
	task.wait()
	local deadline = os.clock() + SHUTDOWN_SAVE_TIMEOUT_SECONDS
	while activeSaveCount > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)
