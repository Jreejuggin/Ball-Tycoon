--!strict
-- Server-authoritative Speed Upgrade Treadmill service for P1-P10.
-- Purchases persist through each plot-relative Activated BoolValue. The purchased
-- owner receives a server-owned 1.5x Shift sprint multiplier.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlotTheme = require(ReplicatedStorage:WaitForChild("PlotTheme"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))
local TreadmillTheme = require(ReplicatedStorage:WaitForChild("TreadmillTheme"))

local SLOT_NAME = "SpeedUpgradeTreadmill"
local WIRED_ATTRIBUTE = "SpeedUpgradeTreadmillServiceWired"
local SPRINT_MULTIPLIER_ATTRIBUTE = "SprintSpeedMultiplier"
local PAD_REFRESH_SECONDS = 0.5

local COLOR_GREEN = Color3.fromRGB(30, 255, 75)
local COLOR_RED = Color3.fromRGB(215, 28, 38)
local COLOR_LOCKED = Color3.fromRGB(105, 110, 120)

local machines = ServerStorage:WaitForChild("Machines")
local template = machines:WaitForChild("SpeedUpgrade_Treadmill")

local padRefreshers: { () -> () } = {}
local lastOwnerByPlot: { [Instance]: Player } = {}

local function formatCash(amount: number): string
	local text = tostring(math.max(0, math.floor(amount)))
	while true do
		local updated, replacements = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = updated
		if replacements == 0 then
			break
		end
	end
	return "$" .. text
end

local function getCash(player: Player?): ValueBase?
	local leaderstats = player and player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
		return cash
	end
	return nil
end

local function placeModel(model: Model, targetCFrame: CFrame, referencePart: BasePart)
	local origin = referencePart.CFrame
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CFrame = targetCFrame * origin:ToObjectSpace(descendant.CFrame)
		end
	end
end

local function initializePlayer(player: Player)
	if typeof(player:GetAttribute(SPRINT_MULTIPLIER_ATTRIBUTE)) ~= "number" then
		player:SetAttribute(SPRINT_MULTIPLIER_ATTRIBUTE, 1)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	initializePlayer(player)
end
Players.PlayerAdded:Connect(initializePlayer)

local function wirePlot(plot: Instance): boolean
	local centreSlots = plot:FindFirstChild("CentreSlots")
	local avatarCentre = centreSlots and centreSlots:FindFirstChild("Centre03_Avatar")
	local avatarActivated = avatarCentre and avatarCentre:FindFirstChild("Activated")
	local upgrades = avatarCentre and avatarCentre:FindFirstChild("Upgrades")
	local slot = upgrades and upgrades:FindFirstChild(SLOT_NAME)

	if not avatarCentre
		or not avatarActivated
		or not avatarActivated:IsA("BoolValue")
		or not slot
		or not slot:IsA("Model")
	then
		warn(("[SpeedUpgradeTreadmillService] Incomplete treadmill slot in %s."):format(plot:GetFullName()))
		return false
	end

	local anchor = slot:FindFirstChild("Anchor")
	local buyPad = slot:FindFirstChild("BuyPad")
	local config = slot:FindFirstChild("Config")
	local price = config and config:FindFirstChild("Price")
	local displayName = config and config:FindFirstChild("DisplayName")
	local requiresStructure = config and config:FindFirstChild("RequiresStructure")
	local machineId = config and config:FindFirstChild("MachineId")
	local sprintMultiplier = config and config:FindFirstChild("SprintMultiplier")
	local activated = slot:FindFirstChild("Activated")

	if not anchor
		or not anchor:IsA("BasePart")
		or not buyPad
		or not buyPad:IsA("BasePart")
		or not price
		or not price:IsA("IntValue")
		or not displayName
		or not displayName:IsA("StringValue")
		or not requiresStructure
		or not requiresStructure:IsA("StringValue")
		or not machineId
		or not machineId:IsA("StringValue")
		or not sprintMultiplier
		or not sprintMultiplier:IsA("NumberValue")
		or not activated
		or not activated:IsA("BoolValue")
	then
		warn(("[SpeedUpgradeTreadmillService] Incomplete treadmill configuration in %s."):format(plot:GetFullName()))
		return false
	end

	if slot:GetAttribute(WIRED_ATTRIBUTE) then
		return false
	end
	slot:SetAttribute(WIRED_ATTRIBUTE, true)

	-- EditPreview_MoveMe is deliberately visible in Studio so designers can
	-- position the full treadmill instead of guessing with an invisible anchor.
	-- It is removed before clients see the plot, while its Base_Main CFrame
	-- remains the authoritative runtime placement.
	local placementCFrame = anchor.CFrame
	local editPreview = slot:FindFirstChild("EditPreview_MoveMe")
	if editPreview and editPreview:IsA("Model") then
		local previewBase = editPreview:FindFirstChild("Base_Main")
		if previewBase and previewBase:IsA("BasePart") then
			placementCFrame = previewBase.CFrame
			anchor.CFrame = placementCFrame
		else
			warn(("[SpeedUpgradeTreadmillService] %s is missing Base_Main; using Anchor."):format(
				editPreview:GetFullName()
			))
		end
		editPreview:Destroy()
	elseif editPreview then
		editPreview:Destroy()
	end

	local priceLabel = buyPad:FindFirstChild("PriceLabel")
	local priceText = priceLabel and priceLabel:FindFirstChild("PriceText", true)
	local upgradeLabel = buyPad:FindFirstChild("UpgradeLabel")
	local upgradeText = upgradeLabel and upgradeLabel:FindFirstChildWhichIsA("TextLabel", true)
	local processing = false

	local function getOwner(): Player?
		local ownerId = tonumber(plot:GetAttribute("Owner"))
		return ownerId and Players:GetPlayerByUserId(ownerId) or nil
	end

	local function dependencyMet(): boolean
		return requiresStructure.Value == "Centre03_Avatar" and avatarActivated.Value
	end

	local function setGuiEnabled(gui: Instance?, enabled: boolean)
		if gui and (gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")) then
			gui.Enabled = enabled
		end
	end

	local function updateSprintReward()
		local owner = getOwner()
		local previousOwner = lastOwnerByPlot[plot]
		if previousOwner and previousOwner ~= owner and previousOwner.Parent then
			previousOwner:SetAttribute(SPRINT_MULTIPLIER_ATTRIBUTE, 1)
		end

		if owner then
			lastOwnerByPlot[plot] = owner
			owner:SetAttribute(
				SPRINT_MULTIPLIER_ATTRIBUTE,
				activated.Value and sprintMultiplier.Value or 1
			)
		else
			lastOwnerByPlot[plot] = nil
		end
	end

	local function clearTreadmill()
		local existing = slot:FindFirstChild("TreadmillModel")
		if existing then
			existing:Destroy()
		end
	end

	local function spawnTreadmill(): Model?
		clearTreadmill()

		local model = template:Clone()
		model.Name = "TreadmillModel"
		local base = model:FindFirstChild("Base_Main")
		if not base or not base:IsA("BasePart") then
			warn("[SpeedUpgradeTreadmillService] Template is missing Base_Main.")
			model:Destroy()
			return nil
		end

		TreadmillTheme.ApplyUnlocked(model, TreadmillTheme.GetPlotColor(plot))
		model.Parent = slot
		placeModel(model, placementCFrame, base)
		return model
	end

	local function ensureTreadmill(): Model?
		local existing = slot:FindFirstChild("TreadmillModel")
		if existing and existing:IsA("Model") then
			TreadmillTheme.ApplyUnlocked(existing, TreadmillTheme.GetPlotColor(plot))
			return existing
		end
		return spawnTreadmill()
	end

	local function updatePad()
		local owner = getOwner()
		local shouldShow = owner ~= nil and not activated.Value

		buyPad.CanCollide = false
		buyPad.CanQuery = shouldShow
		buyPad.Material = Enum.Material.Neon
		setGuiEnabled(priceLabel, shouldShow)
		setGuiEnabled(upgradeLabel, shouldShow)

		if not shouldShow then
			buyPad.Transparency = 1
			buyPad.CanTouch = false
			return
		end

		if not dependencyMet() then
			buyPad.Color = COLOR_LOCKED
			buyPad.Transparency = 0.68
			buyPad.CanTouch = false
			if priceText and priceText:IsA("TextLabel") then
				priceText.Text = "LOCKED"
				priceText.TextColor3 = COLOR_LOCKED
			end
			if upgradeText and upgradeText:IsA("TextLabel") then
				upgradeText.Text = "Requires Avatar Centre"
				upgradeText.TextColor3 = COLOR_LOCKED
			end
			return
		end

		local cash = getCash(owner)
		local affordable = cash ~= nil and (cash :: any).Value >= price.Value
		local color = affordable and COLOR_GREEN or COLOR_RED

		buyPad.Color = color
		buyPad.Transparency = 0.45
		buyPad.CanTouch = true
		if priceText and priceText:IsA("TextLabel") then
			priceText.Text = formatCash(price.Value)
			priceText.TextColor3 = color
		end
		if upgradeText and upgradeText:IsA("TextLabel") then
			upgradeText.Text = displayName.Value
			upgradeText.TextColor3 = color
		end
	end

	local function applyState()
		updateSprintReward()
		if not getOwner() then
			clearTreadmill()
			updatePad()
			return
		end

		if activated.Value then
			ensureTreadmill()
		else
			clearTreadmill()
		end
		updatePad()
	end

	buyPad.Touched:Connect(function(hit: BasePart)
		if processing or activated.Value or not dependencyMet() then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or plot:GetAttribute("Owner") ~= player.UserId then
			return
		end

		local cash = getCash(player)
		if not cash or (cash :: any).Value < price.Value then
			updatePad()
			return
		end

		processing = true
		local model = spawnTreadmill()
		if not model then
			processing = false
			return
		end

		(cash :: any).Value -= price.Value
		activated.Value = true

		PurchaseEffectModule.PlayAcrossParts(TreadmillTheme.GetVisualParts(model), {
			color = PlotTheme.GetPlotColor(plot),
		}, {
			pointCount = 8,
			totalParticleBudget = 72,
		})
		PurchaseSoundModule.PlayPurchaseForTarget(player, buyPad)

		task.delay(0.5, function()
			processing = false
			updatePad()
		end)
	end)

	activated.Changed:Connect(applyState)
	avatarActivated.Changed:Connect(updatePad)
	price.Changed:Connect(updatePad)
	sprintMultiplier.Changed:Connect(updateSprintReward)
	plot:GetAttributeChangedSignal("Owner"):Connect(applyState)
	plot:GetAttributeChangedSignal("PlotColor"):Connect(function()
		if activated.Value and getOwner() then
			ensureTreadmill()
		end
	end)

	table.insert(padRefreshers, updatePad)
	applyState()
	return true
end

local wiredCount = 0
for plotIndex = 1, 10 do
	local plot = workspace:FindFirstChild("P" .. plotIndex)
	if plot and wirePlot(plot) then
		wiredCount += 1
	end
end

task.spawn(function()
	while true do
		task.wait(PAD_REFRESH_SECONDS)
		for _, refresh in ipairs(padRefreshers) do
			refresh()
		end
	end
end)

print(("[SpeedUpgradeTreadmillService] Wired %d treadmill upgrade(s)."):format(wiredCount))
