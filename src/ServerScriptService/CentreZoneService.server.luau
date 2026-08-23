-- CentreZoneService
-- Server-authoritative progression and visual-state controller for the five
-- open-concept centre areas on every tycoon plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local CENTRE_FOLDER_NAME = "CentreSlots"
local FIRST_DROPPER_FOLDER = "DropperSlots"
local FIRST_DROPPER_COUNT = 5
local CENTRE_ORDER = {
	"Centre01_Worker",
	"Centre02_Home",
	"Centre03_Avatar",
	"Centre04_Orb",
	"Centre05_Pet",
}

local COLOR_GREEN = Color3.fromRGB(30, 255, 75)
local COLOR_RED = Color3.fromRGB(215, 28, 38)
local COLOR_LOCKED = Color3.fromRGB(105, 108, 118)
local COLOR_WHITE = Color3.fromRGB(245, 245, 245)
local HIRING_KIOSK_GHOST_TRANSPARENCY = 0.6

local touchDebounces = {}
local ownerVersions = {}
local cashConnections = {}
local originalPresentationProperties = {}

local function getCentreFolder(plot)
	return plot:FindFirstChild(CENTRE_FOLDER_NAME)
end

local function getOwnerPlayer(plot)
	local ownerId = tonumber(plot:GetAttribute("Owner"))
	if not ownerId then
		return nil
	end
	return Players:GetPlayerByUserId(ownerId)
end

local function getCash(player)
	local leaderstats = player and player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Cash")
end

local function getAccentColor(plot)
	local wall = plot:FindFirstChild("PerimeterWall")
	local neon = wall and wall:FindFirstChild("BackWallLeft_Neon")
	return neon and neon:IsA("BasePart") and neon.Color or COLOR_RED
end

local function firstDroppersComplete(plot)
	local folder = plot:FindFirstChild(FIRST_DROPPER_FOLDER)
	if not folder then
		return false
	end

	for slotIndex = 1, FIRST_DROPPER_COUNT do
		local slot = folder:FindFirstChild("Slot" .. slotIndex)
		local activated = slot and slot:FindFirstChild("Activated")
		if not activated or not activated:IsA("BoolValue") or not activated.Value then
			return false
		end
	end

	return true
end

local function requirementMet(plot, slot)
	local requiredFolder = slot:FindFirstChild("RequiredFolderName")
	if requiredFolder and requiredFolder.Value ~= "" then
		if requiredFolder.Value == FIRST_DROPPER_FOLDER then
			return firstDroppersComplete(plot)
		end
		return false
	end

	local dependency = slot:FindFirstChild("Dependency")
	if not dependency or dependency.Value == "" then
		return true
	end

	local centreFolder = getCentreFolder(plot)
	local prerequisite = centreFolder and centreFolder:FindFirstChild(dependency.Value)
	local activated = prerequisite and prerequisite:FindFirstChild("Activated")
	return activated ~= nil and activated.Value
end

local function setGuiEnabled(pad, guiName, enabled)
	local gui = pad:FindFirstChild(guiName)
	if gui and gui:IsA("BillboardGui") then
		gui.Enabled = enabled
	end
	return gui
end

local function getOriginalPresentationProperties(part)
	local original = originalPresentationProperties[part]
	if not original then
		original = {
			Transparency = part.Transparency,
			CanCollide = part.CanCollide,
			CanTouch = part.CanTouch,
			CanQuery = part.CanQuery,
			CastShadow = part.CastShadow,
		}
		originalPresentationProperties[part] = original
	end
	return original
end

local function setModelPresentation(model, mode, ghostTransparency)
	if not model then
		return
	end

	local collisionFolder = model:FindFirstChild("Collision")
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local original = getOriginalPresentationProperties(descendant)
			local isCollision = collisionFolder and descendant:IsDescendantOf(collisionFolder)

			if mode == "Visible" then
				descendant.Transparency = original.Transparency
				descendant.CanCollide = original.CanCollide
				descendant.CanTouch = original.CanTouch
				descendant.CanQuery = original.CanQuery
				descendant.CastShadow = original.CastShadow
			elseif mode == "Ghost" and not isCollision then
				descendant.Transparency = math.max(original.Transparency, ghostTransparency or 0.6)
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.CastShadow = false
			else
				descendant.Transparency = 1
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.CastShadow = false
			end
		end
	end
end

local function applyWorkerCentrePresentation(plot)
	local centreFolder = getCentreFolder(plot)
	local workerCentre = centreFolder and centreFolder:FindFirstChild("Centre01_Worker")
	local activated = workerCentre and workerCentre:FindFirstChild("Activated")
	if not workerCentre or not activated or not activated:IsA("BoolValue") then
		return
	end

	local purchased = activated.Value
	local available = not purchased and requirementMet(plot, workerCentre)
	local kioskMode = purchased and "Visible" or (available and "Ghost" or "Hidden")
	local hiringKiosk = plot:FindFirstChild("HiringKiosk")
	setModelPresentation(hiringKiosk, kioskMode, HIRING_KIOSK_GHOST_TRANSPARENCY)

	-- WorkerSpeedService owns the speed statue's hidden, ghost, and purchased states.

	-- The centre boundary markers and titles are scenery, not the purchase UI.
	-- Keep the actual Worker Centre BuyPad available so the kiosk can be bought.
	local markers = workerCentre:FindFirstChild("ZoneMarkers")
	if markers then
		if purchased then
			local zoneFloor = markers:FindFirstChild("ZoneFloor")
			local areaTitle = zoneFloor and zoneFloor:FindFirstChild("AreaTitle")
			if areaTitle and areaTitle:IsA("SurfaceGui") then
				areaTitle.Enabled = true
			end
		else
			for _, descendant in ipairs(markers:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Transparency = 1
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
				elseif descendant:IsA("SurfaceGui") then
					descendant.Enabled = false
				end
			end
		end
	end
end

local function updateSlotVisual(plot, slot)
	local activated = slot:FindFirstChild("Activated")
	local price = slot:FindFirstChild("Price")
	local status = slot:FindFirstChild("Status")
	local pad = slot:FindFirstChild("BuyPad")
	local markers = slot:FindFirstChild("ZoneMarkers")
	if not activated or not price or not pad or not pad:IsA("BasePart") or not markers then
		return
	end

	local zoneFloor = markers:FindFirstChild("ZoneFloor")
	local overlay = markers:FindFirstChild("LockOverlay")
	local lockDisplay = overlay and overlay:FindFirstChild("LockDisplay")
	local areaTitle = zoneFloor and zoneFloor:FindFirstChild("AreaTitle")
	local titleText = areaTitle and areaTitle:FindFirstChild("Text")
	local nameGui = pad:FindFirstChild("NameLabel")
	local priceGui = pad:FindFirstChild("PriceLabel")
	local priceText = priceGui and priceGui:FindFirstChild("PriceText")
	local accentColor = getAccentColor(plot)

	local state
	if activated.Value then
		state = "Purchased"
	elseif requirementMet(plot, slot) then
		state = "Available"
	else
		state = "Locked"
	end

	if status and status:IsA("StringValue") then
		status.Value = state
	end

	for _, edgeName in ipairs({"LeftEdge", "AisleEdge", "BackDivider", "FrontDivider"}) do
		local edge = markers:FindFirstChild(edgeName)
		if edge and edge:IsA("BasePart") then
			edge.Color = accentColor
			edge.Transparency = state == "Locked" and 0.38 or 0.08
		end
	end

	if state == "Purchased" then
		pad.Transparency = 1
		pad.CanTouch = false
		setGuiEnabled(pad, "NameLabel", false)
		setGuiEnabled(pad, "PriceLabel", false)

		if overlay then
			overlay.Transparency = 1
		end
		if lockDisplay and lockDisplay:IsA("SurfaceGui") then
			lockDisplay.Enabled = false
		end
		if zoneFloor then
			zoneFloor.Transparency = 0.18
		end
		if titleText then
			titleText.TextColor3 = accentColor
			titleText.TextTransparency = 0.04
		end
		return
	end

	setGuiEnabled(pad, "NameLabel", true)
	setGuiEnabled(pad, "PriceLabel", true)
	pad.Material = Enum.Material.Neon
	pad.CanCollide = false

	if state == "Locked" then
		pad.Color = COLOR_LOCKED
		pad.Transparency = 0.72
		pad.CanTouch = false

		if priceText then
			priceText.Text = "LOCKED"
			priceText.TextColor3 = COLOR_LOCKED
		end
		if overlay then
			overlay.Color = COLOR_LOCKED
			overlay.Transparency = 0.78
		end
		if lockDisplay and lockDisplay:IsA("SurfaceGui") then
			lockDisplay.Enabled = true
		end
		if zoneFloor then
			zoneFloor.Transparency = 0.46
		end
		if titleText then
			titleText.TextColor3 = COLOR_LOCKED
			titleText.TextTransparency = 0.18
		end
		return
	end

	local owner = getOwnerPlayer(plot)
	local cash = getCash(owner)
	local affordable = cash ~= nil and cash.Value >= price.Value
	local availableColor = affordable and COLOR_GREEN or COLOR_RED

	pad.Color = availableColor
	pad.Transparency = 0.42
	pad.CanTouch = true

	if priceText then
		priceText.Text = "$" .. tostring(price.Value)
		priceText.TextColor3 = availableColor
	end
	if overlay then
		overlay.Color = accentColor
		overlay.Transparency = 0.94
	end
	if lockDisplay and lockDisplay:IsA("SurfaceGui") then
		lockDisplay.Enabled = false
	end
	if zoneFloor then
		zoneFloor.Transparency = 0.26
	end
	if titleText then
		titleText.TextColor3 = accentColor
		titleText.TextTransparency = 0.08
	end
end

local function updatePlot(plot)
	local centreFolder = getCentreFolder(plot)
	if not centreFolder then
		return
	end

	for _, slotName in ipairs(CENTRE_ORDER) do
		local slot = centreFolder:FindFirstChild(slotName)
		if slot then
			updateSlotVisual(plot, slot)
		end
	end

	applyWorkerCentrePresentation(plot)
end

local function resetCentreProgress(plot)
	local centreFolder = getCentreFolder(plot)
	if not centreFolder then
		return
	end

	for _, slotName in ipairs(CENTRE_ORDER) do
		local slot = centreFolder:FindFirstChild(slotName)
		local activated = slot and slot:FindFirstChild("Activated")
		if activated and activated:IsA("BoolValue") then
			activated.Value = false
		end
	end
end

local function applySavedProgress(plot, player, version)
	local waited = 0
	while player.Parent and not player:GetAttribute("DataLoaded") and waited < 10 do
		if ownerVersions[plot] ~= version or getOwnerPlayer(plot) ~= player then
			return
		end
		task.wait(0.1)
		waited += 0.1
	end

	if ownerVersions[plot] ~= version or getOwnerPlayer(plot) ~= player then
		return
	end

	local savedLevel = tonumber(player:GetAttribute("CentreLevel"))
		or tonumber(player:GetAttribute("SavedCentreLevel"))
		or 0
	savedLevel = math.clamp(math.floor(savedLevel), 0, #CENTRE_ORDER)
	player:SetAttribute("CentreLevel", savedLevel)

	local centreFolder = getCentreFolder(plot)
	if not centreFolder then
		return
	end

	for order, slotName in ipairs(CENTRE_ORDER) do
		local slot = centreFolder:FindFirstChild(slotName)
		local activated = slot and slot:FindFirstChild("Activated")
		if activated and activated:IsA("BoolValue") then
			activated.Value = order <= savedLevel
		end
	end

	local oldConnection = cashConnections[plot]
	if oldConnection then
		oldConnection:Disconnect()
		cashConnections[plot] = nil
	end

	local cash = getCash(player)
	if cash then
		cashConnections[plot] = cash:GetPropertyChangedSignal("Value"):Connect(function()
			if getOwnerPlayer(plot) == player then
				updatePlot(plot)
			end
		end)
	end

	updatePlot(plot)
end

local function onOwnerChanged(plot)
	ownerVersions[plot] = (ownerVersions[plot] or 0) + 1
	local version = ownerVersions[plot]

	local oldConnection = cashConnections[plot]
	if oldConnection then
		oldConnection:Disconnect()
		cashConnections[plot] = nil
	end

	-- Reset immediately so progress from a previous owner can never leak.
	resetCentreProgress(plot)
	updatePlot(plot)

	local player = getOwnerPlayer(plot)
	if player then
		task.spawn(applySavedProgress, plot, player, version)
	end
end

local function playerFromHit(hit)
	if not hit then
		return nil
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character) or nil
end

local function purchaseCentre(plot, slot, hit)
	local pad = slot:FindFirstChild("BuyPad")
	if not pad or touchDebounces[pad] then
		return
	end
	touchDebounces[pad] = true

	local player = playerFromHit(hit)
	local activated = slot:FindFirstChild("Activated")
	local price = slot:FindFirstChild("Price")
	local order = slot:FindFirstChild("Order")

	if not player
		or getOwnerPlayer(plot) ~= player
		or not activated
		or activated.Value
		or not price
		or not requirementMet(plot, slot)
	then
		task.delay(0.25, function()
			touchDebounces[pad] = nil
		end)
		return
	end

	local cash = getCash(player)
	if not cash or cash.Value < price.Value then
		task.delay(0.25, function()
			touchDebounces[pad] = nil
		end)
		return
	end

	-- All currency and progression changes happen on the server after ownership,
	-- dependency, and affordability have been revalidated.
	cash.Value -= price.Value
	activated.Value = true

	local purchasedOrder = order and order.Value or 0
	local currentLevel = tonumber(player:GetAttribute("CentreLevel")) or 0
	if purchasedOrder > currentLevel then
		player:SetAttribute("CentreLevel", purchasedOrder)
	end

	PurchaseSoundModule.PlayPurchaseForTarget(player, pad)
	PurchaseEffectModule.Play(pad.Position + Vector3.new(0, 1.4, 0), {
		color = getAccentColor(plot),
		particleCount = 32,
	})

	updatePlot(plot)
	task.delay(0.4, function()
		touchDebounces[pad] = nil
	end)
end

local function wirePlot(plot)
	local centreFolder = getCentreFolder(plot)
	if not centreFolder then
		return
	end

	for _, slotName in ipairs(CENTRE_ORDER) do
		local slot = centreFolder:FindFirstChild(slotName)
		if slot then
			local activated = slot:FindFirstChild("Activated")
			if activated and activated:IsA("BoolValue") then
				activated:GetPropertyChangedSignal("Value"):Connect(function()
					updatePlot(plot)
				end)
			end

			local pad = slot:FindFirstChild("BuyPad")
			if pad and pad:IsA("BasePart") then
				pad.Touched:Connect(function(hit)
					purchaseCentre(plot, slot, hit)
				end)
			end
		end
	end

	local droppers = plot:FindFirstChild(FIRST_DROPPER_FOLDER)
	if droppers then
		for slotIndex = 1, FIRST_DROPPER_COUNT do
			local slot = droppers:FindFirstChild("Slot" .. slotIndex)
			local activated = slot and slot:FindFirstChild("Activated")
			if activated and activated:IsA("BoolValue") then
				activated:GetPropertyChangedSignal("Value"):Connect(function()
					updatePlot(plot)
				end)
			end
		end
	end

	plot:GetAttributeChangedSignal("Owner"):Connect(function()
		onOwnerChanged(plot)
	end)

	onOwnerChanged(plot)
end

for plotIndex = 1, 10 do
	local plot = workspace:FindFirstChild("P" .. plotIndex)
	if plot then
		wirePlot(plot)
	end
end

print("[CentreZoneService] Wired 5 sequential centre areas on 10 plots.")
