-- Stack counts live in PurchasedItems, which DataSaveScript already serializes.
-- Purchase deadlines are absolute Unix timestamps, so leaving does not reset them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("OrbConfig"))
local Effects = require(script.Parent:WaitForChild("OrbEffectService"))
local Service = {}
local pending = {}
local ready = {}
local refreshing = {}
local toolsByPlayer = {}

local function cooldownAttribute(kind)
    return "Orb" .. kind .. "NextPurchaseAt"
end

local function getCountValue(player, kind)
    local folder = player:FindFirstChild("PurchasedItems")
    local data = Config.Types[kind]
    local value = folder and data and folder:FindFirstChild(data.ItemId)
    return value and value:IsA("IntValue") and value or nil
end

function Service.GetCount(player, kind)
    local value = getCountValue(player, kind)
    return value and value.Value or 0
end

function Service.GetCooldownRemaining(player, kind)
    local deadline = player:GetAttribute(cooldownAttribute(kind))
    return math.max(0, (type(deadline) == "number" and deadline or 0) - os.time())
end

function Service.Resolve(player, savedData)
    local saved = type(savedData) == "table" and savedData.OrbPurchaseCooldowns
    for _, kind in ipairs(Config.Order) do
        local deadline = type(saved) == "table" and saved[kind]
        if type(deadline) ~= "number" or deadline ~= deadline or deadline == math.huge then deadline = 0 end
        -- Clamp malformed future values without allowing a valid five-minute deadline to reset.
        player:SetAttribute(cooldownAttribute(kind), math.clamp(math.floor(deadline), 0, os.time() + Config.PurchaseCooldown))
    end
end

function Service.Serialize(player)
    local result = {}
    for _, kind in ipairs(Config.Order) do
        local deadline = player:GetAttribute(cooldownAttribute(kind)) or 0
        if deadline > os.time() then result[kind] = deadline end
    end
    return result
end

function Service.RefreshTools(player)
    if not ready[player] or not player.Parent then return end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end
    local tools = toolsByPlayer[player] or {}
    toolsByPlayer[player] = tools
    for _, kind in ipairs(Config.Order) do
        local count = Service.GetCount(player, kind)
        local tool = tools[kind]
        -- Keep exactly one live stack Tool; quantities never live in StarterGear.
        for _, container in ipairs({backpack, player.Character}) do
            if container then
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("Tool") and child:GetAttribute("OrbType") == kind and child ~= tool then
                        child:Destroy()
                    end
                end
            end
        end
        if tool and (not tool.Parent or (tool.Parent ~= backpack and tool.Parent ~= player.Character)) then
            tool:Destroy()
            tool = nil
            tools[kind] = nil
        end
        if count <= 0 then
            if tool then tool:Destroy() end
            tools[kind] = nil
        else
            if not tool then
                tool = ServerStorage.OrbTools[Config.Types[kind].ToolName]:Clone()
                tools[kind] = tool
                tool.Parent = backpack
            end
            tool:SetAttribute("StackCount", count)
            tool.ToolTip = Config.Types[kind].ToolName .. " • " .. count .. "x • " .. Config.Types[kind].Description
        end
    end
end

local function scheduleRefresh(player)
    if refreshing[player] then return end
    refreshing[player] = true
    task.defer(function()
        refreshing[player] = nil
        Service.RefreshTools(player)
    end)
end

function Service.Initialize(player)
    if ready[player] then return end
    local folder = player:FindFirstChild("PurchasedItems")
    if not folder then return end
    ready[player] = true
    for _, kind in ipairs(Config.Order) do
        local value = getCountValue(player, kind)
        if not value then
            value = Instance.new("IntValue")
            value.Name = Config.Types[kind].ItemId
            value.Parent = folder
        end
        value.Value = math.clamp(value.Value, 0, Config.MaxStack)
        value.Changed:Connect(function() scheduleRefresh(player) end)
    end
    Service.RefreshTools(player)
end

-- This function cannot yield: validation, cash debit, count and deadline are one commit.
function Service.TryPurchase(player, kind)
    local data = Config.Types[kind]
    local count = data and getCountValue(player, kind)
    if not ready[player] or not player:GetAttribute("DataLoaded") or player:GetAttribute("DataLoadFailed") or not count then
        return false, "Data loading"
    end
    if Service.GetCooldownRemaining(player, kind) > 0 then return false, "Cooldown" end
    if count.Value >= Config.MaxStack then return false, "Stack full" end
    local stats = player:FindFirstChild("leaderstats")
    local cash = stats and stats:FindFirstChild("Cash")
    if not cash or cash.Value < data.Price then return false, "Not enough cash" end
    cash.Value -= data.Price
    count.Value += 1
    player:SetAttribute(cooldownAttribute(kind), os.time() + Config.PurchaseCooldown)
    Service.RefreshTools(player)
    return true
end

local function clearEating(character)
    if character then
        character:SetAttribute("OrbEatingType", "")
        character:SetAttribute("OrbEatingStartedAt", 0)
        character:SetAttribute("OrbEatingEndsAt", 0)
    end
end

function Service.CancelConsumption(player)
    local operation = pending[player]
    if not operation then return end
    pending[player] = nil
    clearEating(operation.character)
    if operation.tool.Parent then
        if operation.tween then operation.tween:Cancel() end
        operation.tool.Enabled = true
        operation.tool.Handle.Size = operation.handleSize
    end
end

function Service.Consume(player, kind)
    local data = type(kind) == "string" and Config.Types[kind]
    local tools = toolsByPlayer[player]
    local tool = data and tools and tools[kind]
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if pending[player] or not ready[player] or not player:GetAttribute("DataLoaded")
        or player:GetAttribute("DataLoadFailed") or not tool or tool.Parent ~= character
        or not humanoid or humanoid.Health <= 0 or humanoid.PlatformStand or Service.GetCount(player, kind) < 1 then
        return false
    end
    local operation = {tool = tool, character = character, handleSize = tool.Handle.Size}
    pending[player] = operation
    tool.Enabled = false
    local started = workspace:GetServerTimeNow()
    character:SetAttribute("OrbEatingType", kind)
    character:SetAttribute("OrbEatingStartedAt", started)
    character:SetAttribute("OrbEatingEndsAt", started + Config.EatDuration)
    -- Shrink the edible orb at the bite; the client animates the arm on every viewing client.
    task.delay(Config.EatDuration - 0.28, function()
        if pending[player] == operation and tool.Parent == character then
            operation.tween = TweenService:Create(tool.Handle, TweenInfo.new(0.25), {Size = Vector3.one * 0.12})
            operation.tween:Play()
        end
    end)
    task.delay(Config.EatDuration, function()
        if pending[player] ~= operation then return end
        if tool.Parent ~= character or player.Character ~= character or humanoid.Health <= 0 or humanoid.PlatformStand then
            Service.CancelConsumption(player)
            return
        end
        local count = getCountValue(player, kind)
        if not count or count.Value < 1 then Service.CancelConsumption(player) return end
        -- Only a completed bite spends one item. Unequipping/death cancels it.
        count.Value -= 1
        Effects.Apply(player, kind)
        pending[player] = nil
        clearEating(character)
        humanoid:UnequipTools()
        if tool.Parent then tool.Handle.Size = operation.handleSize tool.Enabled = true end
        Service.RefreshTools(player)
    end)
    return true
end

function Service.ConnectPlayer(player)
    toolsByPlayer[player] = {}
    Effects.ConnectPlayer(player)
    player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
        if player:GetAttribute("DataLoaded") then Service.Initialize(player) end
    end)
    player.CharacterAdded:Connect(function(character)
        toolsByPlayer[player] = {}
        task.defer(function() Service.RefreshTools(player) end)
        character.ChildRemoved:Connect(function(child)
            local operation = pending[player]
            if operation and operation.tool == child then Service.CancelConsumption(player) end
        end)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then humanoid.Died:Connect(function() Service.CancelConsumption(player) end) end
    end)
    player.CharacterRemoving:Connect(function()
        Service.CancelConsumption(player)
        toolsByPlayer[player] = {}
    end)
    player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then scheduleRefresh(player) end
    end)
    if player:GetAttribute("DataLoaded") then Service.Initialize(player) end
end

function Service.RemovePlayer(player)
    Service.CancelConsumption(player)
    Effects.Clear(player)
    ready[player] = nil
    toolsByPlayer[player] = nil
    refreshing[player] = nil
end

return Service
