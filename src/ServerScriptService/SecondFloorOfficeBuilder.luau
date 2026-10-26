--[[
	SecondFloorOfficeBuilder
	Builds floor 2's office hierarchy, the "machine sections" after the
	cubicles, for one plot. Called by SecondFloorService while it builds the
	second floor; CubicleWorkstationService runs the purchases, upgrades,
	workers and income.

	Tiers (see SecondFloorConfig.OfficeTiers):
	  * Senior Workers   - bigger, cleaner cubicles: L-shaped desk, two monitors,
	                       glass-topped partitions, office chair.
	  * Team Lead        - a glass-walled meeting room: conference table, a team
	                       of seated workers, project-roadmap TV, whiteboard.
	  * Department Mgr   - a private office (one worker) with an executive desk
	                       piled with papers, bookshelves, guest chairs, plus a
	                       waiting lounge in front of it.

	Every unit has the same shape as a cubicle, so one service runs them all:
	  <Unit> (Model, attributes Order + Tier)
	    Activated / UpgradeLevel / Price / BaseIncomePerMinute / CycleSeconds
	    Geometry    - every visible part; starts hidden (ghost/solid set by the service)
	    WorkerSpots - invisible markers where workers spawn (pose, template, tag)
	    BuyPad / UpgradePad - copies of a first-floor dropper pad

	Coordinates below are unit-local: the buy button is at (0, 0, 0) on floor
	2's surface and +X points into the unit. Units only translate from the
	plot's Floor CFrame, so they are rotated correctly on all 10 plots.
]]

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ServerScriptService:WaitForChild("SecondFloorConfig"))

local Builder = {}

-- Palette: cleaner and brighter than the entry-level cubicles.
local WHITE = Color3.fromRGB(236, 236, 232)
local GREY = Color3.fromRGB(120, 124, 132)
local DARK = Color3.fromRGB(28, 29, 31)
local FRAME = Color3.fromRGB(55, 58, 64)
local OAK = Color3.fromRGB(205, 170, 125)
local WOOD = Color3.fromRGB(196, 150, 100)
local DARK_WOOD = Color3.fromRGB(96, 62, 38)
local CARPET = Color3.fromRGB(62, 74, 96)
local CARPET_LIGHT = Color3.fromRGB(96, 110, 130)
local RUG_RED = Color3.fromRGB(120, 30, 40)
local GLASS = Color3.fromRGB(180, 215, 235)
local PLANT = Color3.fromRGB(58, 140, 62)
local POT = Color3.fromRGB(190, 110, 70)
local PAPER = Color3.fromRGB(245, 245, 240)
local CREAM = Color3.fromRGB(240, 232, 205)
local MANILA = Color3.fromRGB(230, 200, 140)
local GOLD = Color3.fromRGB(212, 175, 55)
local LEATHER = Color3.fromRGB(60, 35, 25)
local SOFA = Color3.fromRGB(70, 80, 95)
local SCREEN_BLUE = Color3.fromRGB(40, 120, 200)

local GLASS_TRANSPARENCY = 0.55
local WALL_HEIGHT = 10

---------------------------------------------------------------------------
-- Part helpers
---------------------------------------------------------------------------

-- Anchored box between two corners of `frame`. It starts hidden; the service
-- reveals it. SolidTransparency / SolidCanCollide record its purchased look
-- (same convention as SecondFloorService.makeBox).
local function box(name, frame, cornerA, cornerB, color, material, parent)
	local low = Vector3.new(math.min(cornerA.X, cornerB.X), math.min(cornerA.Y, cornerB.Y), math.min(cornerA.Z, cornerB.Z))
	local high = Vector3.new(math.max(cornerA.X, cornerB.X), math.max(cornerA.Y, cornerB.Y), math.max(cornerA.Z, cornerB.Z))

	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = high - low
	part.CFrame = frame * CFrame.new((low + high) / 2)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part:SetAttribute("SolidTransparency", 0)
	part:SetAttribute("SolidCanCollide", true)
	part.Parent = parent
	return part
end

local function v(x, y, z)
	return Vector3.new(x, y, z)
end

-- A text panel on one face of a part. Starts disabled; the service shows it
-- only while the unit is purchased (text on a ghost looks wrong).
local function addSurfaceText(part, face, text, textColor, backgroundColor, backgroundTransparency)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OfficeText"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = backgroundColor or DARK
	label.BackgroundTransparency = backgroundTransparency or 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = textColor or WHITE
	label.Text = text
	label.Parent = gui
	return gui, label
end

-- Income/level label above a unit's screen, styled like the cubicles' label.
local function addIncomeLabel(screen, studsAbove)
	local incomeLabel = Instance.new("BillboardGui")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.Size = UDim2.new(0, 170, 0, 56)
	incomeLabel.StudsOffset = Vector3.new(0, studsAbove, 0)
	incomeLabel.MaxDistance = 90
	incomeLabel.LightInfluence = 0
	incomeLabel.Enabled = false
	incomeLabel.Parent = screen

	local function addText(name, yScale, heightScale, color)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 0, yScale, 0)
		label.Size = UDim2.new(1, 0, heightScale, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.Parent = incomeLabel
	end
	addText("IncomeText", 0, 0.55, Color3.fromRGB(255, 255, 255))
	addText("LevelText", 0.58, 0.42, Color3.fromRGB(0, 225, 255))
end

---------------------------------------------------------------------------
-- Unit scaffold
---------------------------------------------------------------------------

-- Creates one unit (values, folders, pads) and returns drawing helpers bound
-- to its frame, so the tier builders below only describe furniture.
local function newUnit(tier, index, frame, ctx)
	local unit = Instance.new("Model")
	unit.Name = tier.unitName .. index
	unit:SetAttribute("Order", index)
	unit:SetAttribute("Tier", tier.key)

	local function addValue(className, name, value)
		local valueObject = Instance.new(className)
		valueObject.Name = name
		valueObject.Value = value
		valueObject.Parent = unit
	end
	addValue("BoolValue", "Activated", false)
	addValue("IntValue", "UpgradeLevel", 1)
	addValue("IntValue", "Price", tier.price)
	addValue("NumberValue", "BaseIncomePerMinute", tier.baseIncomePerMinute)
	addValue("NumberValue", "CycleSeconds", tier.cycleSeconds)

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = unit

	local spots = Instance.new("Folder")
	spots.Name = "WorkerSpots"
	spots.Parent = unit

	-- Buy and upgrade pads: copies of a first-floor dropper pad, centred on the
	-- unit's origin. Only one is visible at a time (the service decides).
	local function makePad(name, labelText)
		local pad = ctx.padTemplate:Clone()
		for _, descendant in ipairs(pad:GetDescendants()) do
			if descendant:IsA("BaseScript") or descendant:IsA("ValueBase") then
				descendant:Destroy()
			end
		end
		pad.Name = name
		pad.CFrame = frame * CFrame.new(0, pad.Size.Y / 2, 0)
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanTouch = false
		pad.Transparency = 1
		pad.Material = Enum.Material.Neon
		if pad:IsA("UnionOperation") then
			pad.UsePartColor = true
		end
		for _, child in ipairs(pad:GetChildren()) do
			if child:IsA("BillboardGui") then
				child.Enabled = false
				if child.Name == "DropperLabel" then
					for _, label in ipairs(child:GetDescendants()) do
						if label:IsA("TextLabel") then
							label.Text = labelText
						end
					end
				end
			end
		end
		pad.Parent = unit
	end
	makePad("BuyPad", tier.label)
	makePad("UpgradePad", "Upgrade")

	local api = { unit = unit, frame = frame }

	function api.piece(name, cornerA, cornerB, color, material, collide)
		local part = box(name, frame, cornerA, cornerB, color, material, geometry)
		part:SetAttribute("SolidCanCollide", collide ~= false)
		return part
	end

	-- Plot-colored trim, recolored by PlotThemeService like the cubicles' trims.
	function api.accent(name, cornerA, cornerB)
		local part = api.piece(name, cornerA, cornerB, ctx.plotColor)
		CollectionService:AddTag(part, ctx.accentTag)
		return part
	end

	function api.glass(name, cornerA, cornerB)
		local part = api.piece(name, cornerA, cornerB, GLASS, Enum.Material.Glass)
		part:SetAttribute("SolidTransparency", GLASS_TRANSPARENCY)
		return part
	end

	-- A box rotated around Y about its own centre (papers, books).
	function api.tilted(name, center, size, yawDegrees, color, material)
		local part = box(name, frame, center - size / 2, center + size / 2, color, material, geometry)
		part.CFrame = frame * CFrame.new(center) * CFrame.Angles(0, math.rad(yawDegrees), 0)
		part:SetAttribute("SolidCanCollide", false)
		return part
	end

	function api.ball(name, center, diameter, color)
		local part = api.piece(name, center, center + Vector3.one * diameter, color, Enum.Material.Grass, false)
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * diameter
		part.CFrame = frame * CFrame.new(center)
		return part
	end

	-- Potted floor plant at unit-local (x, z).
	function api.plant(x, z, size)
		size = size or 1
		api.piece("PlantPot", v(x - 0.7 * size, 0, z - 0.7 * size), v(x + 0.7 * size, 1.4 * size, z + 0.7 * size), POT, nil, true)
		api.ball("PlantLeaves", v(x, 2.4 * size, z), 2.2 * size, PLANT)
		api.ball("PlantLeavesTop", v(x, 3.4 * size, z), 1.5 * size, PLANT)
	end

	-- Office chair whose occupant's root sits at unit-local `position`, facing
	-- `direction`. In the chair's own frame, forward is -Z (CFrame.lookAt).
	function api.chair(position, direction, executive)
		local chairFrame = frame * CFrame.lookAt(position, position + direction)
		local seatTop = Config.SeatHeight
		local color = executive and LEATHER or DARK
		local function chairPiece(name, a, b, partColor)
			local part = box(name, chairFrame, a, b, partColor or color, nil, geometry)
			part:SetAttribute("SolidCanCollide", false) -- workers sit through it
			return part
		end
		chairPiece("ChairSeat", v(-0.95, seatTop - 0.3, -1.25), v(0.95, seatTop, 0.55))
		chairPiece("ChairBack", v(-0.95, seatTop, 0.55), v(0.95, seatTop + (executive and 3.6 or 2.4), 0.8))
		chairPiece("ChairPole", v(-0.15, 0.25, -0.5), v(0.15, seatTop - 0.3, -0.2), GREY)
		chairPiece("ChairBase", v(-0.9, 0, -1.25), v(0.9, 0.25, 0.45), GREY)
	end

	-- Where a worker spawns. The marker is invisible and never collides.
	function api.spot(position, direction, pose, templateName, tag)
		local marker = Instance.new("Part")
		marker.Name = "WorkerSpot"
		marker.Size = Vector3.new(1, 0.2, 1)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
		marker.CastShadow = false
		marker.Transparency = 1
		marker.CFrame = frame * CFrame.lookAt(position, position + direction)
		marker:SetAttribute("Pose", pose) -- "Sit" or "Stand"
		marker:SetAttribute("SeatHeight", Config.SeatHeight)
		marker:SetAttribute("Template", templateName)
		marker:SetAttribute("Tag", tag)
		marker.Parent = spots
		return marker
	end

	function api.screen(name, cornerA, cornerB, studsAbove)
		local screen = api.piece(name or "Screen", cornerA, cornerB, Config.CubicleLevels[1].screenColor, Enum.Material.Neon, false)
		addIncomeLabel(screen, studsAbove)
		return screen
	end

	-- Door sign facing the aisle (-X), above a doorway in the x = 2 wall.
	function api.doorSign(text, halfWidth)
		local sign = api.piece("DoorSign", v(1.6, WALL_HEIGHT + 0.4, -halfWidth), v(2.0, WALL_HEIGHT + 2.4, halfWidth), FRAME)
		addSurfaceText(sign, Enum.NormalId.Left, text, WHITE)
		api.accent("DoorSignTrim", v(1.55, WALL_HEIGHT + 2.4, -halfWidth), v(2.05, WALL_HEIGHT + 2.6, halfWidth))
		return sign
	end

	return api
end

-- A wall along X or Z made of glass panels between frame posts, with an
-- optional doorway gap. `axis` is "Z" for a wall running along Z at fixed x
-- (x0..x1 thickness), or "X" for one running along X at fixed z.
local function glassWall(api, axis, fixedMin, fixedMax, from, to, postSpacing, doorFrom, doorTo, lowerPanelHeight, lowerColor)
	local function corners(a, b, y0, y1)
		if axis == "Z" then
			return v(fixedMin, y0, a), v(fixedMax, y1, b)
		end
		return v(a, y0, fixedMin), v(b, y1, fixedMax)
	end

	-- Posts at every spacing step and at both ends of the doorway.
	local postPositions = {}
	local position = from
	while position < to - 0.01 do
		table.insert(postPositions, position)
		position += postSpacing
	end
	table.insert(postPositions, to)
	if doorFrom then
		table.insert(postPositions, doorFrom)
		table.insert(postPositions, doorTo)
	end
	for _, p in ipairs(postPositions) do
		local a, b = corners(p - 0.2, p + 0.2, 0, WALL_HEIGHT)
		api.piece("WallPost", a, b, FRAME)
	end

	-- Panels: lower solid band (optional) + glass, skipping the doorway.
	local function panel(a, b)
		local glassFrom = 0
		if lowerPanelHeight then
			local la, lb = corners(a, b, 0, lowerPanelHeight)
			api.piece("WallLower", la, lb, lowerColor or FRAME)
			glassFrom = lowerPanelHeight
		end
		local ga, gb = corners(a, b, glassFrom, WALL_HEIGHT - 0.6)
		api.glass("WallGlass", ga, gb)
		local ta, tb = corners(a, b, WALL_HEIGHT - 0.6, WALL_HEIGHT)
		api.piece("WallHeader", ta, tb, FRAME)
	end
	if doorFrom then
		panel(from, doorFrom)
		panel(doorTo, to)
		local ha, hb = corners(doorFrom, doorTo, WALL_HEIGHT - 2, WALL_HEIGHT)
		api.piece("DoorHeader", ha, hb, FRAME)
	else
		panel(from, to)
	end

	-- Plot-colored cap along the whole top.
	local ca, cb = corners(from - 0.2, to + 0.2, WALL_HEIGHT, WALL_HEIGHT + 0.3)
	api.accent("WallCap", ca, cb)
end

---------------------------------------------------------------------------
-- Senior Worker cubicle (one per unit)
---------------------------------------------------------------------------

local function buildSenior(api, _index, tier)
	local piece, glass, accent = api.piece, api.glass, api.accent

	-- Floor and glass-topped partitions (back + two sides).
	piece("Carpet", v(2.4, 0, -5.8), v(11.6, 0.06, 5.8), CARPET_LIGHT, Enum.Material.Fabric, false)
	piece("PartitionBack", v(11.2, 0, -5.8), v(11.6, 5, 5.8), WHITE)
	glass("PartitionBackGlass", v(11.2, 5, -5.8), v(11.6, 6.6, 5.8))
	accent("TrimBack", v(11.15, 6.6, -5.85), v(11.65, 6.85, 5.85))
	for _, side in ipairs({ -1, 1 }) do
		local inner, outer = side * 5.4, side * 5.8
		piece("PartitionSide", v(2.4, 0, inner), v(11.2, 5, outer), WHITE)
		glass("PartitionSideGlass", v(2.4, 5, inner), v(11.2, 6.6, outer))
		accent("TrimSide", v(2.35, 6.6, inner), v(11.2, 6.85, outer))
	end

	-- L-shaped desk: main desk along the back, return on the right.
	piece("DeskTop", v(7.4, 2.4, -5.2), v(10.4, 2.6, 5.2), OAK)
	piece("DeskBack", v(10.2, 0, -5.2), v(10.4, 2.4, 5.2), GREY)
	piece("DeskLegLeft", v(7.4, 0, -5.2), v(10.4, 2.4, -5.0), GREY)
	piece("DeskLegRight", v(7.4, 0, 5.0), v(10.4, 2.4, 5.2), GREY)
	piece("ReturnTop", v(4.0, 2.4, 3.4), v(7.4, 2.6, 5.2), OAK)
	piece("ReturnDrawers", v(4.0, 0, 3.4), v(5.6, 2.4, 5.2), GREY)

	-- Two monitors; the left one shows the level color and carries the label.
	piece("MonitorLeft", v(9.5, 2.95, -3.4), v(9.75, 5.0, -0.4), DARK, nil, false)
	api.screen("Screen", v(9.45, 3.05, -3.3), v(9.5, 4.9, -0.5), 2.6)
	piece("MonitorRight", v(9.5, 2.95, 0.4), v(9.75, 5.0, 3.4), DARK, nil, false)
	piece("ScreenRight", v(9.45, 3.05, 0.5), v(9.5, 4.9, 3.3), SCREEN_BLUE, Enum.Material.Neon, false)
	piece("MonitorStandLeft", v(9.55, 2.6, -2.0), v(9.75, 2.95, -1.8), DARK, nil, false)
	piece("MonitorStandRight", v(9.55, 2.6, 1.8), v(9.75, 2.95, 2.0), DARK, nil, false)
	piece("Keyboard", v(8.0, 2.6, -1.1), v(8.6, 2.68, 1.1), DARK, nil, false)
	piece("Mouse", v(8.2, 2.6, 1.5), v(8.5, 2.66, 1.8), DARK, nil, false)
	piece("Mug", v(8.9, 2.6, 3.9), v(9.2, 2.95, 4.2), WHITE, nil, false)

	-- Small desk plant on the return.
	piece("DeskPlantPot", v(5.8, 2.6, 4.0), v(6.4, 3.1, 4.6), POT, nil, false)
	api.ball("DeskPlantLeaves", v(6.1, 3.5, 4.3), 1.0, PLANT)

	local seat = v(6.3, 0, 0)
	api.chair(seat, Vector3.xAxis)
	api.spot(seat, Vector3.xAxis, "Sit", tier.workerTemplate, Config.TypingWorkerTag)
end

---------------------------------------------------------------------------
-- Team Lead meeting room (one unit)
-- Room: x 2..39, z -24..24. Door in the aisle-side wall (x = 2) at z -3..3.
---------------------------------------------------------------------------

local function buildMeetingRoom(api, _index, tier)
	local piece = api.piece

	piece("Carpet", v(2, 0, -24), v(39, 0.06, 24), CARPET, Enum.Material.Fabric, false)

	-- Walls: glass on the aisle side and both ends, solid at the back.
	glassWall(api, "Z", 2, 2.4, -24, 24, 7, -3, 3)
	glassWall(api, "X", -24, -23.6, 2, 39, 7)
	glassWall(api, "X", 23.6, 24, 2, 39, 7)
	piece("BackWall", v(38.6, 0, -23.6), v(39, WALL_HEIGHT, 23.6), WHITE)
	api.doorSign("TEAM LEAD - MEETING ROOM", 7)

	-- Conference table on two pedestals.
	piece("TableTop", v(16, 2.4, -13), v(24, 2.6, 13), DARK_WOOD)
	piece("TableEdge", v(15.9, 2.35, -13.1), v(24.1, 2.42, 13.1), FRAME, nil, false)
	piece("TableBaseNorth", v(19, 0, -9), v(21, 2.4, -7), FRAME)
	piece("TableBaseSouth", v(19, 0, 7), v(21, 2.4, 9), FRAME)

	-- Chairs: four per side plus the head of the table (facing the TV).
	local seats = {}
	for _, z in ipairs({ -9, -3, 3, 9 }) do
		table.insert(seats, { position = v(14.9, 0, z), direction = Vector3.xAxis })
		table.insert(seats, { position = v(25.1, 0, z), direction = -Vector3.xAxis })
	end
	local head = { position = v(20, 0, -15.3), direction = Vector3.zAxis }
	table.insert(seats, head)
	for _, seat in ipairs(seats) do
		api.chair(seat.position, seat.direction, seat == head)
	end

	-- Who sits where: the team lead at the head, the team spread around.
	local occupied = {
		head,
		{ position = v(14.9, 0, -3), direction = Vector3.xAxis },
		{ position = v(25.1, 0, 3), direction = -Vector3.xAxis },
		{ position = v(14.9, 0, 9), direction = Vector3.xAxis },
		{ position = v(25.1, 0, -9), direction = -Vector3.xAxis },
	}
	local templates = tier.workerTemplates or {}
	for i, seat in ipairs(occupied) do
		local template = templates[i] or Config.WorkerTemplateName
		api.spot(seat.position, seat.direction, "Sit", template, Config.TalkingWorkerTag)
	end

	-- Presentation TV on the far wall, facing the room (-Z). Its border glows
	-- in the level color; the roadmap is drawn on top.
	piece("TVBacking", v(12, 2.5, 23.0), v(28, 10, 23.5), DARK)
	local screen = api.screen("Screen", v(12.4, 2.9, 22.9), v(27.6, 9.6, 23.0), 4.4)
	local tvGui = addSurfaceText(screen, Enum.NormalId.Front, "", WHITE)
	local tvText = tvGui:FindFirstChild("Text")
	tvText.Size = UDim2.fromScale(0.94, 0.9)
	tvText.Position = UDim2.fromScale(0.03, 0.05)
	tvText.BackgroundTransparency = 0
	tvText.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
	tvText.TextScaled = false
	tvText.TextSize = 28
	tvText.TextYAlignment = Enum.TextYAlignment.Top
	tvText.Text = "\nQ4 PROJECT ROADMAP"
	for i, bar in ipairs({ { 0.78, Color3.fromRGB(40, 225, 80) }, { 0.55, Color3.fromRGB(45, 165, 255) }, { 0.32, Color3.fromRGB(255, 145, 35) } }) do
		local fill = Instance.new("Frame")
		fill.Name = "Bar" .. i
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = bar[2]
		fill.Position = UDim2.fromScale(0.08, 0.3 + i * 0.16)
		fill.Size = UDim2.fromScale(0.84 * bar[1], 0.09)
		fill.Parent = tvText
	end

	-- Whiteboard on the back wall, facing the room (-X).
	local board = piece("Whiteboard", v(38.3, 3, -10), v(38.6, 8, 10), WHITE)
	addSurfaceText(board, Enum.NormalId.Left, "SPRINT GOALS\n[x] Ship Ball v2\n[x] Hire seniors\n[ ] Beat Q4 target", Color3.fromRGB(30, 60, 160))
	piece("WhiteboardTray", v(38.0, 2.9, -10), v(38.6, 3.05, 10), GREY, nil, false)

	-- Coffee credenza and plants.
	piece("Credenza", v(35, 0, 12), v(38.3, 2.8, 22), DARK_WOOD)
	piece("CoffeeMachine", v(36, 2.8, 19.5), v(37.6, 4.4, 21), DARK, nil, false)
	piece("Cup", v(36.2, 2.8, 17.5), v(36.6, 3.2, 17.9), WHITE, nil, false)
	api.plant(5, -21)
	api.plant(5, 21)
	api.plant(36, -21)
end

---------------------------------------------------------------------------
-- Department Manager office (one unit, one worker) + waiting lounge
-- Office: x 2..39, z -26..26, door at z -3..3. Lounge: z -74..-30.
---------------------------------------------------------------------------

local function buildPaperStacks(api)
	-- Deterministic "messy" stacks: each sheet twisted a little differently.
	local stacks = {
		{ x = 27.2, z = -4.2, count = 9 },
		{ x = 28.4, z = -3.6, count = 6 },
		{ x = 26.4, z = -2.0, count = 12 },
		{ x = 27.6, z = 4.8, count = 7 },
		{ x = 26.3, z = 3.2, count = 4 },
	}
	local sheetSize = Vector3.new(1.3, 0.07, 1.8)
	for stackIndex, stack in ipairs(stacks) do
		for sheet = 1, stack.count do
			local wobble = math.sin(stackIndex * 12.9898 + sheet * 78.233) * 12
			local color = PAPER
			if sheet % 4 == 0 then
				color = MANILA -- a folder every few sheets
			elseif sheet % 2 == 0 then
				color = CREAM
			end
			local center = v(stack.x, 2.6 + (sheet - 0.5) * sheetSize.Y, stack.z)
			api.tilted("Paper", center, sheetSize, wobble, color)
		end
	end
end

local function buildBookshelf(api, zFrom, zTo)
	local piece = api.piece
	piece("ShelfSideA", v(36.6, 0, zFrom), v(38.6, 8, zFrom + 0.3), DARK_WOOD)
	piece("ShelfSideB", v(36.6, 0, zTo - 0.3), v(38.6, 8, zTo), DARK_WOOD)
	piece("ShelfBack", v(38.4, 0, zFrom), v(38.6, 8, zTo), DARK_WOOD)
	local bookColors = {
		Color3.fromRGB(150, 40, 40), Color3.fromRGB(40, 70, 140), Color3.fromRGB(40, 110, 60),
		Color3.fromRGB(200, 160, 60), Color3.fromRGB(90, 50, 110), Color3.fromRGB(30, 30, 30),
	}
	for shelf = 0, 3 do
		local y = shelf * 2
		piece("Shelf", v(36.6, y, zFrom), v(38.6, y + 0.2, zTo), DARK_WOOD, nil, false)
		-- Books: varied heights and widths across the shelf.
		local z = zFrom + 0.4
		local book = 0
		while z < zTo - 0.9 do
			book += 1
			local width = 0.35 + ((book * 7 + shelf * 3) % 4) * 0.12
			local height = 1.1 + ((book * 5 + shelf) % 3) * 0.2
			piece("Book", v(36.9, y + 0.2, z), v(38.3, y + 0.2 + height, z + width), bookColors[(book + shelf) % #bookColors + 1], nil, false)
			z += width + 0.05
		end
	end
end

local function buildManagerOffice(api, _index, tier)
	local piece = api.piece

	-- Office shell: wood floor, glass front with a wood lower band, solid sides.
	piece("Floor", v(2, 0, -26), v(39, 0.06, 26), WOOD, Enum.Material.WoodPlanks, false)
	glassWall(api, "Z", 2, 2.4, -26, 26, 7, -3, 3, 3.5, DARK_WOOD)
	for _, side in ipairs({ -1, 1 }) do
		local inner, outer = side * 25.6, side * 26
		piece("SideWall", v(2.4, 0, inner), v(39, WALL_HEIGHT, outer), WHITE)
		piece("SideWainscot", v(2.4, 0, side * 25.5), v(39, 3.5, inner), DARK_WOOD, nil, false)
		api.accent("SideWallCap", v(2.4, WALL_HEIGHT, inner), v(39, WALL_HEIGHT + 0.3, outer))
	end
	piece("BackWall", v(38.6, 0, -25.6), v(39, WALL_HEIGHT, 25.6), WHITE)
	api.doorSign("DEPARTMENT MANAGER", 6)
	piece("Rug", v(14, 0.06, -10), v(34, 0.1, 10), RUG_RED, Enum.Material.Fabric, false)

	-- Executive desk facing the door; the manager sits behind it (x = 31).
	piece("DeskTop", v(25, 2.4, -6), v(29.6, 2.6, 6), DARK_WOOD)
	piece("DeskFront", v(25, 0, -6), v(25.4, 2.4, 6), DARK_WOOD)
	piece("DeskSideA", v(25, 0, -6), v(29.6, 2.4, -5.6), DARK_WOOD)
	piece("DeskSideB", v(25, 0, 5.6), v(29.6, 2.4, 6), DARK_WOOD)
	local nameplate = piece("Nameplate", v(24.85, 1.2, -2.5), v(25, 2.0, 2.5), GOLD, Enum.Material.Metal, false)
	addSurfaceText(nameplate, Enum.NormalId.Left, "DEPT. MANAGER", DARK)

	-- Monitor facing the manager (+X); its screen shows the level color.
	piece("Monitor", v(26.2, 3.0, 1.0), v(26.45, 5.2, 4.4), DARK, nil, false)
	api.screen("Screen", v(26.45, 3.1, 1.1), v(26.5, 5.1, 4.3), 2.8)
	piece("MonitorStand", v(26.2, 2.6, 2.6), v(26.45, 3.0, 2.8), DARK, nil, false)
	piece("Keyboard", v(28.8, 2.6, -1.0), v(29.4, 2.68, 1.0), DARK, nil, false)
	piece("DeskLampBase", v(26.0, 2.6, -5.5), v(26.6, 2.75, -4.9), GOLD, Enum.Material.Metal, false)
	piece("DeskLampShade", v(25.9, 3.9, -5.6), v(26.7, 4.4, -4.8), Color3.fromRGB(40, 90, 50), nil, false)
	piece("DeskLampPole", v(26.25, 2.75, -5.25), v(26.35, 3.9, -5.15), GOLD, Enum.Material.Metal, false)
	piece("Mug", v(28.6, 2.6, 4.0), v(28.95, 2.95, 4.35), WHITE, nil, false)
	buildPaperStacks(api)

	local seat = v(31, 0, 0)
	api.chair(seat, -Vector3.xAxis, true)
	api.spot(seat, -Vector3.xAxis, "Sit", tier.workerTemplate, Config.TypingWorkerTag)

	-- Guest chairs, bookshelves, filing cabinet, plants.
	api.chair(v(21.5, 0, -3), Vector3.xAxis)
	api.chair(v(21.5, 0, 3), Vector3.xAxis)
	buildBookshelf(api, -20, -8)
	buildBookshelf(api, 8, 20)
	piece("FilingCabinet", v(35.6, 0, -25.4), v(38.4, 4.2, -22.6), GREY, Enum.Material.Metal)
	for _, y in ipairs({ 1.2, 2.6, 4.0 }) do
		piece("CabinetHandle", v(35.5, y - 0.15, -24.3), v(35.6, y, -23.7), DARK, Enum.Material.Metal, false)
	end
	api.plant(5, -23)
	api.plant(5, 23)
	api.plant(35, 23.5)

	-- Waiting lounge in front of the office.
	piece("LoungeRug", v(10, 0.06, -64), v(30, 0.1, -40), CARPET, Enum.Material.Fabric, false)
	for _, sofa in ipairs({ { x0 = 10.5, back = 10.5, dir = 1 }, { x0 = 26.5, back = 28.7, dir = -1 } }) do
		local x1 = sofa.x0 + 3
		piece("SofaBase", v(sofa.x0, 0, -60), v(x1, 1.6, -44), SOFA, Enum.Material.Fabric)
		piece("SofaBack", v(sofa.back, 1.6, -60), v(sofa.back + 0.8, 3.6, -44), SOFA, Enum.Material.Fabric)
		piece("SofaArmA", v(sofa.x0, 1.6, -60), v(x1, 2.6, -59.2), SOFA, Enum.Material.Fabric)
		piece("SofaArmB", v(sofa.x0, 1.6, -44.8), v(x1, 2.6, -44), SOFA, Enum.Material.Fabric)
	end
	piece("CoffeeTableTop", v(17, 1.2, -56), v(23, 1.4, -48), DARK_WOOD)
	piece("CoffeeTableLegs", v(18, 0, -55), v(22, 1.2, -49), FRAME)
	api.tilted("Magazine", v(19, 1.45, -53), Vector3.new(1.2, 0.08, 1.6), 15, Color3.fromRGB(200, 60, 60))
	api.tilted("Magazine", v(20.6, 1.45, -51), Vector3.new(1.2, 0.08, 1.6), -10, Color3.fromRGB(60, 120, 200))
	piece("WaterCoolerBody", v(35, 0, -53), v(36.4, 3.4, -51.6), WHITE)
	local jug = piece("WaterCoolerJug", v(35.1, 3.4, -52.9), v(36.3, 5.0, -51.7), Color3.fromRGB(120, 200, 255), Enum.Material.Glass, false)
	jug:SetAttribute("SolidTransparency", 0.3)
	piece("FloorLampPole", v(8.4, 0, -63.4), v(8.6, 6, -63.2), GOLD, Enum.Material.Metal, false)
	piece("FloorLampShade", v(7.8, 6, -64), v(9.2, 7.2, -62.6), CREAM, Enum.Material.Fabric, false)
	api.plant(6, -72)
	api.plant(6, -32)
	api.plant(36, -72)
	api.plant(36, -32)
end

local TIER_BUILDERS = {
	Senior = buildSenior,
	TeamLead = buildMeetingRoom,
	Manager = buildManagerOffice,
}

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

--[[
	Builds every tier in Config.OfficeTiers into `secondFloor`.
	ctx = {
		plot, floorTop (CFrame at floor 1's surface), storey (number),
		plotColor (Color3), accentTag (string), padTemplate (BasePart),
		secondFloor (Model)
	}
]]
function Builder.Build(ctx)
	for _, tier in ipairs(Config.OfficeTiers) do
		local buildUnit = TIER_BUILDERS[tier.key]
		if not buildUnit then
			warn("[SecondFloorOfficeBuilder] No builder for tier " .. tostring(tier.key))
			continue
		end

		local folder = Instance.new("Folder")
		folder.Name = tier.folder
		folder.Parent = ctx.secondFloor

		for index, position in ipairs(tier.positions) do
			local frame = ctx.floorTop * CFrame.new(position.X, ctx.storey, position.Z)
			local api = newUnit(tier, index, frame, ctx)
			buildUnit(api, index, tier)
			api.unit.Parent = folder
		end
	end
end

return Builder
