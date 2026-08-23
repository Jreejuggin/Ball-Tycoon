--!strict
-- WorkerNotesGiftsStationService
-- Server-authoritative Worker1 prerequisite, $5 purchase, persistence state,
-- visuals, collision, and buy-pad feedback for all ten Worker Centres.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlotTheme = require(ReplicatedStorage:WaitForChild("PlotTheme"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))
local StationTheme = require(
	ServerStorage:WaitForChild("Modules"):WaitForChild("WorkerNotesGiftsStationTheme")
)

local INTERACTION_EVENT_NAME = "WorkerGiftsInteractionEvent"
local interactionEvent: RemoteEvent
local existingInteractionEvent = ReplicatedStorage:FindFirstChild(INTERACTION_EVENT_NAME)
if existingInteractionEvent and existingInteractionEvent:IsA("RemoteEvent") then
	interactionEvent = existingInteractionEvent
else
	if existingInteractionEvent then
		existingInteractionEvent:Destroy()
	end
	interactionEvent = Instance.new("RemoteEvent")
	interactionEvent.Name = INTERACTION_EVENT_NAME
	interactionEvent.Parent = ReplicatedStorage
end

local STATION_NAME = "WorkerNotesGiftsStation"
local ORIGINAL_TRANSPARENCY_ATTRIBUTE = "WorkerGiftsUnlockedTransparency"
local LOCKED_TRANSPARENCY = 1
local AVAILABLE_TRANSPARENCY = 0.6
local PAD_TRANSPARENCY = 0
local PAD_REFRESH_SECONDS = 0.5
local COLOR_GREEN = Color3.new(0, 1, 0)
local COLOR_RED = Color3.new(0.8, 0.1, 0.1)
local INTERACTION_COOLDOWN_SECONDS = 1
local POPUP_MESSAGES = {
	"A worker packed a surprise gift!",
	"Your workers found something useful!",
	"A daily worker gift is waiting!",
	"The Worker Gifts station is ready!",
}
local popupRandom = Random.new()
local lastInteractionAtByUserId: { [number]: number } = {}

local function formatPrice(value: number): string
	local formatted = tostring(math.max(0, math.floor(value)))
	while true do
		local updated, replacements = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = updated
		if replacements == 0 then
			break
		end
	end
	return "$" .. formatted
end

local function ensureBillboard(parent: Instance, name: string): BillboardGui
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("BillboardGui") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Parent = parent
	return billboard
end

local function ensureProximityPrompt(parent: Instance, name: string): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.Parent = parent
	return prompt
end

local function ensureTextLabel(parent: Instance, name: string): TextLabel
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("TextLabel") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.Parent = parent
	return textLabel
end

local function styleTextLabel(textLabel: TextLabel, color: Color3)
	textLabel.BackgroundTransparency = 1
	textLabel.TextScaled = true
	textLabel.TextWrapped = true
	textLabel.FontFace = Font.new(
		"rbxasset://fonts/families/GothamSSm.json",
		Enum.FontWeight.Bold,
		Enum.FontStyle.Normal
	)
	textLabel.TextColor3 = color
	textLabel.TextTransparency = 0
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.TextStrokeTransparency = 0
end

local function getOwnerPlayer(plot: Instance): Player?
	local ownerId = tonumber(plot:GetAttribute("Owner"))
	return ownerId and Players:GetPlayerByUserId(ownerId) or nil
end

local function getCash(player: Player?): NumberValue?
	local leaderstats = player and player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
		return cash :: any
	end
	return nil
end

local padRefreshers: { () -> () } = {}

local function wirePlot(plot: Instance): boolean
	local centreSlots = plot:FindFirstChild("CentreSlots")
	local workerCentre = centreSlots and centreSlots:FindFirstChild("Centre01_Worker")
	local workerActivations = workerCentre and workerCentre:FindFirstChild("WorkerActivations")
	local workerOne = workerActivations and workerActivations:FindFirstChild("Worker1")
	local station = workerCentre and workerCentre:FindFirstChild(STATION_NAME)

	if not workerCentre
		or not workerOne
		or not workerOne:IsA("BoolValue")
		or not station
		or not station:IsA("Model")
	then
		warn(("[WorkerNotesGiftsStationService] Incomplete Worker Centre station in %s"):format(
			plot:GetFullName()
		))
		return false
	end

	local purchaseState = station:FindFirstChild("PurchaseState")
	local activated = purchaseState and purchaseState:FindFirstChild("Activated")
	local price = station:FindFirstChild("Price")
	local buyPad = station:FindFirstChild("BuyPad")
	local head = buyPad and buyPad:FindFirstChild("Head")
	local giftStationRoot = station:FindFirstChild("WorkerGiftStation_Root")
	local collisionFolder = station:FindFirstChild("Collision")
	local collision = collisionFolder and collisionFolder:FindFirstChild("CollisionBox")

	if not purchaseState or not purchaseState:IsA("Folder")
		or not activated or not activated:IsA("BoolValue")
		or not price or not price:IsA("IntValue")
		or not buyPad or not buyPad:IsA("Model")
		or not head or not head:IsA("BasePart")
		or not giftStationRoot or not giftStationRoot:IsA("Model")
		or not collision or not collision:IsA("BasePart")
	then
		warn(("[WorkerNotesGiftsStationService] Incomplete purchase configuration in %s"):format(
			station:GetFullName()
		))
		return false
	end

	local visualParts = StationTheme.GetVisualParts(station)

	-- Match the circular Worker Speed purchase pad dimensions while preserving
	-- this station's existing position and plot-facing rotation.
	if head:IsA("Part") then
		head.Shape = Enum.PartType.Cylinder
		head.Size = Vector3.new(0.35, 4.29, 4.29)
		head.CFrame = head.CFrame * CFrame.Angles(0, 0, math.rad(90))
	end

	local labelAnchor = buyPad:FindFirstChild("LabelAnchor")
	if labelAnchor and not labelAnchor:IsA("BasePart") then
		labelAnchor:Destroy()
		labelAnchor = nil
	end
	if not labelAnchor then
		labelAnchor = Instance.new("Part")
		labelAnchor.Name = "LabelAnchor"
		labelAnchor.Parent = buyPad
	end
	labelAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	labelAnchor.CFrame = CFrame.new(head.Position)
	labelAnchor.Transparency = 1
	labelAnchor.Anchored = true
	labelAnchor.CanCollide = false
	labelAnchor.CanTouch = false
	labelAnchor.CanQuery = false
	labelAnchor.CastShadow = false

	local existingPriceLabel = head:FindFirstChild("PriceLabel")
	if existingPriceLabel and not labelAnchor:FindFirstChild("PriceLabel") then
		existingPriceLabel.Parent = labelAnchor
	end

	local upgradeLabel = ensureBillboard(labelAnchor, "UpgradeLabel")
	upgradeLabel.Adornee = labelAnchor
	upgradeLabel.Size = UDim2.new(4, 0, 2, 0)
	upgradeLabel.StudsOffset = Vector3.new(0, 5, 0)
	upgradeLabel.StudsOffsetWorldSpace = Vector3.zero
	upgradeLabel.AlwaysOnTop = false
	upgradeLabel.LightInfluence = 0
	upgradeLabel.MaxDistance = math.huge
	upgradeLabel.Enabled = false

	local titleText = ensureTextLabel(upgradeLabel, "TitleText")
	styleTextLabel(titleText, Color3.new(1, 1, 1))
	titleText.Size = UDim2.new(1, 0, 0.55, 0)
	titleText.Position = UDim2.new(0, 0, 0, 0)
	titleText.Text = "Daily worker gifts"

	local benefitText = ensureTextLabel(upgradeLabel, "BenefitText")
	styleTextLabel(benefitText, Color3.fromRGB(255, 235, 90))
	benefitText.Size = UDim2.new(1, 0, 0.48, 0)
	benefitText.Position = UDim2.new(0, 0, 0.52, 0)
	benefitText.Text = "🎁 1 gift/day"

	local priceLabel = ensureBillboard(labelAnchor, "PriceLabel")
	priceLabel.Adornee = labelAnchor
	priceLabel.Size = UDim2.new(4, 0, 1.5, 0)
	priceLabel.StudsOffset = Vector3.new(0, 3, 0)
	priceLabel.StudsOffsetWorldSpace = Vector3.zero
	priceLabel.AlwaysOnTop = false
	priceLabel.LightInfluence = 0
	priceLabel.MaxDistance = math.huge
	priceLabel.Enabled = false

	local priceText = ensureTextLabel(priceLabel, "PriceText")
	styleTextLabel(priceText, COLOR_GREEN)
	priceText.Size = UDim2.fromScale(1, 1)
	priceText.Position = UDim2.fromScale(0, 0)

	-- Persistent current-benefit display above the Worker Gifts statue.
	local statusAnchor = station:FindFirstChild("GiftStatusAnchor")
	if statusAnchor and not statusAnchor:IsA("BasePart") then
		statusAnchor:Destroy()
		statusAnchor = nil
	end
	if not statusAnchor then
		statusAnchor = Instance.new("Part")
		statusAnchor.Name = "GiftStatusAnchor"
		statusAnchor.Parent = station
	end

	local rootBoxCFrame, rootBoxSize = giftStationRoot:GetBoundingBox()
	local statusPosition = (rootBoxCFrame * CFrame.new(0, (rootBoxSize.Y / 2) + 0.9, 0)).Position
	statusAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	statusAnchor.CFrame = CFrame.new(statusPosition)
	statusAnchor.Transparency = 1
	statusAnchor.Anchored = true
	statusAnchor.CanCollide = false
	statusAnchor.CanTouch = false
	statusAnchor.CanQuery = false
	statusAnchor.CastShadow = false

	local statusLabel = ensureBillboard(statusAnchor, "GiftStatusLabel")
	statusLabel.Adornee = statusAnchor
	statusLabel.Size = UDim2.new(5, 0, 1.65, 0)
	statusLabel.StudsOffset = Vector3.zero
	statusLabel.StudsOffsetWorldSpace = Vector3.zero
	statusLabel.AlwaysOnTop = false
	statusLabel.LightInfluence = 0
	statusLabel.MaxDistance = math.huge
	statusLabel.Enabled = false

	local statusTitleText = ensureTextLabel(statusLabel, "TitleText")
	styleTextLabel(statusTitleText, Color3.fromRGB(0, 225, 255))
	statusTitleText.Size = UDim2.new(1, 0, 0.48, 0)
	statusTitleText.Position = UDim2.new(0, 0, 0, 0)
	statusTitleText.Text = "Daily worker gifts"

	local statusBenefitText = ensureTextLabel(statusLabel, "BenefitText")
	styleTextLabel(statusBenefitText, Color3.fromRGB(255, 235, 90))
	statusBenefitText.Size = UDim2.new(1, 0, 0.52, 0)
	statusBenefitText.Position = UDim2.new(0, 0, 0.48, 0)
	statusBenefitText.Text = "🎁 1 gift/day"

	local interactionPrompt = ensureProximityPrompt(collision, "WorkerGiftsPrompt")
	interactionPrompt.ActionText = "Interact"
	interactionPrompt.ObjectText = "Daily Worker Gifts"
	interactionPrompt.KeyboardKeyCode = Enum.KeyCode.E
	interactionPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	interactionPrompt.HoldDuration = 0
	interactionPrompt.MaxActivationDistance = 10
	interactionPrompt.RequiresLineOfSight = false
	interactionPrompt.ClickablePrompt = true
	interactionPrompt.Enabled = false

	local isProcessingPurchase = false
	local themeWarningShown = false

	local function applyPlotTheme()
		local color = PlotTheme.GetPlotColor(plot)
		local changed = StationTheme.ApplyColor(station, color, plot.Name)
		if changed ~= StationTheme.ExpectedAccentCount and not themeWarningShown then
			themeWarningShown = true
			warn(("[WorkerNotesGiftsStationService] %s has %d/%d accent parts"):format(
				station:GetFullName(),
				changed,
				StationTheme.ExpectedAccentCount
			))
		end
	end

	local function updatePad()
		local owner = getOwnerPlayer(plot)
		local available = owner ~= nil and workerOne.Value and not activated.Value
		local cash = getCash(owner)
		local affordable = price.Value <= 0 or (cash ~= nil and cash.Value >= price.Value)
		local color = affordable and COLOR_GREEN or COLOR_RED

		head.Material = Enum.Material.Neon
		head.Color = color
		head.Transparency = available and PAD_TRANSPARENCY or 1
		head.CanCollide = false
		head.CanTouch = available
		head.CanQuery = available

		upgradeLabel.Enabled = available
		priceLabel.Enabled = available
		titleText.Text = "Daily worker gifts"
		titleText.TextColor3 = Color3.new(1, 1, 1)
		benefitText.Text = "🎁 1 gift/day"
		benefitText.TextColor3 = Color3.fromRGB(255, 235, 90)
		priceText.Text = formatPrice(price.Value)
		priceText.TextColor3 = color

		station:SetAttribute("PurchasePrice", price.Value)
	end

	local function applyState()
		local hasOwner = plot:GetAttribute("Owner") ~= nil
		local workerPurchased = hasOwner and workerOne.Value
		local purchased = workerPurchased and activated.Value

		statusLabel.Enabled = purchased
		interactionPrompt.Enabled = purchased
		statusTitleText.Text = "Daily worker gifts"
		statusTitleText.TextColor3 = Color3.fromRGB(0, 225, 255)
		statusBenefitText.Text = "🎁 1 gift/day"
		statusBenefitText.TextColor3 = Color3.fromRGB(255, 235, 90)

		-- Worker Gifts stays hidden until Worker1 is purchased, then becomes
		-- a 0.6 ghost purchase and finally turns solid after its own purchase.
		applyPlotTheme()

		for _, part in ipairs(visualParts) do
			local originalTransparency = part:GetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE)
			if type(originalTransparency) ~= "number" then
				originalTransparency = 0
			end

			if purchased then
				part.Transparency = math.clamp(originalTransparency, 0, 1)
			elseif workerPurchased then
				part.Transparency = math.max(originalTransparency, AVAILABLE_TRANSPARENCY)
			else
				part.Transparency = math.max(originalTransparency, LOCKED_TRANSPARENCY)
			end
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = purchased
			part.CastShadow = purchased
		end

		collision.Transparency = 1
		collision.CanCollide = purchased
		collision.CanTouch = false
		collision.CanQuery = purchased
		collision.CastShadow = false

		station:SetAttribute("Unlocked", workerPurchased)
		station:SetAttribute("Purchased", purchased)
		station:SetAttribute("Status", purchased and "Purchased" or (workerPurchased and "Available" or "Hidden"))
		updatePad()
	end

	interactionPrompt.Triggered:Connect(function(player: Player)
		if not activated.Value or plot:GetAttribute("Owner") ~= player.UserId then
			return
		end

		local now = os.clock()
		local lastInteractionAt = lastInteractionAtByUserId[player.UserId] or 0
		if now - lastInteractionAt < INTERACTION_COOLDOWN_SECONDS then
			return
		end
		lastInteractionAtByUserId[player.UserId] = now

		interactionEvent:FireClient(player, {
			title = "Daily Worker Gifts",
			message = POPUP_MESSAGES[popupRandom:NextInteger(1, #POPUP_MESSAGES)],
		})
	end)

	head.Touched:Connect(function(hit: BasePart)
		if isProcessingPurchase or activated.Value or not workerOne.Value then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or plot:GetAttribute("Owner") ~= player.UserId then
			return
		end

		local cash = getCash(player)
		local purchasePrice = math.max(0, price.Value)
		if purchasePrice > 0 and (not cash or cash.Value < purchasePrice) then
			updatePad()
			return
		end

		isProcessingPurchase = true
		if purchasePrice > 0 and cash then
			cash.Value -= purchasePrice
		end
		activated.Value = true
		applyState()

		PurchaseSoundModule.PlayPurchaseForTarget(player, head)
		PurchaseEffectModule.PlayAcrossParts(visualParts, nil, {
			pointCount = 24,
			totalParticleBudget = 100,
		})

		task.delay(0.4, function()
			isProcessingPurchase = false
		end)
	end)

	workerOne:GetPropertyChangedSignal("Value"):Connect(applyState)
	activated:GetPropertyChangedSignal("Value"):Connect(applyState)
	price:GetPropertyChangedSignal("Value"):Connect(updatePad)
	plot:GetAttributeChangedSignal("Owner"):Connect(applyState)
	plot:GetAttributeChangedSignal("PlotColor"):Connect(applyState)

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

print(("[WorkerNotesGiftsStationService] Wired %d station(s) with Worker1 prerequisites and saved purchases."):format(
	wiredCount
))
