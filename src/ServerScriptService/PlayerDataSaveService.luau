-- PlayerDataSaveService
-- Capture a complete departure snapshot before releasing a shared plot.
-- Serialize writes per Player; different players can save concurrently.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Progress = require(script.Parent.TycoonProgressService)
local Tutorial = require(script.Parent.TutorialProgressService)
local WorkerGifts = require(script.Parent.WorkerGiftCooldownService)
local Orbs = require(script.Parent.OrbInventoryService)

local Service = {}
local store = DataStoreService:GetDataStore("PlayerCashData_v3")
local sessions = setmetatable({}, { __mode = "k" })
local closing = false

local function stateFor(player)
    local state = sessions[player]
    if not state then
        state = {}
        sessions[player] = state
    end
    return state
end

local function canSave(player)
    return player:GetAttribute("DataLoaded") == true
        and player:GetAttribute("DataLoadFailed") ~= true
end

function Service.GetOwnedPlot(player)
    local name = player:GetAttribute("AssignedPlotName")
    local plot = type(name) == "string" and workspace:FindFirstChild(name)
    if plot and plot:GetAttribute("Owner") == player.UserId then
        return plot
    end
    for index = 1, 10 do
        plot = workspace:FindFirstChild("P" .. index)
        if plot and plot:GetAttribute("Owner") == player.UserId then
            return plot
        end
    end
    return nil
end

local function capture(player)
    local plot = Service.GetOwnedPlot(player)
    local stats = player:FindFirstChild("leaderstats")
    local cash = stats and stats:FindFirstChild("Cash")
    local gemsFolder = player:FindFirstChild("GemData")
    local gems = gemsFolder and gemsFolder:FindFirstChild("Gems")
    local bank = gemsFolder and gemsFolder:FindFirstChild("BankedGems")
    local items = {}
    local folder = player:FindFirstChild("PurchasedItems")
    if folder then
        for _, value in folder:GetChildren() do
            if value:IsA("IntValue") and value.Value > 0 then
                items[value.Name] = value.Value
            end
        end
    end
    local color = player:GetAttribute("SavedPlotColor")
    local progress = Progress.GetDepartureProgress(player)
    if not progress then
        -- A load can finish before assignment. Never replace loaded upgrades
        -- with an empty snapshot just because this Player has no plot yet.
        progress = plot and Progress.CapturePlot(plot) or Progress.GetLoadedProgress(player)
    end
    return {
        Cash = cash and cash.Value or 0,
        Gems = gems and gems.Value or 0,
        BankedGems = bank and bank.Value or 0,
        UpgradeLevel = (plot and tonumber(plot:GetAttribute("UpgradeLevel")))
            or tonumber(player:GetAttribute("SavedUpgradeLevel")) or 1,
        CentreLevel = math.clamp(math.floor(tonumber(player:GetAttribute("CentreLevel")) or 0), 0, 5),
        PlotColor = typeof(color) == "Color3" and {R = color.R, G = color.G, B = color.B} or nil,
        TycoonProgress = progress,
        PurchasedItems = items,
        Tutorial = Tutorial.Serialize(player),
        LastWorkerGiftClaim = WorkerGifts.Serialize(player),
        OrbPurchaseCooldowns = Orbs.Serialize(player),
    }
end

function Service.CaptureFinal(player)
    local state = stateFor(player)
    if not state.finalData and canSave(player) then
        state.finalData = capture(player)
    end
    return state.finalData
end

function Service.ReleasePlot(player)
    -- No yields between snapshot and cleanup. DataStore requests happen later.
    Service.CaptureFinal(player)
    local plot = Service.GetOwnedPlot(player)
    if not plot then return end
    Progress.SetDepartureProgress(player, Progress.CapturePlot(plot))
    plot:SetAttribute("RestoringProgress", true)
    Progress.ResetPlot(plot)
    plot:SetAttribute("UpgradeLevel", 1)
    plot:SetAttribute("OwnerName", nil)
    plot:SetAttribute("Owner", nil)
    plot:SetAttribute("RestoringProgress", nil)
end

-- Accepting a writer makes the queue testable without touching real player saves.
function Service.CreateQueue(write)
    local queueStates = setmetatable({}, { __mode = "k" })
    return function(player, getSnapshot, isFinal)
        local state = queueStates[player]
        if not state then
            state = {}
            queueStates[player] = state
        end
        while state.running do task.wait() end
        if state.finalSaved then return true end
        state.running = true
        -- Snapshot after waiting: an older autosave cannot overwrite a departure.
        local final
        local ok, result = pcall(function()
            local snapshot
            snapshot, final = getSnapshot()
            return write(player, snapshot)
        end)
        state.running = false
        if ok and result == true and (isFinal or final) then
            state.finalSaved = true
        end
        if not ok then
            warn("[PlayerDataSaveService] Save error: " .. tostring(result))
        end
        return ok and result == true
    end
end

local queuedSave = Service.CreateQueue(function(player, data)
    local lastError
    for attempt = 1, 3 do
        local ok, err = pcall(function()
            store:UpdateAsync(player.UserId, function() return data end)
        end)
        if ok then
            local count = 0
            for _ in pairs(type(data.TycoonProgress.Values) == "table" and data.TycoonProgress.Values or {}) do
                count += 1
            end
            player:SetAttribute("LastSaveTime", os.time())
            player:SetAttribute("LastSavedProgressValueCount", count)
            player:SetAttribute("LastSaveFailed", false)
            return true
        end
        lastError = err
        if attempt < 3 then task.wait(2 ^ (attempt - 1)) end
    end
    player:SetAttribute("LastSaveFailed", true)
    warn("[PlayerDataSaveService] Failed saving " .. player.Name .. ": " .. tostring(lastError))
    return false
end)

function Service.Save(player, isFinal)
    if not canSave(player) then return false end
    if isFinal or closing then Service.CaptureFinal(player) end
    return queuedSave(player, function()
        local state = stateFor(player)
        return state.finalData or capture(player), state.finalData ~= nil
    end, isFinal == true)
end

function Service.Close()
    closing = true
    -- Freeze everyone's data before launching any yielding write.
    for _, player in Players:GetPlayers() do
        Service.CaptureFinal(player)
    end
    local pending = 0
    for player, state in pairs(sessions) do
        if state.finalData then
            pending += 1
            task.spawn(function()
                Service.Save(player, true)
                pending -= 1
            end)
        end
    end
    while pending > 0 do task.wait() end
end

return Service