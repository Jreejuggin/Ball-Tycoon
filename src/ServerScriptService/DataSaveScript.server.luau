-- DataSaveScript: resolved merge of Avatar_Orbs_Speed_Protection and main.
-- Saving is kept inside this Script so no other file needs to be rewritten.
-- Existing service modules keep their current interfaces and implementations.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Progress = require(script.Parent.TycoonProgressService)
local Tutorial = require(script.Parent.TutorialProgressService)
local WorkerGifts = require(script.Parent.WorkerGiftCooldownService)
local Orbs = require(script.Parent.OrbInventoryService)
local Receipts = require(script.Parent.PurchaseReceiptService)


-- Private save helpers: do not also call the older PlayerDataSaveService writer.
local SaveService = (function()
	local Service = {}
	local store = DataStoreService:GetDataStore("PlayerCashData_v3")
	local SAVE_ATTEMPTS = 3
	local LOCK_STALE_SECONDS = 300
	local LOAD_ATTEMPTS = 13
	local LOCK_RETRY_SECONDS = 5
	local SHUTDOWN_TIMEOUT_SECONDS = 25
	local sessions = setmetatable({}, { __mode = "k" })
	local closing = false
	local activeOperations = 0

	function Service.IsClosing()
		return closing
	end

	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[key] = copy(child) end
		return result
	end

	local function stateFor(player)
		local state = sessions[player]
		if not state then
			state = { id = HttpService:GenerateGUID(false), sequence = 0 }
			sessions[player] = state
		end
		return state
	end

	local function lockFor(state)
		return { SessionId = state.id, JobId = game.JobId, Time = os.time() }
	end

	local function canSave(player, state)
		return state.loaded == true and not state.lost
			and player:GetAttribute("DataLoaded") == true
			and not player:GetAttribute("DataLoadFailed")
			and not player:GetAttribute("DataSessionLost")
	end

	local function markSessionLost(player, state)
		state.lost = true
		player:SetAttribute("DataSessionLost", true)
		warn("[DataSaveScript] Save lock lost for " .. player.Name)
		if player.Parent then
			player:Kick("Your data session changed. Please rejoin.")
		end
	end

	-- Load and lock atomically. A still-active lock is never forcibly stolen.
	function Service.Load(player)
		local state = stateFor(player)
		if state.loaded or state.loading or closing then return false, nil end
		state.loading = true
		activeOperations += 1
		local loaded, savedData = false, nil
		local consecutiveErrors = 0
		for attempt = 1, LOAD_ATTEMPTS do
			if not player.Parent or closing then break end
			local acquired = false
			local recordData = nil
			local ok, err = pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(current)
					-- UpdateAsync may invoke this callback more than once.
					acquired, recordData = false, nil
					if not player.Parent or closing then return nil end
					if current ~= nil and type(current) ~= "table" then
						error("Unexpected save format; refusing to replace it")
					end
					local record = type(current) == "table" and copy(current) or {}
					local lock = record.SessionLock
					if type(lock) == "table" and lock.SessionId ~= state.id then
						local time = tonumber(lock.Time)
						if not time or time ~= time or os.time() - time < LOCK_STALE_SECONDS then
							return nil
						end
					end
					-- A lock-only record still represents a new player.
					recordData = record.Cash ~= nil and copy(record) or nil
					record.SessionLock = lockFor(state)
					acquired = true
					return record
				end)
			end)
			if ok and acquired then
				state.loaded = true
				loaded, savedData = true, recordData
				break
			end
			if not ok then
				consecutiveErrors += 1
				warn("[DataSaveScript] Load attempt failed: " .. tostring(err))
				if consecutiveErrors >= SAVE_ATTEMPTS then break end
			else
				consecutiveErrors = 0
			end
			if attempt < LOAD_ATTEMPTS and player.Parent and not closing then
				task.wait(LOCK_RETRY_SECONDS)
			end
		end
		state.loading = false
		activeOperations -= 1
		return loaded, savedData
	end

	-- A player can leave after lock acquisition but before initialization completes.
	-- Do not write default cash/progress in that case; release only our own lock.
	function Service.AbortLoad(player)
		local state = sessions[player]
		if not state or not state.loaded or state.released then return end
		activeOperations += 1
		for attempt = 1, SAVE_ATTEMPTS do
			local ok, err = pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(current)
					local lock = type(current) == "table" and current.SessionLock
					if type(lock) ~= "table" or lock.SessionId ~= state.id then return nil end
					local record = copy(current)
					record.SessionLock = nil
					return record
				end)
			end)
			if ok then state.released = true break end
			warn("[DataSaveScript] Lock release failed: " .. tostring(err))
			if attempt < SAVE_ATTEMPTS then task.wait(2 ^ (attempt - 1)) end
		end
		activeOperations -= 1
	end

	function Service.GetOwnedPlot(player)
		local name = player:GetAttribute("AssignedPlotName")
		local plot = type(name) == "string" and workspace:FindFirstChild(name)
		if plot and plot:GetAttribute("Owner") == player.UserId then return plot end
		for index = 1, 10 do
			plot = workspace:FindFirstChild("P" .. index)
			if plot and plot:GetAttribute("Owner") == player.UserId then return plot end
		end
		return nil
	end

	local function capture(player)
		local plot = Service.GetOwnedPlot(player)
		local stats = player:FindFirstChild("leaderstats")
		local cash = stats and stats:FindFirstChild("Cash")
		local gemData = player:FindFirstChild("GemData")
		local gems = gemData and gemData:FindFirstChild("Gems")
		local bank = gemData and gemData:FindFirstChild("BankedGems")
		assert(cash and gems and bank, "Player currency values are missing; refusing a partial save")
		local folder = player:FindFirstChild("PurchasedItems")
		assert(folder, "PurchasedItems is missing; refusing a partial save")
		local items = {}
		for _, value in ipairs(folder:GetChildren()) do
			if value:IsA("IntValue") and value.Value > 0 then items[value.Name] = value.Value end
		end
		-- No owned plot yet must preserve the loaded player's progress.
		local progress = plot and Progress.CapturePlot(plot)
			or Progress.GetDepartureProgress(player) or Progress.GetLoadedProgress(player)
		local color = player:GetAttribute("SavedPlotColor")
		return copy({
			Cash = cash.Value,
			Gems = gems.Value,
			BankedGems = bank.Value,
			UpgradeLevel = (plot and tonumber(plot:GetAttribute("UpgradeLevel")))
				or tonumber(player:GetAttribute("SavedUpgradeLevel")) or 1,
			CentreLevel = math.clamp(math.floor(tonumber(player:GetAttribute("CentreLevel")) or 0), 0, 5),
			PlotColor = typeof(color) == "Color3" and { R = color.R, G = color.G, B = color.B } or nil,
			TycoonProgress = progress,
			PurchasedItems = items,
			Tutorial = Tutorial.Serialize(player),
			LastWorkerGiftClaim = WorkerGifts.Serialize(player),
			OrbPurchaseCooldowns = Orbs.Serialize(player),
			ProcessedReceipts = Receipts.Serialize(player),
		})
	end

	function Service.CaptureFinal(player)
		local state = stateFor(player)
		if not state.finalData and canSave(player, state) then
			-- Capture synchronously, before cleanup handlers can change the plot.
			state.finalData = capture(player)
			player:SetAttribute("DataClosing", true)
		end
		return state.finalData
	end

	function Service.ReleasePlot(player)
		Service.CaptureFinal(player)
		local plot = Service.GetOwnedPlot(player)
		if not plot then return end
		local state = stateFor(player)
		if state.finalData then
			Progress.SetDepartureProgress(player, copy(state.finalData.TycoonProgress))
		end
		-- These existing progress-service methods must remain non-yielding.
		plot:SetAttribute("RestoringProgress", true)
		Progress.ResetPlot(plot)
		plot:SetAttribute("UpgradeLevel", 1)
		plot:SetAttribute("OwnerName", nil)
		player:SetAttribute("AssignedPlotName", nil)
		plot:SetAttribute("RestoringProgress", nil)
		plot:SetAttribute("Owner", nil) -- advertise availability only after cleanup
	end

	local function writeSnapshot(player, state, data, isFinal, sequence)
		local lastError
		for attempt = 1, SAVE_ATTEMPTS do
			local outcome = nil
			local ok, err = pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(current)
					outcome = nil
					-- Retry safely if the write committed but its response was lost.
					if type(current) == "table" and current.LastSaveSessionId == state.id
						and current.LastSaveSequence == sequence then
						outcome = "saved"
						return nil
					end
					local lock = type(current) == "table" and current.SessionLock
					if type(lock) ~= "table" or lock.SessionId ~= state.id then
						outcome = "lost"
						return nil
					end
					-- Retain unrelated fields introduced by other compatible systems.
					local record = copy(current)
					for key, value in pairs(data) do record[key] = copy(value) end
					record.PlotColor = copy(data.PlotColor)
					record.SessionLock = if isFinal then nil else lockFor(state)
					record.LastSaveSessionId = state.id
					record.LastSaveSequence = sequence
					outcome = "saved"
					return record
				end)
			end)
			if ok and outcome == "saved" then
				if isFinal then state.released = true end
				local count = 0
				for _ in pairs(type(data.TycoonProgress.Values) == "table" and data.TycoonProgress.Values or {}) do
					count += 1
				end
				player:SetAttribute("LastSaveTime", os.time())
				player:SetAttribute("LastSavedProgressValueCount", count)
				player:SetAttribute("LastSaveFailed", false)
				return true
			elseif ok and outcome == "lost" then
				markSessionLost(player, state)
				return false
			end
			lastError = err
			if attempt < SAVE_ATTEMPTS then task.wait(2 ^ (attempt - 1)) end
		end
		player:SetAttribute("LastSaveFailed", true)
		warn("[DataSaveScript] Save failed for " .. player.Name .. ": " .. tostring(lastError))
		return false
	end

	function Service.Save(player, isFinal)
		local state = stateFor(player)
		if not canSave(player, state) then return false end
		-- Receipts must never acknowledge a grant made after the snapshot froze.
		if not isFinal and (closing or state.finalData or state.released) then return false end
		if state.released then return isFinal == true end
		if isFinal then Service.CaptureFinal(player) end
		activeOperations += 1
		while state.busy do task.wait(0.1) end
		if state.released or state.lost then
			activeOperations -= 1
			return state.released == true and isFinal == true
		end
		state.busy = true
		local ok, result = xpcall(function()
			if not canSave(player, state) then return false end
			-- A final snapshot may have been captured while this save was queued.
			local final = state.finalData ~= nil
			local data = state.finalData or capture(player)
			state.sequence += 1
			local saved = writeSnapshot(player, state, data, final, state.sequence)
			-- An ordinary/receipt save cannot certify a frozen final snapshot.
			return saved and (not final or isFinal == true)
		end, debug.traceback)
		state.busy = false
		activeOperations -= 1
		if not ok then
			player:SetAttribute("LastSaveFailed", true)
			warn("[DataSaveScript] " .. tostring(result))
			return false
		end
		return result == true
	end

	function Service.Close()
		closing = true
		local deadline = os.clock() + SHUTDOWN_TIMEOUT_SECONDS
		-- Include departed Players whose final save is already pending or failed.
		local targets = {}
		for player, state in pairs(sessions) do
			local ok, err = pcall(Service.CaptureFinal, player)
			if not ok then warn("[DataSaveScript] Shutdown capture failed: " .. tostring(err)) end
			if state.finalData and not state.released and not state.lost then table.insert(targets, player) end
		end
		local pending = #targets
		for _, player in ipairs(targets) do
			task.spawn(function()
				local ok, err = pcall(Service.Save, player, true)
				if not ok then warn("[DataSaveScript] Shutdown save failed: " .. tostring(err)) end
				pending -= 1
			end)
		end
		while (pending > 0 or activeOperations > 0) and os.clock() < deadline do task.wait(0.1) end
		if pending > 0 or activeOperations > 0 then
			warn("[DataSaveScript] Shutdown deadline reached with unfinished requests")
		end
	end

	return Service

end)()

local AUTOSAVE_INTERVAL_SECONDS = 60
local initialized = setmetatable({}, { __mode = "k" })

local function numberOr(value, fallback)
	local number = tonumber(value)
	if not number or number ~= number or math.abs(number) == math.huge then return fallback end
	return number
end

local function newValue(className, name, parent)
	local value = Instance.new(className)
	value.Name = name
	value.Parent = parent
	return value
end

local function initializePlayer(player)
	if initialized[player] then return end
	initialized[player] = true
	player:SetAttribute("DataLoaded", false)
	local ok, err = xpcall(function()
		local leaderstats = newValue("Folder", "leaderstats", player)
		local cash = newValue("IntValue", "Cash", leaderstats)
		local gemData = newValue("Folder", "GemData", player)
		local gems = newValue("IntValue", "Gems", gemData)
		local bankedGems = newValue("IntValue", "BankedGems", gemData)
		local success, savedData = SaveService.Load(player)
		if not success then error("Could not acquire and load the player's data session") end
		if not player.Parent or SaveService.IsClosing() then
			SaveService.AbortLoad(player)
			return
		end
		local data = type(savedData) == "table" and savedData or {}
		cash.Value = numberOr(data.Cash, 0)
		gems.Value = math.max(0, math.floor(numberOr(data.Gems, 0)))
		bankedGems.Value = math.max(0, math.floor(numberOr(data.BankedGems, 0)))
		player:SetAttribute("SavedUpgradeLevel", math.max(1, math.floor(numberOr(data.UpgradeLevel, 1))))
		local centreLevel = math.clamp(math.floor(numberOr(data.CentreLevel, 0)), 0, 5)
		player:SetAttribute("SavedCentreLevel", centreLevel)
		player:SetAttribute("CentreLevel", centreLevel)
		if type(data.PlotColor) == "table" then
			local red = numberOr(data.PlotColor.R, nil)
			local green = numberOr(data.PlotColor.G, nil)
			local blue = numberOr(data.PlotColor.B, nil)
			if red and green and blue then
				player:SetAttribute("SavedPlotColor", Color3.new(
					math.clamp(red, 0, 1), math.clamp(green, 0, 1), math.clamp(blue, 0, 1)
				))
			end
		end
		local progress = type(data.TycoonProgress) == "table" and data.TycoonProgress or {}
		local count = 0
		for _ in pairs(type(progress.Values) == "table" and progress.Values or {}) do count += 1 end
		player:SetAttribute("LoadedProgressSchema", numberOr(progress.SchemaVersion, 0))
		player:SetAttribute("LoadedProgressValueCount", count)
		Progress.SetLoadedProgress(player, progress)
		local items = newValue("Folder", "PurchasedItems", player)
		if type(data.PurchasedItems) == "table" then
			for itemId, quantity in pairs(data.PurchasedItems) do
				local amount = math.max(0, math.floor(numberOr(quantity, 0)))
				if type(itemId) == "string" and amount > 0 then
					newValue("IntValue", itemId, items).Value = amount
				end
			end
		end
		Tutorial.Resolve(player, true, savedData)
		WorkerGifts.Resolve(player, true, savedData)
		Orbs.Resolve(player, savedData)
		Receipts.Resolve(player, savedData)
		-- Assignment and inventory initialization may only begin after all restores.
		player:SetAttribute("DataLoaded", true)
	end, debug.traceback)
	if not ok then
		player:SetAttribute("DataLoadFailed", true)
		warn("[DataSaveScript] Initialization failed for " .. player.Name .. ": " .. tostring(err))
		SaveService.AbortLoad(player)
		if player.Parent then player:Kick("Your saved data could not be loaded safely. Please rejoin.") end
	end
end

-- This is the only departure owner. PlotAssignmentScript must not reset plots.
Players.PlayerRemoving:Connect(function(player)
	local ok, err = pcall(function()
		SaveService.ReleasePlot(player) -- freezes full data BEFORE resetting the plot
		SaveService.Save(player, true) -- yielding DataStore write uses that snapshot
	end)
	if not ok then warn("[DataSaveScript] Departure failed: " .. tostring(err)) end
end)

Receipts.Start(function(player)
	return SaveService.Save(player, false)
end)
Players.PlayerAdded:Connect(initializePlayer)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(initializePlayer, player) end

task.spawn(function()
	while not SaveService.IsClosing() do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		if SaveService.IsClosing() then break end
		for _, player in ipairs(Players:GetPlayers()) do task.spawn(SaveService.Save, player, false) end
	end
end)

game:BindToClose(SaveService.Close)


  