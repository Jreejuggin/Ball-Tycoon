--!strict
-- VoicelineStationService
-- Server authority for the Worker1 prerequisite, station purchase, saved
-- activation, themed visuals, and buy-pad feedback across all ten plots.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlotTheme = require(ReplicatedStorage:WaitForChild("PlotTheme"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))
local VoicelineStationTheme = require(
	ServerStorage:WaitForChild("Modules"):WaitForChild("VoicelineStationTheme")
)

local Catalog = require(ReplicatedStorage:WaitForChild("VoicelineCatalog"))
local BuyPadLayout = require(ServerStorage:WaitForChild("Modules"):WaitForChild("VoicelineBuyPadLayout"))
local openEvent = ReplicatedStorage:WaitForChild("VoicelineMenuEvent") :: RemoteEvent
local lastInteractionAt: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	lastInteractionAt[player] = nil
end)

local STATION_NAME = "VoicelineStation"
local AVAILABLE_PREVIEW_TRANSPARENCY = 0.6
local ORIGINAL_TRANSPARENCY_ATTRIBUTE = "VoicelineUnlockedTransparency"
local PAD_TRANSPARENCY = 0.5
local PAD_REFRESH_SECONDS = 0.5
local COLOR_GREEN = Color3.new(0, 1, 0)
local COLOR_RED = Color3.new(0.8, 0.1, 0.1)

local function getVisualParts(station: Model): { BasePart }
	return VoicelineStationTheme.GetVisualParts(station)
end

local function getWorkerOneActivation(plot: Instance): BoolValue?
	local centreSlots = plot:FindFirstChild("CentreSlots")
	local workerCentre = centreSlots and centreSlots:FindFirstChild("Centre01_Worker")
	local activations = workerCentre and workerCentre:FindFirstChild("WorkerActivations")
	local workerOne = activations and activations:FindFirstChild("Worker1")

	if workerOne and workerOne:IsA("BoolValue") then
		return workerOne
	end
	return nil
end

local function formatPrice(value: number): string
	local digits = tostring(math.max(0, math.floor(value)))
	local formatted = digits
	while true do
		local replaced, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return "$" .. formatted
end

local function getOwnerPlayer(plot: Instance): Player?
	local ownerId = tonumber(plot:GetAttribute("Owner"))
	return ownerId and Players:GetPlayerByUserId(ownerId) or nil
end

local function getCash(player: Player?): any
	local leaderstats = player and player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) and cash or nil
end

local padRefreshers: { () -> () } = {}

local function wirePlot(plot: Instance): boolean
	local station = plot:FindFirstChild(STATION_NAME)
	if not station or not station:IsA("Model") then
		warn(("[VoicelineStationService] Missing %s.%s"):format(plot:GetFullName(), STATION_NAME))
		return false
	end

	local workerOne = getWorkerOneActivation(plot)
	if not workerOne then
		warn(("[VoicelineStationService] Missing saved Worker1 activation in %s"):format(
			plot:GetFullName()
		))
		return false
	end

	local purchaseState = station:FindFirstChild("PurchaseState")
	local activated = purchaseState and purchaseState:FindFirstChild("Activated")
	local price = station:FindFirstChild("Price")
	local buyPad = station:FindFirstChild("BuyPad")
	local head = buyPad and buyPad:FindFirstChild("Head")
	if not purchaseState or not purchaseState:IsA("Folder")
		or not activated or not activated:IsA("BoolValue")
		or not price or not price:IsA("IntValue")
		or not buyPad or not buyPad:IsA("Model")
		or not head or not head:IsA("BasePart")
	then
		warn(("[VoicelineStationService] Incomplete purchase configuration in %s"):format(
			station:GetFullName()
		))
		return false
	end

	local collisionFolder = station:FindFirstChild("Collision")
	local collision = collisionFolder and collisionFolder:FindFirstChild("CollisionBox")
	if not collision or not collision:IsA("BasePart") then
		warn(("[VoicelineStationService] Missing CollisionBox in %s"):format(
			station:GetFullName()
		))
		return false
	end

	local visualParts = getVisualParts(station)
	local microphone = station:FindFirstChild("VoicelineMicrophone_Roblox")
	local button = microphone and microphone:FindFirstChild("MIC_ButtonGlow_Yellow", true)
	if not button or not button:IsA("BasePart") then
		warn("[VoicelineStationService] Missing microphone button: " .. station:GetFullName())
		return false
	end
	local prompt = button:FindFirstChild("VoicelinePrompt") :: ProximityPrompt
	local glow = button:FindFirstChild("VoicelineGlow") :: PointLight
	if not prompt or not glow then
		warn("[VoicelineStationService] Missing microphone interaction configuration")
		return false
	end

	-- A prompt can be spoofed by a client; validate owner, saved state, life,
	-- and server-observed distance before sending the catalog to that player.
	prompt.Triggered:Connect(function(player)
		if not prompt.Enabled or not activated.Value or not workerOne.Value
			or plot:GetAttribute("Owner") ~= player.UserId
			or plot:GetAttribute("RestoringProgress") then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0
			or (root.Position - button.Position).Magnitude > prompt.MaxActivationDistance + 2 then return end
		local now = os.clock()
		if now - (lastInteractionAt[player] or -math.huge) < 0.5 then return end
		lastInteractionAt[player] = now
		openEvent:FireClient(player, {
			station = station,
			plot = plot,
			color = PlotTheme.GetPlotColor(plot),
			entries = Catalog,
		})
	end)
	local padUI = BuyPadLayout.Apply(station)
	local priceLabel = padUI.priceLabel
	local priceText = padUI.priceText
	local themeWarningShown = false
	local isProcessingPurchase = false

	local function applyTheme()
		local color = PlotTheme.GetPlotColor(plot)
		local changed = VoicelineStationTheme.ApplyColor(station, color, plot.Name)
		if changed ~= VoicelineStationTheme.ExpectedAccentCount and not themeWarningShown then
			themeWarningShown = true
			warn(("[VoicelineStationService] %s has %d/%d accent parts"):format(
				station:GetFullName(),
				changed,
				VoicelineStationTheme.ExpectedAccentCount
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

		padUI.upgradeLabel.Enabled = available
		priceLabel.Enabled = available
		padUI.titleText.Text = "Worker Voicelines"
		padUI.benefitText.Text = "🎤 " .. tostring(#Catalog) .. " audios"
		priceText.Text = formatPrice(price.Value)
		priceText.TextColor3 = color
		station:SetAttribute("PurchasePrice", price.Value)
	end

	local function applyState()
		-- Three-state progression:
		--   Hidden    = Worker1 has not been purchased.
		--   Available = Worker1 is purchased; the station is a 0.6 ghost.
		--   Purchased = the first voiceline purchase is saved; station is solid.
		local hasOwner = plot:GetAttribute("Owner") ~= nil
		local workerPurchased = hasOwner and workerOne.Value
		local purchased = workerPurchased and activated.Value
		prompt.Enabled = purchased
		glow.Enabled = purchased

		applyTheme()
		for _, part in ipairs(visualParts) do
			local originalTransparency = part:GetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE)
			if type(originalTransparency) ~= "number" then
				originalTransparency = 0
			end

			if purchased then
				part.Transparency = math.clamp(originalTransparency, 0, 1)
			elseif workerPurchased then
				part.Transparency = math.max(originalTransparency, AVAILABLE_PREVIEW_TRANSPARENCY)
			else
				part.Transparency = 1
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

		station:SetAttribute("Status", purchased and "Purchased" or (workerPurchased and "Available" or "Hidden"))
		station:SetAttribute("Unlocked", purchased)
		if plot:GetAttribute("VoiceLinesUnlocked") ~= purchased then
			plot:SetAttribute("VoiceLinesUnlocked", purchased)
		end
		updatePad()
	end

	head.Touched:Connect(function(hit: BasePart)
		if isProcessingPurchase or activated.Value or not workerOne.Value
			or plot:GetAttribute("RestoringProgress") then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or plot:GetAttribute("Owner") ~= player.UserId then
			return
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0
			or (root.Position - head.Position).Magnitude > 10 then return end

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
	plot:GetAttributeChangedSignal("PlotColor"):Connect(applyTheme)

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

print(("[VoicelineStationService] Wired %d station(s) with Worker1 prerequisites and saved purchases."):format(
	wiredCount
))
