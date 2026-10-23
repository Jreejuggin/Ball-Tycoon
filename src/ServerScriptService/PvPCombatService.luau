-- Server combat state. Clients send input intent, never hits or timing results.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("PvPConfig"))
local Remotes = RS:WaitForChild("PvPRemotes")
local Service = {}
local states = {}
local function now() return workspace:GetServerTimeNow() end
local function state(player)
    local value = states[player]
    if not value then
        value = {combo = 0, guardAt = -math.huge, nextGuard = 0, nextDodge = 0,
            evadingUntil = 0, stunnedUntil = 0, hitGraceUntil = 0}
        states[player] = value
    end
    return value
end
local function emit(player, kind, data)
    if typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players then
        Remotes.Feedback:FireClient(player, kind, data or {})
    end
end
local function impact(position, kind)
    Remotes.Impact:FireAllClients(position, kind)
end
local function equippedWeapon(player)
    local character = player.Character
    if not character then return nil end
    for _, tool in character:GetChildren() do
        if tool:IsA("Tool") and
            ((tool.Name == "KnockbackPlank" and tool:GetAttribute("GrantedByKnockbackPlankStation") == true)
            or (tool.Name == "ThrowableBall" and tool:GetAttribute("GrantedByThrowableBallStation") == true)) then
            return tool
        end
    end
    return nil
end
local function live(player)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
    return char, hum, root
end
local function publishCombo(player, value)
    player:SetAttribute("PvPCombo", value.combo)
    player:SetAttribute("PvPComboExpiresAt", value.combo > 0 and value.lastHit + Config.ComboWindow or 0)
end

function Service.CanAttack(player)
    if not Config.Enabled then return true end
    local char, hum = live(player)
    if not char or hum.PlatformStand then return false end
    local s = state(player)
    return now() >= s.stunnedUntil and now() >= s.evadingUntil
        and now() >= s.guardAt + Config.GuardDuration
end

function Service.IsEvading(character)
    if not Config.Enabled then return false end
    local player = Players:GetPlayerFromCharacter(character)
    return player ~= nil and now() < state(player).evadingUntil
end

-- Pure rule helper, also used in regression checks.
function Service.NextCombo(count, lastHit, sameTarget, time)
    if not sameTarget or time - (lastHit or -math.huge) > Config.ComboWindow then count = 0 end
    return count + 1 >= Config.ComboHits and Config.ComboHits or count + 1
end

function Service.BeforeHit(attacker, character, tool, origin)
    if not Config.Enabled then
        return {damage = 1, knockback = tonumber(tool:GetAttribute("HorizontalKnockback")) or 184,
            vertical = tonumber(tool:GetAttribute("VerticalKnockback")) or 52,
            ragdoll = tonumber(tool:GetAttribute("RagdollSeconds")) or 1.25}
    end
    local defender = Players:GetPlayerFromCharacter(character)
    if not defender then return nil end
    local s = state(defender)
    local t = now()
    if t < s.evadingUntil or t < s.hitGraceUntil then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    local offset = origin - root.Position
    local facing = offset.Magnitude < 0.1 or root.CFrame.LookVector:Dot(offset.Unit) > 0.1
    if facing and t < s.guardAt + Config.GuardDuration then
        local perfect = t <= s.guardAt + Config.PerfectGuardDuration
        if perfect then
            local a = state(attacker)
            a.stunnedUntil = t + Config.ParryStun
            attacker:SetAttribute("PvPStunnedUntil", a.stunnedUntil)
            emit(attacker, "Parried", {duration = Config.ParryStun})
            emit(defender, "PerfectGuard", {})
            impact(root.Position, "Parry")
            return nil
        end
        s.lastAttacker, s.lastDamageAt = attacker, t
        emit(defender, "Guarded", {})
        emit(attacker, "Blocked", {})
        impact(root.Position, "Guard")
        return {damage = Config.GuardDamageMultiplier, knockback = 0, vertical = 0, ragdoll = 0, guarded = true}
    end
    local a = state(attacker)
    local step = Service.NextCombo(a.combo, a.lastHit, a.target == defender, t)
    local mixed = a.target == defender and a.weapon ~= nil and a.weapon ~= tool.Name
        and t - (a.lastHit or -math.huge) <= Config.ComboWindow
    local finisher = step == Config.ComboHits
    a.combo = finisher and 0 or step
    a.lastHit, a.target, a.weapon = t, defender, tool.Name
    publishCombo(attacker, a)
    s.hitGraceUntil = t + Config.HitGrace
    s.lastAttacker, s.lastDamageAt = attacker, t
    local bonus = (finisher and Config.FinisherDamageBonus or 1) * (mixed and Config.MixedWeaponBonus or 1)
    return {damage = bonus, knockback = finisher and Config.FinisherKnockback or Config.LightKnockback,
        vertical = finisher and Config.FinisherVertical or Config.LightVertical,
        ragdoll = finisher and Config.FinisherRagdoll or Config.LightRagdoll,
        finisher = finisher, mixed = mixed, combo = step}
end

function Service.AfterHit(attacker, character, result, damage)
    if not Config.Enabled then return end
    local defender = Players:GetPlayerFromCharacter(character)
    if not defender then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    emit(attacker, "Hit", {combo = result.combo or 0, damage = damage,
        finisher = result.finisher, mixed = result.mixed, position = root.Position})
    emit(defender, "Hurt", {damage = damage, finisher = result.finisher})
    impact(root.Position, result.finisher and "Finisher" or result.guarded and "Guard" or "Hit")
    if result.finisher and character:FindFirstChildOfClass("Humanoid").Health > 0 then
        local s = state(defender)
        local t = now()
        -- One server-owned input opportunity. Spamming cannot extend the window.
        s.recovery = {character = character, startAt = t + Config.RecoveryStart,
            endAt = t + Config.RecoveryEnd, perfectStart = t + Config.RecoveryPerfectStart,
            perfectEnd = t + Config.RecoveryPerfectEnd, used = false}
        character:SetAttribute("PvPRecoveryStart", s.recovery.startAt)
        character:SetAttribute("PvPRecoveryEnd", s.recovery.endAt)
        character:SetAttribute("PvPRecoveryPerfectStart", s.recovery.perfectStart)
        character:SetAttribute("PvPRecoveryPerfectEnd", s.recovery.perfectEnd)
        emit(defender, "Recovery", s.recovery)
    end
end

function Service.Guard(player)
    if not Config.Enabled or not equippedWeapon(player) or not Service.CanAttack(player) then return false end
    local s = state(player) local t = now()
    if t < s.nextGuard then return false end
    s.guardAt, s.nextGuard = t, t + Config.GuardCooldown
    player:SetAttribute("PvPGuardUntil", t + Config.GuardDuration)
    player:SetAttribute("PvPGuardReadyAt", s.nextGuard)
    emit(player, "Guard", {})
    local _, _, root = live(player)
    if root then impact(root.Position, "Guard") end
    return true
end

function Service.Dodge(player, direction)
    if not Config.Enabled or not equippedWeapon(player) or not Service.CanAttack(player) then return false end
    local char, hum, root = live(player)
    local s = state(player) local t = now()
    if not char or t < s.nextDodge or root.Anchored then return false end
    if typeof(direction) ~= "Vector3" or direction.X ~= direction.X or direction.Z ~= direction.Z
        or math.abs(direction.X) > 1.5 or math.abs(direction.Z) > 1.5 then
        direction = root.CFrame.LookVector
    end
    direction = Vector3.new(direction.X, 0, direction.Z)
    if direction.Magnitude < 0.05 then direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) end
    if direction.Magnitude < 0.05 then return false end
    direction = direction.Unit
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    params.RespectCanCollide = true
    local distance = Config.DodgeSpeed * Config.DodgeDuration
    local obstacle = workspace:Blockcast(root.CFrame, Vector3.new(2, 3, 2), direction * distance, params)
    local speed = obstacle and math.max(0, obstacle.Distance - 1) / Config.DodgeDuration or Config.DodgeSpeed
    if speed < 5 then return false end
    s.nextDodge, s.evadingUntil = t + Config.DodgeCooldown, t + Config.DodgeDuration
    player:SetAttribute("PvPDodgeReadyAt", s.nextDodge)
    player:SetAttribute("PvPEvadingUntil", s.evadingUntil)
    local serverOwned = pcall(function() root:SetNetworkOwner(nil) end)
    root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, root.AssemblyLinearVelocity.Y, direction.Z * speed)
    emit(player, "Dodge", {})
    impact(root.Position, "Dodge")
    task.delay(Config.DodgeDuration, function()
        if serverOwned and root.Parent and player.Character == char and not hum.PlatformStand then
            pcall(function() root:SetNetworkOwnershipAuto() end)
        end
    end)
    return true
end

function Service.TryRecover(player)
    local s = state(player)
    local r = s.recovery
    local char, hum = live(player)
    local t = now()
    if not Config.Enabled or not r or r.used or not char or r.character ~= char
        or not hum.PlatformStand or t > r.endAt then return nil end
    -- Consume the attempt even when early: timing matters.
    r.used = true
    char:SetAttribute("PvPRecoveryEnd", 0)
    if t < r.startAt then emit(player, "RecoveryMiss", {}) return nil end
    local perfect = t >= r.perfectStart and t <= r.perfectEnd
    s.evadingUntil = t + (perfect and Config.RecoveryGrace or Config.RecoveryGrace * 0.5)
    player:SetAttribute("PvPEvadingUntil", s.evadingUntil)
    emit(player, "Recovered", {perfect = perfect})
    impact(char.HumanoidRootPart.Position, "Recover")
    return char
end

function Service.ResetCharacter(player)
    states[player] = nil
    state(player)
    if player.Character then player.Character:SetAttribute("PvPRecoveryEnd", 0) end
    for _, attr in {"PvPCombo", "PvPComboExpiresAt", "PvPGuardUntil", "PvPGuardReadyAt",
        "PvPDodgeReadyAt", "PvPEvadingUntil", "PvPStunnedUntil"} do player:SetAttribute(attr, 0) end
    -- Match statistics are separate from permanent tycoon progress.
    player:SetAttribute("PvPKnockouts", player:GetAttribute("PvPKnockouts") or 0)
    player:SetAttribute("PvPStreak", player:GetAttribute("PvPStreak") or 0)
end

function Service.OnDeath(player)
    local s = state(player)
    local attacker = s.lastAttacker
    if attacker and attacker ~= player and attacker.Parent == Players
        and now() - (s.lastDamageAt or -math.huge) <= Config.KOAttributionWindow then
        attacker:SetAttribute("PvPKnockouts", (attacker:GetAttribute("PvPKnockouts") or 0) + 1)
        local streak = (attacker:GetAttribute("PvPStreak") or 0) + 1
        attacker:SetAttribute("PvPStreak", streak)
        emit(attacker, "Knockout", {name = player.DisplayName, streak = streak})
    end
    player:SetAttribute("PvPStreak", 0)
    Service.ResetCharacter(player)
end

function Service.RemovePlayer(player)
    states[player] = nil
    for _, s in pairs(states) do
        if s.target == player then s.combo, s.target = 0, nil end
        if s.lastAttacker == player then s.lastAttacker = nil end
    end
end

return Service