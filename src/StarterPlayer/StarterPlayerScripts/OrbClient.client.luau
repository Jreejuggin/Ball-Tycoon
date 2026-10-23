-- Responsive effect timer and server-confirmed procedural eating on all viewing clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("OrbConfig"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("OrbStatusGui")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "OrbStatusGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end
local function label(parent, name, size, pos, textSize)
    local value = Instance.new("TextLabel")
    value.Name = name
    value.Size = size
    value.Position = pos
    value.BackgroundTransparency = 1
    value.TextColor3 = Color3.fromRGB(250, 250, 255)
    value.Font = Enum.Font.GothamBold
    value.TextSize = textSize
    value.Parent = parent
    return value
end
local card = Instance.new("Frame")
card.Name = "EffectCard"
card.AnchorPoint = Vector2.new(0.5, 1)
card.Position = UDim2.new(0.5, 0, 1, -106)
card.Size = UDim2.fromOffset(350, 76)
card.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
card.BackgroundTransparency = 0.08
card.Visible = false
card.Parent = gui
corner(card, 15)
local outline = Instance.new("UIStroke")
outline.Thickness = 2
outline.Parent = card
local scale = Instance.new("UIScale")
scale.Parent = card
local symbol = label(card, "OrbSymbol", UDim2.fromOffset(44, 44), UDim2.fromOffset(12, 12), 24)
symbol.BackgroundTransparency = 0.1
symbol.Text = "P"
corner(symbol, 22)
local title = label(card, "Title", UDim2.new(1, -138, 0, 25), UDim2.fromOffset(67, 10), 17)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MinTextSize = 12
textConstraint.MaxTextSize = 17
textConstraint.Parent = title
local subtitle = label(card, "Subtitle", UDim2.new(1, -85, 0, 21), UDim2.fromOffset(67, 34), 12)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Color3.fromRGB(205, 215, 236)
subtitle.Font = Enum.Font.GothamMedium
local time = label(card, "TimeRemaining", UDim2.fromOffset(65, 32), UDim2.new(1, -77, 0, 9), 23)
local bar = Instance.new("Frame")
bar.Name = "ProgressTrack"
bar.Size = UDim2.new(1, -24, 0, 5)
bar.Position = UDim2.new(0, 12, 1, -12)
bar.BackgroundColor3 = Color3.fromRGB(48, 60, 79)
bar.BorderSizePixel = 0
bar.Parent = card
corner(bar, 3)
local fill = Instance.new("Frame")
fill.Name = "Progress"
fill.Size = UDim2.fromScale(1, 1)
fill.BorderSizePixel = 0
fill.Parent = bar
corner(fill, 3)
local toast = label(gui, "PurchaseToast", UDim2.fromOffset(350, 40), UDim2.new(0.5, 0, 1, -192), 14)
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
toast.BackgroundTransparency = 0.12
toast.Visible = false
corner(toast, 12)
local toastVersion = 0
ReplicatedStorage:WaitForChild("OrbRemotes").Feedback.OnClientEvent:Connect(function(event, kind)
    if event ~= "Purchased" or not Config.Types[kind] then return end
    toastVersion += 1
    local version = toastVersion
    toast.Text = Config.Types[kind].ToolName .. " added to your inventory!"
    toast.TextColor3 = Config.Types[kind].Color
    toast.Visible = true
    task.delay(2.5, function() if version == toastVersion then toast.Visible = false end end)
end)

local displaySignature = ""
local frameTime = 0
RunService.Heartbeat:Connect(function(dt)
    frameTime += dt
    if frameTime < 0.05 then return end
    frameTime = 0
    local now = workspace:GetServerTimeNow()
    local character = player.Character
    local eatingKind = character and character:GetAttribute("OrbEatingType")
    local eatingEnd = character and character:GetAttribute("OrbEatingEndsAt") or 0
    local isEating = Config.Types[eatingKind] ~= nil and eatingEnd > now
    local kind = isEating and eatingKind or player:GetAttribute("ActiveOrbType")
    local expires = isEating and eatingEnd or (player:GetAttribute("ActiveOrbExpiresAt") or 0)
    local remaining = math.max(0, expires - now)
    local data = Config.Types[kind]
    local signature = data and remaining > 0 and (kind .. ":" .. tostring(expires) .. ":" .. tostring(isEating)) or ""
    card.Visible = signature ~= ""
    if signature ~= "" then
        title.Text = data.ToolName
        subtitle.Text = isEating and "Eating..." or (kind == "Protection" and "Melee & throwable protection" or "+20% movement speed")
        time.Text = isEating and "..." or (tostring(math.ceil(remaining)) .. "s")
        symbol.Text = kind == "Protection" and "P" or "S"
        symbol.BackgroundColor3 = data.Color
        symbol.TextColor3 = Color3.fromRGB(15, 24, 40)
        outline.Color = data.Color
        fill.BackgroundColor3 = data.Color
        fill.Size = UDim2.fromScale(isEating and (1 - remaining / Config.EatDuration) or remaining / Config.Duration, 1)
        if signature ~= displaySignature then
            scale.Scale = 0.82
            TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end
    end
    displaySignature = signature
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
    card.Size = UDim2.fromOffset(math.min(350, viewport.X - 28), 76)
    card.Position = UDim2.new(0.5, 0, 1, viewport.Y < 500 and -92 or -106)
    toast.Size = UDim2.fromOffset(math.min(350, viewport.X - 28), 40)
end)

-- Animate from replicated eating timestamps. No uploaded animation asset is required.
-- Remove our previous offset before the Animator evaluates; layer after it in PreSimulation.
local rigs = {}
local function stripOffsets(rig)
    for _, entry in ipairs(rig.joints) do
        if entry.joint.Parent then
            entry.joint.Transform = entry.offset:Inverse() * entry.joint.Transform
        end
        entry.offset = CFrame.identity
    end
end
local function removeRig(character)
    local rig = rigs[character]
    if not rig then return end
    stripOffsets(rig)
    if rig.grip and rig.grip.Parent then rig.grip.C0 = rig.baseGrip end
    rigs[character] = nil
end
local function findRig(character)
    local rig = {joints = {}}
    local tool
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") and child:GetAttribute("OrbType") then tool = child break end
    end
    if not tool then return nil end
    rig.tool = tool
    rig.handle = tool:FindFirstChild("Handle")
    for _, joint in ipairs(character:GetDescendants()) do
        if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
            local name = joint.Name
            local role = (name == "RightShoulder" or name == "Right Shoulder") and "shoulder"
                or name == "RightElbow" and "elbow" or name == "Neck" and "neck"
            if role then table.insert(rig.joints, {joint = joint, role = role, offset = CFrame.identity}) end
        end
        if joint:IsA("JointInstance") and joint.Name == "RightGrip" and joint.Part1 == rig.handle then
            rig.grip = joint
            rig.baseGrip = joint.C0
        end
    end
    return rig
end
RunService.PreAnimation:Connect(function()
    for _, rig in pairs(rigs) do stripOffsets(rig) end
end)
RunService.PreSimulation:Connect(function()
    local now = workspace:GetServerTimeNow()
    local seen = {}
    for _, other in ipairs(Players:GetPlayers()) do
        local character = other.Character
        local started = character and character:GetAttribute("OrbEatingStartedAt") or 0
        local ends = character and character:GetAttribute("OrbEatingEndsAt") or 0
        if character and ends > now and started > 0 then
            seen[character] = true
            local rig = rigs[character]
            if not rig then rig = findRig(character) rigs[character] = rig end
            if rig then
                if not rig.grip then
                    removeRig(character)
                else
                    local elapsed = now - started
                    local rise = math.clamp(elapsed / 0.35, 0, 1)
                    local fall = math.clamp((ends - now) / 0.2, 0, 1)
                    local blend = math.sin(math.min(rise, fall) * math.pi / 2)
                    for _, entry in ipairs(rig.joints) do
                        local pose
                        if entry.role == "shoulder" then
                            pose = CFrame.Angles(math.rad(100 * blend), 0, math.rad(-20 * blend))
                        elseif entry.role == "elbow" then
                            pose = CFrame.Angles(math.rad(-70 * blend), 0, 0)
                        else
                            pose = CFrame.Angles(math.rad(math.sin(elapsed * 14) * 4 * blend), 0, 0)
                        end
                        entry.offset = pose
                        entry.joint.Transform = pose * entry.joint.Transform
                    end
                    local head = character:FindFirstChild("Head")
                    local hand = rig.grip.Part0
                    if head and hand then
                        local mouth = head.CFrame * CFrame.new(0.15, -0.25, -head.Size.Z / 2 - 0.4)
                        local mouthGrip = hand.CFrame:ToObjectSpace(mouth) * rig.grip.C1
                        rig.grip.C0 = rig.baseGrip:Lerp(mouthGrip, blend)
                    end
                end
            end
        end
    end
    for character in pairs(rigs) do
        if not seen[character] then removeRig(character) end
    end
end)
