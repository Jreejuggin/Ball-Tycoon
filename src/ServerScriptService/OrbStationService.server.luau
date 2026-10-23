-- Owner-only Orb Centre shops, repeatable stacks, and separate five-minute cooldowns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("OrbConfig"))
local Inventory = require(script.Parent:WaitForChild("OrbInventoryService"))
local PurchaseEffect = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSound = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))
local remotes = ReplicatedStorage:WaitForChild("OrbRemotes")
local refreshers = {}
local GREEN = Color3.fromRGB(30, 255, 75)
local RED = Color3.fromRGB(215, 28, 38)
local COOLDOWN_COLOR = Color3.fromRGB(150, 170, 215)
local lastConsumeRequest = {}

remotes.Consume.OnServerEvent:Connect(function(player, kind)
    if type(kind) ~= "string" or not Config.Types[kind] then return end
    local now = os.clock()
    if now - (lastConsumeRequest[player] or -math.huge) < 0.2 then return end
    lastConsumeRequest[player] = now
    Inventory.Consume(player, kind)
end)

Players.PlayerAdded:Connect(Inventory.ConnectPlayer)
for _, player in ipairs(Players:GetPlayers()) do Inventory.ConnectPlayer(player) end
Players.PlayerRemoving:Connect(function(player)
    Inventory.RemovePlayer(player)
    lastConsumeRequest[player] = nil
end)

local function wireStation(plot, centre, kind)
    local data = Config.Types[kind]
    local station = centre.Upgrades:WaitForChild(data.StationName)
    local pad = station.BuyPad
    local activated = centre.Activated
    local function getOwner()
        local id = tonumber(plot:GetAttribute("Owner"))
        return id and Players:GetPlayerByUserId(id) or nil
    end
    local function refresh()
        local owner = getOwner()
        local visible = owner ~= nil and activated.Value and not plot:GetAttribute("RestoringProgress")
        local remaining = owner and Inventory.GetCooldownRemaining(owner, kind) or 0
        local stats = owner and owner:FindFirstChild("leaderstats")
        local cash = stats and stats:FindFirstChild("Cash")
        local canBuy = visible and remaining == 0 and owner:GetAttribute("DataLoaded")
            and not owner:GetAttribute("DataLoadFailed") and Inventory.GetCount(owner, kind) < Config.MaxStack
        local color = remaining > 0 and COOLDOWN_COLOR or (cash and cash.Value >= data.Price and GREEN or RED)
        pad.Material = Enum.Material.Neon
        pad.Color = color
        pad.Transparency = visible and 0.45 or 1
        pad.CanCollide = false
        pad.CanTouch = canBuy == true
        pad.CanQuery = visible
        pad.PriceLabel.Enabled = visible
        pad.UpgradeLabel.Enabled = visible
        local text = "$" .. data.Price
        if remaining > 0 then
            text = string.format("READY IN %d:%02d", math.floor(remaining / 60), remaining % 60)
        elseif owner and owner:GetAttribute("DataLoadFailed") then
            text = "DATA UNAVAILABLE"
        elseif owner and Inventory.GetCount(owner, kind) >= Config.MaxStack then
            text = "STACK FULL"
        end
        pad.PriceLabel.PriceText.Text = text
        pad.PriceLabel.PriceText.TextColor3 = color
        pad.UpgradeLabel.WorkerText.Text = data.ToolName
        pad.UpgradeLabel.SpeedText.Text = data.Description
        for _, part in ipairs(station.Display:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = visible and (part:GetAttribute("DisplayTransparency") or 0) or 1
                part.CanCollide = visible and part.Name == "Pedestal"
                part.CanTouch = false
                part.CanQuery = visible and part.Name == "Pedestal"
                part.CastShadow = visible
            elseif part:IsA("PointLight") then
                part.Enabled = visible
            end
        end
    end
    pad.Touched:Connect(function(hit)
        if not activated.Value or plot:GetAttribute("RestoringProgress") then return end
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not player or player ~= getOwner() or not humanoid or humanoid.Health <= 0 or not root then return end
        local localPosition = pad.CFrame:PointToObjectSpace(root.Position)
        if math.abs(localPosition.X) > pad.Size.X / 2 + 2.5
            or math.abs(localPosition.Z) > pad.Size.Z / 2 + 2.5
            or localPosition.Y < -2 or localPosition.Y > 7 then return end
        local bought = Inventory.TryPurchase(player, kind)
        if bought then
            remotes.Feedback:FireClient(player, "Purchased", kind)
            PurchaseSound.PlayPurchaseForTarget(player, pad)
            PurchaseEffect.PlayAcrossParts({station.Display.Orb}, {color = data.Color}, {pointCount = 8, totalParticleBudget = 40})
        end
        refresh()
    end)
    activated.Changed:Connect(refresh)
    plot:GetAttributeChangedSignal("Owner"):Connect(refresh)
    plot:GetAttributeChangedSignal("RestoringProgress"):Connect(refresh)
    table.insert(refreshers, refresh)
    refresh()
end

for index = 1, 10 do
    local plot = workspace:WaitForChild("P" .. index)
    local centre = plot.CentreSlots.Centre04_Orb
    for _, kind in ipairs(Config.Order) do wireStation(plot, centre, kind) end
end
-- One shared one-second updater supports pad affordability and cooldown countdowns.
task.spawn(function()
    while true do
        task.wait(1)
        for _, refresh in ipairs(refreshers) do refresh() end
    end
end)
print("[OrbStationService] Wired 20 consumable stations across P1-P10.")
