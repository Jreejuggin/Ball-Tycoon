-- Own movement speed on the server; clients request only sprint on/off.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Effects = require(script.Parent:WaitForChild("OrbEffectService"))
local remote = ReplicatedStorage:WaitForChild("OrbRemotes"):WaitForChild("Sprint")
local sprinting = {}
local lastRequest = {}
local characterConnections = {}

local function apply(player)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local sprintMultiplier = tonumber(player:GetAttribute("SprintSpeedMultiplier")) or 1
    local base = sprinting[player] and 44 * math.clamp(sprintMultiplier, 1, 3) or 16
    humanoid.WalkSpeed = base * Effects.GetSpeedMultiplier(player)
    player:SetAttribute("IsSprinting", sprinting[player] == true)
end

local function connectPlayer(player)
    local function attach(character)
        sprinting[player] = false
        local old = characterConnections[player]
        if old then old:Disconnect() end
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end
        characterConnections[player] = humanoid.Died:Connect(function()
            sprinting[player] = false
            apply(player)
        end)
        apply(player)
    end
    player.CharacterAdded:Connect(attach)
    player:GetAttributeChangedSignal("SprintSpeedMultiplier"):Connect(function() apply(player) end)
    player:GetAttributeChangedSignal("OrbSpeedMultiplier"):Connect(function() apply(player) end)
    if player.Character then task.spawn(attach, player.Character) end
end
remote.OnServerEvent:Connect(function(player, enabled)
    if type(enabled) ~= "boolean" then return end
    local time = os.clock()
    -- Releasing sprint always succeeds, even immediately after pressing it.
    if enabled and time - (lastRequest[player] or -math.huge) < 0.08 then return end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    lastRequest[player] = time
    sprinting[player] = enabled
    apply(player)
end)
Players.PlayerAdded:Connect(connectPlayer)
for _, player in ipairs(Players:GetPlayers()) do connectPlayer(player) end
Players.PlayerRemoving:Connect(function(player)
    local connection = characterConnections[player]
    if connection then connection:Disconnect() end
    characterConnections[player] = nil
    sprinting[player] = nil
    lastRequest[player] = nil
end)
