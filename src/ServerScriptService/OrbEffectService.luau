-- Private server state is authoritative; replicated attributes only drive visuals.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OrbConfig"))
local Service = {}
local active = {}

local function now()
    return workspace:GetServerTimeNow()
end

local function removeVisual(character)
    if not character then return end
    for _, name in ipairs({"OrbProtectionForceField", "OrbProtectionBubble", "OrbProtectionHighlight"}) do
        local child = character:FindFirstChild(name)
        if child then child:Destroy() end
    end
end

function Service.Clear(player)
    active[player] = nil
    removeVisual(player.Character)
    player:SetAttribute("ActiveOrbType", "")
    player:SetAttribute("ActiveOrbExpiresAt", 0)
    player:SetAttribute("OrbSpeedMultiplier", 1)
end

function Service.GetSpeedMultiplier(player)
    local effect = active[player]
    if effect and effect.kind == "Speed" and effect.character == player.Character and effect.expiresAt > now() then
        return Config.Types.Speed.Multiplier
    end
    return 1
end

function Service.IsProtectedCharacter(character)
    local player = Players:GetPlayerFromCharacter(character)
    local effect = player and active[player]
    return effect ~= nil and effect.kind == "Protection"
        and effect.character == character and effect.expiresAt > now()
end

function Service.Apply(player, kind)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not Config.Types[kind] or not humanoid or humanoid.Health <= 0 then return false end
    Service.Clear(player)
    local effect = {kind = kind, character = character, expiresAt = now() + Config.Duration}
    active[player] = effect
    -- A new effect always has a new deadline; old expiry tasks cannot cancel it.
    player:SetAttribute("ActiveOrbType", kind)
    player:SetAttribute("ActiveOrbExpiresAt", effect.expiresAt)
    if kind == "Protection" then
        local field = Instance.new("ForceField")
        field.Name = "OrbProtectionForceField"
        field.Visible = false
        field.Parent = character
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            local bubble = Instance.new("Part")
            bubble.Name = "OrbProtectionBubble"
            bubble.Shape = Enum.PartType.Ball
            bubble.Size = Vector3.new(7, 7, 7)
            bubble.Material = Enum.Material.ForceField
            bubble.Color = Config.Types.Protection.Color
            bubble.Transparency = 0.5
            bubble.Massless = true
            bubble.CanCollide = false
            bubble.CanTouch = false
            bubble.CanQuery = false
            bubble.CastShadow = false
            bubble.CFrame = root.CFrame
            bubble.Parent = character
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = root
            weld.Part1 = bubble
            weld.Parent = bubble
        end
        local highlight = Instance.new("Highlight")
        highlight.Name = "OrbProtectionHighlight"
        highlight.FillTransparency = 1
        highlight.OutlineColor = Config.Types.Protection.Color
        highlight.OutlineTransparency = 0.2
        highlight.DepthMode = Enum.HighlightDepthMode.Occluded
        highlight.Parent = character
    else
        player:SetAttribute("OrbSpeedMultiplier", Config.Types.Speed.Multiplier)
    end
    task.delay(Config.Duration, function()
        if active[player] == effect then Service.Clear(player) end
    end)
    return true
end

function Service.ConnectPlayer(player)
    player.CharacterRemoving:Connect(function(character)
        removeVisual(character)
        Service.Clear(player)
    end)
    player.CharacterAdded:Connect(function(character)
        Service.Clear(player)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then humanoid.Died:Connect(function() Service.Clear(player) end) end
    end)
    Service.Clear(player)
end

return Service
