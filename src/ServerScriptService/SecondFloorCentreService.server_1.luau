--[[
	SecondFloorCentreService
	Runs the floor-2 copies of the five centres (Worker, Home, Avatar, Orb, Pet)
	that SecondFloorService builds into each plot's SecondFloor.CentreSlots.

	Uses the same rules and visuals as the first floor's CentreZoneService:
	  * Centres unlock in order (each depends on the one before it).
	  * Locked / Available / Purchased quadrant presentation, green/red pad by
	    affordability, accent color taken from the plot.
	  * Server-authoritative purchase: owner, requirement and cash re-checked
	    before Cash is deducted, with a debounce so a touch can't charge twice.

	Differences from floor 1, all deliberate:
	  * Nothing shows until the second floor itself is bought (Hidden state).
	  * The Worker Centre unlocks after the first row of cubicles instead of the
	    first row of droppers, since floor 2 has no droppers.
	  * Progress is saved through the centres' Activated values, which
	    TycoonProgressService already saves, restores and resets. Floor 1's
	    CentreLevel attribute is never touched, so the two floors stay separate.

	Upgrades inside the centres: the Home Centre's structures (walls, glass,
	roof, lights) are sold on floor 2 by StructureSequenceService. The Worker
	Centre shows a decorative copy of floor 1's layout (Hiring Kiosk, speed
	sign, notes & gifts station), ghosted while available and solid once
	bought. The other centres' floor-1 upgrades are not copied: Worker hiring serves floor 1's
	droppers, and Avatar items are per-player tools and boosts, so second copies
	would charge again for things the player already owns. Orb and Pet have no
	upgrades yet. Their floor-2 zones are ready for upgrades when designed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ServerScriptService:WaitForChild("SecondFloorConfig"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

-- Same colors as CentreZoneService, so both floors look identical.
local COLOR_GREEN = Color3.fromRGB(30, 255, 75)
local COLOR_RED = Color3.fromRGB(215, 28, 38)
local COLOR_LOCKED = Color3.fromRGB(105, 108, 118)
local EDGE_NAMES = { "LeftEdge", "AisleEdge", "BackDivider", "FrontDivider" }
local MANAGED_MARKERS = { ZoneFloor = true, LockOverlay = true }
for _, edgeName in ipairs(EDGE_NAMES) do
	MANAGED_MARKERS[edgeName] = true
end

local UPDATE_INTERVAL_SECONDS = 0.5
local PURCHASE_COOLDOWN_SECONDS = 0.4

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function getOwnerPlayer(plot)
	local ownerId = tonumber(plot:GetAttribute("Owner"))
	return ownerId and Players:GetPlayerByUserId(ownerId) or nil
end

local function getCash(player)
	local leaderstats = player and player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Cash")
end

local function getPlayerFromHit(hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character) or nil
end

-- Same source as CentreZoneService: the plot's neon back-wall strip.
local function getAccentColor(plot)
	local wall = plot:FindFirstChild("PerimeterWall")
	local neon = wall and wall:FindFirstChild("BackWallLeft_Neon")
	return neon and neon:IsA("BasePart") and neon.Color or COLOR_RED
end

local function setGuiEnabled(gui, enabled)
	if gui and (gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")) then
		gui.Enabled = enabled
	end
end

---------------------------------------------------------------------------
-- Decorative layout props (floor-2 Worker Centre)
-- Same three looks CentreZoneService gives floor 1's Hiring Kiosk:
--   Hidden  - centre locked (or floor 2 not bought): invisible, no collision.
--   Ghost   - centre available: see-through preview; collision proxies solid.
--   Visible - centre bought: solid look; collision proxies solid.
-- SecondFloorService records each part's SolidTransparency and whether it is
-- a collision proxy (LayoutCollision) when it builds the copy.
---------------------------------------------------------------------------

local function collectLayoutParts(centre)
	local parts = {}
	local folder = centre:FindFirstChild(Config.LayoutFolderName)
	if folder then
		for _, descendant in ipairs(folder:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	return parts
end

local function applyLayoutMode(parts, mode)
	for _, part in ipairs(parts) do
		local isCollision = part:GetAttribute("LayoutCollision") == true
		local solid = part:GetAttribute("SolidTransparency") or 0

		if mode == "Hidden" then
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		elseif isCollision then
			-- Invisible blocker, active whenever the prop is shown.
			part.Transparency = 1
			part.CanCollide = true
			part.CanQuery = true
			part.CastShadow = false
		elseif mode == "Ghost" then
			part.Transparency = math.max(solid, Config.GhostTransparency)
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		else -- Visible
			part.Transparency = solid
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = solid < 1
		end
		part.CanTouch = false
	end
end

---------------------------------------------------------------------------
-- Per-centre records
---------------------------------------------------------------------------

local function makeRecord(centre)
	local markers = centre:FindFirstChild("ZoneMarkers")
	local pad = centre:FindFirstChild("BuyPad")
	local zoneFloor = markers and markers:FindFirstChild("ZoneFloor")
	local overlay = markers and markers:FindFirstChild("LockOverlay")
	local areaTitle = zoneFloor and zoneFloor:FindFirstChild("AreaTitle")
	local priceGui = pad and pad:FindFirstChild("PriceLabel")

	local edges = {}
	for _, edgeName in ipairs(EDGE_NAMES) do
		local edge = markers and markers:FindFirstChild(edgeName)
		if edge and edge:IsA("BasePart") then
			table.insert(edges, edge)
		end
	end

	-- Any other marker parts are just restored to their authored look.
	local otherParts = {}
	if markers then
		for _, descendant in ipairs(markers:GetDescendants()) do
			if descendant:IsA("BasePart") and not MANAGED_MARKERS[descendant.Name] then
				table.insert(otherParts, descendant)
			end
		end
	end

	return {
		centre = centre,
		activated = centre:FindFirstChild("Activated"),
		price = centre:FindFirstChild("Price"),
		status = centre:FindFirstChild("Status"),
		pad = pad,
		zoneFloor = zoneFloor,
		overlay = overlay,
		lockDisplay = overlay and overlay:FindFirstChild("LockDisplay"),
		areaTitle = areaTitle,
		titleText = areaTitle and areaTitle:FindFirstChild("Text"),
		nameGui = pad and pad:FindFirstChild("NameLabel"),
		priceGui = priceGui,
		priceText = priceGui and priceGui:FindFirstChild("PriceText"),
		edges = edges,
		otherParts = otherParts,
		layoutParts = collectLayoutParts(centre),
		layoutMode = nil, -- last applied mode, so the 0.5s poll doesn't rewrite parts
		processing = false,
	}
end

local function isRecordComplete(record)
	return record.activated and record.price and record.pad and record.pad:IsA("BasePart")
end

---------------------------------------------------------------------------
-- Per-plot logic
---------------------------------------------------------------------------

local function setupPlot(plot)
	local secondFloor = plot:FindFirstChild("SecondFloor")
	local floorActivated = secondFloor and secondFloor:FindFirstChild("Activated")
	local centreFolder = secondFloor and secondFloor:FindFirstChild("CentreSlots")
	local cubicleFolder = secondFloor and secondFloor:FindFirstChild("Cubicles")
	if not (floorActivated and centreFolder) then
		warn("[SecondFloorCentreService] " .. plot.Name .. " has no second-floor centres.")
		return
	end

	local records = {}
	for _, centreName in ipairs(Config.Centres) do
		local centre = centreFolder:FindFirstChild(centreName)
		if centre then
			local record = makeRecord(centre)
			if isRecordComplete(record) then
				table.insert(records, record)
			else
				warn("[SecondFloorCentreService] Incomplete centre: " .. centre:GetFullName())
			end
		end
	end

	-- Floor 2's version of "a row of droppers": every first-row cubicle bought.
	local function firstCubicleRowComplete()
		if not cubicleFolder then
			return false
		end
		local found = 0
		for _, cubicle in ipairs(cubicleFolder:GetChildren()) do
			local order = cubicle:GetAttribute("Order")
			if order and order <= Config.CubicleRowSize then
				local activated = cubicle:FindFirstChild("Activated")
				if not (activated and activated.Value) then
					return false
				end
				found += 1
			end
		end
		return found > 0
	end

	local function requirementMet(record)
		if not floorActivated.Value then
			return false
		end

		local required = record.centre:FindFirstChild("RequiredFolderName")
		if required and required.Value ~= "" then
			if required.Value == Config.WorkerCentreRequirement then
				return firstCubicleRowComplete()
			end
			return false
		end

		local dependency = record.centre:FindFirstChild("Dependency")
		if not dependency or dependency.Value == "" then
			return true
		end
		local prerequisite = centreFolder:FindFirstChild(dependency.Value)
		local activated = prerequisite and prerequisite:FindFirstChild("Activated")
		return activated ~= nil and activated.Value
	end

	local function getState(record)
		if not floorActivated.Value then
			return "Hidden"
		end
		if record.activated.Value then
			return "Purchased"
		end
		if requirementMet(record) then
			return "Available"
		end
		return "Locked"
	end

	local function hideRecord(record)
		local pad = record.pad
		pad.Transparency = 1
		pad.CanTouch = false
		setGuiEnabled(record.nameGui, false)
		setGuiEnabled(record.priceGui, false)
		setGuiEnabled(record.areaTitle, false)
		setGuiEnabled(record.lockDisplay, false)
		for _, part in ipairs({ record.zoneFloor, record.overlay }) do
			if part then
				part.Transparency = 1
			end
		end
		for _, part in ipairs(record.edges) do
			part.Transparency = 1
		end
		for _, part in ipairs(record.otherParts) do
			part.Transparency = 1
		end
	end

	-- Mirrors CentreZoneService.updateSlotVisual for the three visible states.
	local function applyRecord(record)
		local state = getState(record)
		if record.status and record.status:IsA("StringValue") then
			-- StructureSequenceService reads "Available" for its Walls preview.
			record.status.Value = state == "Hidden" and "Locked" or state
		end

		local layoutMode = (state == "Purchased" and "Visible") or (state == "Available" and "Ghost") or "Hidden"
		if #record.layoutParts > 0 and layoutMode ~= record.layoutMode then
			record.layoutMode = layoutMode
			applyLayoutMode(record.layoutParts, layoutMode)
		end

		if state == "Hidden" then
			hideRecord(record)
			return
		end

		local pad = record.pad
		local accentColor = getAccentColor(plot)

		for _, part in ipairs(record.otherParts) do
			part.Transparency = part:GetAttribute("SolidTransparency") or 0
		end
		setGuiEnabled(record.areaTitle, state ~= "Purchased")
		for _, edge in ipairs(record.edges) do
			edge.Color = accentColor
			edge.Transparency = state == "Locked" and 0.38 or 0.08
		end

		if state == "Purchased" then
			pad.Transparency = 1
			pad.CanTouch = false
			setGuiEnabled(record.nameGui, false)
			setGuiEnabled(record.priceGui, false)
			if record.overlay then
				record.overlay.Transparency = 1
			end
			setGuiEnabled(record.lockDisplay, false)
			if record.zoneFloor then
				record.zoneFloor.Transparency = 0.18
			end
			if record.titleText then
				record.titleText.TextColor3 = accentColor
				record.titleText.TextTransparency = 0.04
			end
			return
		end

		setGuiEnabled(record.nameGui, true)
		setGuiEnabled(record.priceGui, true)
		pad.Material = Enum.Material.Neon
		pad.CanCollide = false

		if state == "Locked" then
			pad.Color = COLOR_LOCKED
			pad.Transparency = 0.72
			pad.CanTouch = false
			if record.priceText then
				record.priceText.Text = "LOCKED"
				record.priceText.TextColor3 = COLOR_LOCKED
			end
			if record.overlay then
				record.overlay.Color = COLOR_LOCKED
				record.overlay.Transparency = 0.78
			end
			setGuiEnabled(record.lockDisplay, true)
			if record.zoneFloor then
				record.zoneFloor.Transparency = 0.46
			end
			if record.titleText then
				record.titleText.TextColor3 = COLOR_LOCKED
				record.titleText.TextTransparency = 0.18
			end
			return
		end

		-- Available
		local cash = getCash(getOwnerPlayer(plot))
		local affordable = cash ~= nil and cash.Value >= record.price.Value
		local availableColor = affordable and COLOR_GREEN or COLOR_RED
		pad.Color = availableColor
		pad.Transparency = 0.42
		pad.CanTouch = not record.processing
		if record.priceText then
			record.priceText.Text = "$" .. tostring(record.price.Value)
			record.priceText.TextColor3 = availableColor
		end
		if record.overlay then
			record.overlay.Color = accentColor
			record.overlay.Transparency = 0.94
		end
		setGuiEnabled(record.lockDisplay, false)
		if record.zoneFloor then
			record.zoneFloor.Transparency = 0.26
		end
		if record.titleText then
			record.titleText.TextColor3 = accentColor
			record.titleText.TextTransparency = 0.08
		end
	end

	local function applyAll()
		for _, record in ipairs(records) do
			applyRecord(record)
		end
	end

	local function purchase(record, hit)
		if record.processing or record.activated.Value then
			return
		end
		local player = getPlayerFromHit(hit)
		if not player or getOwnerPlayer(plot) ~= player then
			return
		end
		if not requirementMet(record) then
			return
		end

		local price = record.price.Value
		local cash = getCash(player)
		if not cash or cash.Value < price then
			return
		end

		-- Lock before charging, so repeated touches cannot charge twice.
		record.processing = true
		cash.Value -= price
		record.activated.Value = true
		applyAll()

		PurchaseSoundModule.PlayPurchaseForTarget(player, record.pad)
		PurchaseEffectModule.Play(record.pad.Position + Vector3.new(0, 1.4, 0), {
			color = getAccentColor(plot),
			particleCount = 32,
		})

		task.delay(PURCHASE_COOLDOWN_SECONDS, function()
			record.processing = false
		end)
	end

	for _, record in ipairs(records) do
		record.pad.Touched:Connect(function(hit)
			purchase(record, hit)
		end)
		-- React at once to purchases, save restores and resets.
		record.activated.Changed:Connect(applyAll)
	end
	floorActivated.Changed:Connect(applyAll)

	applyAll()
	task.spawn(function()
		-- The poll also picks up cash changes (pad color) and cubicle purchases.
		while plot.Parent do
			task.wait(UPDATE_INTERVAL_SECONDS)
			applyAll()
		end
	end)
end

---------------------------------------------------------------------------
-- Startup: wait for SecondFloorService to finish each plot, then run it.
---------------------------------------------------------------------------

for _, plot in ipairs(Workspace:GetChildren()) do
	if plot:IsA("Model") and string.match(plot.Name, "^P%d+$") then
		task.spawn(function()
			while not plot:GetAttribute("SecondFloorBuilt") do
				plot:GetAttributeChangedSignal("SecondFloorBuilt"):Wait()
			end
			setupPlot(plot)
		end)
	end
end
