-- Cross-platform input and presentation. This script never awards hits or bonuses.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local Config = require(RS:WaitForChild("PvPConfig"))
local remotes = RS:WaitForChild("PvPRemotes")
local gui = Instance.new("ScreenGui")
gui.Name = "PvPCombatGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 24
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local blue = Color3.fromRGB(82, 207, 255)
local gold = Color3.fromRGB(255, 204, 73)
local green = Color3.fromRGB(92, 245, 155)
local function label(parent, name, text, size, position, color)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Size, l.Position = size, position
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Color3.new(1,1,1)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 16
    l.TextWrapped = true
    l.Parent = parent
    return l
end
local card = Instance.new("Frame")
card.Name = "CombatCard"
card.AnchorPoint = Vector2.new(.5,0)
card.Position = UDim2.new(.5,0,0,112)
card.Size = UDim2.fromOffset(320,106)
card.BackgroundColor3 = Color3.fromRGB(19,25,40)
card.BackgroundTransparency = .12
card.Visible = false
card.Parent = gui
local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,16) corner.Parent = card
local stroke = Instance.new("UIStroke") stroke.Thickness = 2 stroke.Color = blue stroke.Parent = card
local scale = Instance.new("UIScale") scale.Parent = card
local title = label(card,"Title","PVP • READY",UDim2.new(1,-20,0,24),UDim2.fromOffset(10,8),blue)
local detail = label(card,"Detail","",UDim2.new(1,-20,0,20),UDim2.fromOffset(10,34))
detail.TextSize = 13
local status = label(card,"Cooldowns","",UDim2.new(1,-20,0,18),UDim2.fromOffset(10,80))
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(191,207,229)
local pips = {}
for i=1,3 do
    local p = Instance.new("Frame") p.Name = "ComboPip"..i
    p.Position = UDim2.new((i-1)/3,10,0,60)
    p.Size = UDim2.new(1/3,-16,0,9)
    p.BackgroundColor3 = Color3.fromRGB(51,63,81)
    p.BorderSizePixel = 0 p.Parent = card
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1,0) c.Parent = p
    pips[i] = p
end
local track = Instance.new("Frame") track.Name="RecoveryTrack"
track.Position = UDim2.new(0,14,0,60) track.Size=UDim2.new(1,-28,0,14)
track.BackgroundColor3=Color3.fromRGB(58,66,84) track.BorderSizePixel=0 track.Visible=false track.Parent=card
local zone=Instance.new("Frame") zone.Name="SuccessWindow" zone.BorderSizePixel=0 zone.BackgroundColor3=green zone.Parent=track
local perfect=Instance.new("Frame") perfect.Name="PerfectWindow" perfect.BorderSizePixel=0 perfect.BackgroundColor3=gold perfect.Parent=track
local marker=Instance.new("Frame") marker.Name="TimingMarker" marker.AnchorPoint=Vector2.new(.5,.5)
marker.Size=UDim2.new(0,4,1,10) marker.BackgroundColor3=Color3.new(1,1,1) marker.BorderSizePixel=0 marker.Parent=track
local hitMarker=label(gui,"HitMarker","✦",UDim2.fromOffset(60,60),UDim2.new(.5,-30,.5,-30),gold)
hitMarker.TextSize=42 hitMarker.Visible=false
local toast=label(gui,"CombatToast","",UDim2.new(1,-40,0,42),UDim2.new(0,20,0,224),gold)
toast.Visible=false toast.TextSize=19

local equipped
local bound = {}
local untilMessage = 0
local message, messageColor = "", blue
local toastToken, markerToken = 0, 0
local characterConnections = {}
local lastRequest = {}
local function time() return workspace:GetServerTimeNow() end
local function request(kind)
    local t=os.clock()
    if t-(lastRequest[kind] or -math.huge)<.12 then return end
    lastRequest[kind]=t
    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    remotes.Action:FireServer(kind,kind=="Dodge" and hum and hum.MoveDirection or nil)
end
local function bind(name,titleText,key,button,position,callback)
    if bound[name] then return end
    bound[name]=true
    CAS:BindAction(name,function(_,state)
        if state==Enum.UserInputState.Begin then callback() end
        return Enum.ContextActionResult.Sink
    end,true,key,button)
    CAS:SetTitle(name,titleText) CAS:SetPosition(name,position)
end
local function unbind(name)
    if bound[name] then CAS:UnbindAction(name) bound[name]=nil end
end
local function weapon(tool)
    return tool and tool:IsA("Tool") and (tool.Name=="KnockbackPlank" or tool.Name=="ThrowableBall")
end
local function findWeapon()
    equipped=nil
    if player.Character then
        for _,child in player.Character:GetChildren() do if weapon(child) then equipped=child break end end
    end
end
local function inputLabel(key,button)
    local input=UIS:GetLastInputType()
    if UIS.TouchEnabled and input==Enum.UserInputType.Touch then return "TAP" end
    if tostring(input):find("Gamepad") then return button end
    return key
end
local function updateBindings(recovering)
    if equipped and Config.Enabled then
        bind("PvPGuard","Guard",Enum.KeyCode.F,Enum.KeyCode.ButtonL2,UDim2.new(1,-145,1,-325),function() request("Guard") end)
        bind("PvPDodge","Dodge",Enum.KeyCode.E,Enum.KeyCode.ButtonB,UDim2.new(1,-215,1,-265),function() request("Dodge") end)
        bind("PvPAttack","Attack",Enum.KeyCode.R,Enum.KeyCode.ButtonR2,UDim2.new(1,-82,1,-265),function()
            if equipped and equipped.Enabled then equipped:Activate() end
        end)
    else
        unbind("PvPGuard") unbind("PvPDodge") unbind("PvPAttack")
    end
    if recovering and Config.Enabled then
        bind("PvPRecover","Rise",Enum.KeyCode.Q,Enum.KeyCode.ButtonX,UDim2.new(1,-82,1,-325),function() request("Recover") end)
    else unbind("PvPRecover") end
end
local function attach(character)
    for _,c in characterConnections do c:Disconnect() end table.clear(characterConnections)
    table.insert(characterConnections,character.ChildAdded:Connect(findWeapon))
    table.insert(characterConnections,character.ChildRemoved:Connect(findWeapon))
    findWeapon()
end
player.CharacterAdded:Connect(attach)
if player.Character then attach(player.Character) end

local function pop(text,color,duration)
    message,messageColor,untilMessage=text,color,time()+(duration or .85)
    scale.Scale=.90
    TweenService:Create(scale,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
end
local function notify(text,color)
    toastToken+=1 local token=toastToken
    toast.Text,toast.TextColor3,toast.Visible=text,color,true
    task.delay(2,function() if token==toastToken then toast.Visible=false end end)
end
local function damageNumber(position,amount,color)
    if typeof(position)~="Vector3" then return end
    local anchor=Instance.new("Part") anchor.Name="PvPDamageNumber"
    anchor.Size=Vector3.one*.1 anchor.Anchored=true anchor.CanCollide=false anchor.CanTouch=false anchor.CanQuery=false
    anchor.Transparency=1 anchor.CFrame=CFrame.new(position+Vector3.new(0,3,0)) anchor.Parent=workspace
    local billboard=Instance.new("BillboardGui") billboard.Size=UDim2.fromOffset(110,45)
    billboard.AlwaysOnTop=true billboard.Parent=anchor
    local text=label(billboard,"Damage","-"..math.floor(amount+.5),UDim2.fromScale(1,1),UDim2.fromScale(0,0),color)
    text.TextSize=28 text.TextStrokeTransparency=.2
    TweenService:Create(anchor,TweenInfo.new(.65),{Position=anchor.Position+Vector3.new(0,2.5,0)}):Play()
    TweenService:Create(text,TweenInfo.new(.65),{TextTransparency=1,TextStrokeTransparency=1}):Play()
    Debris:AddItem(anchor,.7)
end

remotes.Feedback.OnClientEvent:Connect(function(kind,data)
    if kind=="Hit" then
        local color=data.finisher and gold or blue
        pop(data.finisher and "FINISHER!" or data.mixed and "MIX-UP • "..data.combo.."/3" or "COMBO • "..data.combo.."/3",color)
        hitMarker.Visible=true hitMarker.TextColor3=color
        markerToken+=1 local token=markerToken
        task.delay(.14,function() if token==markerToken then hitMarker.Visible=false end end)
        damageNumber(data.position,data.damage,color)
    elseif kind=="PerfectGuard" then pop("PERFECT PARRY!",gold,1.2)
    elseif kind=="Parried" then pop("PARRIED • BRIEFLY STUNNED",Color3.fromRGB(255,110,110),.9)
    elseif kind=="Guarded" then pop("GUARDED • DAMAGE REDUCED",blue)
    elseif kind=="Blocked" then pop("GUARDED",blue)
    elseif kind=="Guard" then pop("GUARD UP",blue,.55)
    elseif kind=="Dodge" then pop("DODGE!",blue,.4)
    elseif kind=="Recovered" then pop(data.perfect and "PERFECT RECOVERY!" or "RECOVERED!",green,1.2)
    elseif kind=="RecoveryMiss" then pop("TOO EARLY • TRY NEXT KNOCKDOWN",Color3.fromRGB(255,110,110),1.2)
    elseif kind=="Knockout" then
        notify("KO • "..data.name..(data.streak>1 and "  |  "..data.streak.." STREAK" or ""),gold)
        pop("KNOCKOUT!",gold,1.2)
    elseif kind=="Hurt" and not data.finisher then
        pop("HIT • "..math.floor(data.damage+.5).." DAMAGE",Color3.fromRGB(255,135,135),.5)
    end
end)

-- Cosmetic effects stay local and expire; no global per-frame projectile work.
remotes.Impact.OnClientEvent:Connect(function(position,kind)
    if typeof(position)~="Vector3" then return end
    local camera=workspace.CurrentCamera
    if camera and (camera.CFrame.Position-position).Magnitude>180 then return end
    local color=kind=="Finisher" and gold or kind=="Recover" and green or blue
    local orb=Instance.new("Part") orb.Name="PvPImpact"
    orb.Shape=Enum.PartType.Ball orb.Size=Vector3.one*(kind=="Finisher" and 2 or .5)
    orb.Material=Enum.Material.Neon orb.Color=color orb.Transparency=.35
    orb.Anchored=true orb.CanCollide=false orb.CanTouch=false orb.CanQuery=false
    orb.Position=position orb.Parent=workspace
    TweenService:Create(orb,TweenInfo.new(.3),{Size=Vector3.one*(kind=="Finisher" and 9 or 4),Transparency=1}):Play()
    Debris:AddItem(orb,.35)
end)

RunService.RenderStepped:Connect(function()
    local t=time() local char=player.Character
    local endAt=char and char:GetAttribute("PvPRecoveryEnd") or 0
    local startAt=char and char:GetAttribute("PvPRecoveryStart") or 0
    local recovering=endAt>t
    updateBindings(recovering)
    local combo=(player:GetAttribute("PvPComboExpiresAt") or 0)>t and (player:GetAttribute("PvPCombo") or 0) or 0
    card.Visible=Config.Enabled and (equipped~=nil or recovering or t<untilMessage)
    local camera=workspace.CurrentCamera
    local width=camera and camera.ViewportSize.X or 800
    local height=camera and camera.ViewportSize.Y or 600
    card.Size=UDim2.fromOffset(math.min(320,width-24),106)
    card.Position=UDim2.new(.5,0,0,height<500 and 88 or 112)
    toast.Position=UDim2.new(0,20,0,height<500 and 200 or 224)
    track.Visible=recovering
    for i,p in pips do p.Visible=not recovering p.BackgroundColor3=i<=combo and (combo==2 and gold or blue) or Color3.fromRGB(51,63,81) end
    local guard=math.max(0,(player:GetAttribute("PvPGuardReadyAt") or 0)-t)
    local dodge=math.max(0,(player:GetAttribute("PvPDodgeReadyAt") or 0)-t)
    status.Text=string.format("%s GUARD %s  •  %s DODGE %s  •  KO %d",
        inputLabel("F","L2"),guard>0 and string.format("%.1fs",guard) or "READY",
        inputLabel("E","B"),dodge>0 and string.format("%.1fs",dodge) or "READY",
        player:GetAttribute("PvPKnockouts") or 0)
    if recovering then
        title.Text,title.TextColor3="TIME YOUR RECOVERY",green
        local recoveryInput=inputLabel("Q","X")
        detail.Text=recoveryInput..(recoveryInput=="TAP" and " RISE" or "").." • PRESS IN GREEN, GOLD IS PERFECT"
        local beginning=startAt-Config.RecoveryStart local duration=endAt-beginning
        zone.Position=UDim2.fromScale((startAt-beginning)/duration,0)
        zone.Size=UDim2.fromScale((endAt-startAt)/duration,1)
        local ps=char:GetAttribute("PvPRecoveryPerfectStart") or startAt
        local pe=char:GetAttribute("PvPRecoveryPerfectEnd") or startAt
        perfect.Position=UDim2.fromScale((ps-beginning)/duration,0)
        perfect.Size=UDim2.fromScale((pe-ps)/duration,1)
        marker.Position=UDim2.fromScale(math.clamp((t-beginning)/duration,0,1),.5)
        stroke.Color=green
    else
        title.Text=t<untilMessage and message or combo==2 and "FINISHER READY" or combo>0 and "COMBO • "..combo.."/3" or "PVP • READY"
        title.TextColor3=t<untilMessage and messageColor or combo==2 and gold or blue
        stroke.Color=title.TextColor3
        detail.Text=combo==2 and "LAND ONE MORE HIT • MIX WEAPONS FOR A BONUS" or
            combo>0 and "KEEP HITTING THE SAME OPPONENT TO CHAIN" or "3 HITS → FINISHER  •  TIME YOUR GUARD"
    end
end)
script.Destroying:Connect(function()
    for name in pairs(bound) do CAS:UnbindAction(name) end
    for _,c in characterConnections do c:Disconnect() end
    gui:Destroy()
end)
