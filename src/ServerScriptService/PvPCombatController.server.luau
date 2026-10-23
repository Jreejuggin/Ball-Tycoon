local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PvP = require(script.Parent.PvPCombatService)
local Damage = require(script.Parent.CombatDamageService)
local remote = RS.PvPRemotes.Action
local lastRequest = {}
local connections = {}
local function connect(player)
    local list = {}
    connections[player] = list
    local death
    local function attach(character)
        PvP.ResetCharacter(player)
        if death then death:Disconnect() end
        local hum = character:WaitForChild("Humanoid", 10)
        if player.Character ~= character or not hum then return end
        death = hum.Died:Connect(function() PvP.OnDeath(player) end)
    end
    table.insert(list, player.CharacterAdded:Connect(attach))
    table.insert(list, player.CharacterRemoving:Connect(function()
        if death then death:Disconnect() death = nil end
        PvP.ResetCharacter(player)
    end))
    list.cleanup = function() if death then death:Disconnect() end end
    if player.Character then task.spawn(attach, player.Character) end
end
remote.OnServerEvent:Connect(function(player, action, direction)
    if action ~= "Guard" and action ~= "Dodge" and action ~= "Recover" then return end
    local t = os.clock()
    if t - (lastRequest[player] or -math.huge) < 0.07 then return end
    lastRequest[player] = t
    if action == "Guard" then PvP.Guard(player)
    elseif action == "Dodge" then PvP.Dodge(player, direction)
    else
        local character = PvP.TryRecover(player)
        if character then Damage.RecoverCharacter(character) end
    end
end)
Players.PlayerAdded:Connect(connect)
Players.PlayerRemoving:Connect(function(player)
    local list = connections[player]
    if list then for _, c in ipairs(list) do c:Disconnect() end list.cleanup() end
    connections[player], lastRequest[player] = nil, nil
    PvP.RemovePlayer(player)
end)
for _, player in Players:GetPlayers() do connect(player) end
print("[PvPCombatController] Combos, timed guards, dodge and recovery enabled.")
