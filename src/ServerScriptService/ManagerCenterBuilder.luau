--[[
	ManagerCenterBuilder
	Builds floor 2's Manager Center (the floor-2 copy of the Worker Centre) for
	one plot. Called by SecondFloorService while it builds the second floor;
	ManagerCenterService runs the purchases and supervisors, and
	SecondFloorCentreService shows the building (hidden / ghost / solid) with
	the rest of the centre.

	Adds to <SecondFloor>/CentreSlots/Centre01_Worker:
	  Layout              - the office building and the training sign. Every part
	                        records its purchased look (SolidTransparency,
	                        SolidCanCollide) and starts hidden.
	  WorkerActivations   - one BoolValue per supervisor (Config.SupervisorStages).
	                        TycoonProgressService already saves any BoolValue in a
	                        folder with this name, so purchases save per player.
	  Upgrades
	    SupervisorBuyPad  - copy of floor 1's worker buy pad, same spot.
	    ProductivityTraining
	      BuyPad          - copy of floor 1's Worker Speed pad, same spot.
	      UpgradeLevel    - saved like every other UpgradeLevel.
	  Supervisors         - empty; ManagerCenterService puts supervisors here.

	Positions are plot-local (SecondFloorConfig); every part is placed from the
	plot's Floor CFrame, so it is rotated correctly on all 10 plots.
]]

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ServerScriptService:WaitForChild("SecondFloorConfig"))

local Builder = {}

local WHITE = Color3.fromRGB(236, 236, 232)
local FRAME = Color3.fromRGB(55, 58, 64)
local DARK = Color3.fromRGB(28, 29, 31)
local GREY = Color3.fromRGB(120, 124, 132)
local CARPET = Color3.fromRGB(70, 80, 100)
local DARK_WOOD = Color3.fromRGB(96, 62, 38)
local GLASS = Color3.fromRGB(180, 215, 235)
local PLANT = Color3.fromRGB(58, 140, 62)
local POT = Color3.fromRGB(190, 110, 70)
local SOFA = Color3.fromRGB(70, 80, 95)
local LIGHT_PANEL = Color3.fromRGB(255, 250, 235)

local GLASS_TRANSPARENCY = 0.55
local HEIGHT = 12

-- Building footprint (plot-local). The front faces the aisle (+X), with the
-- door lined up on the supervisor pad.
local X_BACK, X_FRONT = -68, -27
local Z_LEFT, Z_RIGHT = -142, -95

local function v(x, y, z)
	return Vector3.new(x, y, z)
end

---------------------------------------------------------------------------
-- Part helpers (everything goes in the Layout folder, hidden at first)
---------------------------------------------------------------------------

local function newPartMaker(frame, parent, plotColor, accentTag)
	local make = {}

	function make.box(name, cornerA, cornerB, color, material, collide)
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
		part.CanQuery = false
		part.CastShadow = false
		-- Read by SecondFloorCentreService when it shows the building.
		part:SetAttribute("SolidTransparency", 0)
		part:SetAttribute("SolidCanCollide", collide ~= false)
		part:SetAttribute("LayoutCollision", false)
		part.Parent = parent
		return part
	end

	function make.glass(name, cornerA, cornerB)
		local part = make.box(name, cornerA, cornerB, GLASS, Enum.Material.Glass)
		part:SetAttribute("SolidTransparency", GLASS_TRANSPARENCY)
		return part
	end

	-- Plot-colored trim, recolored by PlotThemeService.
	function make.accent(name, cornerA, cornerB, collide)
		local part = make.box(name, cornerA, cornerB, plotColor, nil, collide)
		CollectionService:AddTag(part, accentTag)
		return part
	end

	function make.ball(name, center, diameter, color)
		local part = make.box(name, center, center + Vector3.one, color, Enum.Material.Grass, false)
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * diameter
		part.CFrame = frame * CFrame.new(center)
		return part
	end

	function make.plant(x, z)
		make.box("PlantPot", v(x - 0.7, 0, z - 0.7), v(x + 0.7, 1.4, z + 0.7), POT)
		make.ball("PlantLeaves", v(x, 2.4, z), 2.2, PLANT)
		make.ball("PlantLeavesTop", v(x, 3.4, z), 1.5, PLANT)
	end

	-- Text on one face of a part; only shown while the centre is bought.
	function make.text(part, face, text, textColor)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "LayoutText"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Enabled = false
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextWrapped = true
		label.TextColor3 = textColor or WHITE
		label.Text = text
		label.Parent = gui
		return label
	end

	return make
end

---------------------------------------------------------------------------
-- The building
---------------------------------------------------------------------------

-- A wall of glass panels between posts, with an optional lower solid band and
-- doorway. axis "Z": runs along Z at x0..x1; axis "X": runs along X at z0..z1.
local function glassWall(make, axis, fixedMin, fixedMax, from, to, spacing, lowerHeight, doorFrom, doorTo)
	local function corners(a, b, y0, y1)
		if axis == "Z" then
			return v(fixedMin, y0, a), v(fixedMax, y1, b)
		end
		return v(a, y0, fixedMin), v(b, y1, fixedMax)
	end

	local posts = {}
	local position = from
	while position < to - 0.01 do
		table.insert(posts, position)
		position += spacing
	end
	table.insert(posts, to)
	if doorFrom then
		table.insert(posts, doorFrom)
		table.insert(posts, doorTo)
	end
	for _, p in ipairs(posts) do
		local a, b = corners(p - 0.25, p + 0.25, 0, HEIGHT)
		make.box("WallPost", a, b, FRAME)
	end

	local function panel(a, b)
		local glassFrom = 0
		if lowerHeight then
			local la, lb = corners(a, b, 0, lowerHeight)
			make.box("WallLower", la, lb, WHITE)
			glassFrom = lowerHeight
		end
		local ga, gb = corners(a, b, glassFrom, HEIGHT - 0.6)
		make.glass("WallGlass", ga, gb)
		local ha, hb = corners(a, b, HEIGHT - 0.6, HEIGHT)
		make.box("WallHeader", ha, hb, FRAME)
	end
	if doorFrom then
		panel(from, doorFrom)
		panel(doorTo, to)
		local da, db = corners(doorFrom, doorTo, HEIGHT - 3, HEIGHT)
		make.box("DoorHeader", da, db, FRAME)
	else
		panel(from, to)
	end
end

local function buildBuilding(make)
	local doorZ = Config.SupervisorPadPosition.Z
	local doorFrom, doorTo = doorZ - 3.4, doorZ + 3.4

	-- Floor and walls.
	make.box("Carpet", v(X_BACK, 0, Z_LEFT), v(X_FRONT, 0.06, Z_RIGHT), CARPET, Enum.Material.Fabric, false)
	make.box("BackWall", v(X_BACK, 0, Z_LEFT), v(X_BACK + 0.4, HEIGHT, Z_RIGHT), WHITE)
	glassWall(make, "X", Z_LEFT, Z_LEFT + 0.4, X_BACK + 0.4, X_FRONT, 7, 4)
	glassWall(make, "X", Z_RIGHT - 0.4, Z_RIGHT, X_BACK + 0.4, X_FRONT, 7, 4)
	glassWall(make, "Z", X_FRONT - 0.4, X_FRONT, Z_LEFT + 0.4, Z_RIGHT - 0.4, 6, nil, doorFrom, doorTo)

	-- Flat roof with a plot-colored rim.
	make.box("Roof", v(X_BACK - 0.4, HEIGHT, Z_LEFT - 0.4), v(X_FRONT + 0.4, HEIGHT + 0.6, Z_RIGHT + 0.4), FRAME)
	make.accent("RoofRimFront", v(X_FRONT, HEIGHT + 0.6, Z_LEFT - 0.4), v(X_FRONT + 0.4, HEIGHT + 1.1, Z_RIGHT + 0.4))
	make.accent("RoofRimBack", v(X_BACK - 0.4, HEIGHT + 0.6, Z_LEFT - 0.4), v(X_BACK, HEIGHT + 1.1, Z_RIGHT + 0.4))
	make.accent("RoofRimLeft", v(X_BACK, HEIGHT + 0.6, Z_LEFT - 0.4), v(X_FRONT, HEIGHT + 1.1, Z_LEFT))
	make.accent("RoofRimRight", v(X_BACK, HEIGHT + 0.6, Z_RIGHT), v(X_FRONT, HEIGHT + 1.1, Z_RIGHT + 0.4))

	-- Entrance canopy and the building sign, facing the aisle.
	make.box("Canopy", v(X_FRONT, HEIGHT - 2, doorFrom - 3), v(X_FRONT + 3.2, HEIGHT - 1.6, doorTo + 3), FRAME)
	make.accent("CanopyEdge", v(X_FRONT + 3.2, HEIGHT - 2.1, doorFrom - 3), v(X_FRONT + 3.5, HEIGHT - 1.5, doorTo + 3))
	local sign = make.box("BuildingSign", v(X_FRONT + 3.1, HEIGHT - 1.5, doorFrom - 6), v(X_FRONT + 3.4, HEIGHT + 0.9, doorTo + 6), DARK)
	make.text(sign, Enum.NormalId.Right, string.upper(Config.ManagerCenterName), WHITE)

	-- Ceiling light panels.
	for _, z in ipairs({ -134, -118.4, -103 }) do
		for _, x in ipairs({ -58, -40 }) do
			make.box("CeilingLight", v(x - 3, HEIGHT - 0.25, z - 2), v(x + 3, HEIGHT - 0.05, z + 2), LIGHT_PANEL, Enum.Material.Neon, false)
		end
	end

	-- Reception desk facing the door, with a plot-colored stripe.
	make.box("ReceptionDesk", v(-45, 0, doorZ - 6), v(-42, 3.4, doorZ + 6), WHITE)
	make.box("ReceptionTop", v(-45.3, 3.4, doorZ - 6.3), v(-41.7, 3.6, doorZ + 6.3), DARK_WOOD)
	make.accent("ReceptionStripe", v(-41.75, 1.2, doorZ - 6), v(-41.65, 1.7, doorZ + 6), false)
	make.box("ReceptionMonitor", v(-44.2, 3.6, doorZ + 1), v(-43.95, 5.4, doorZ + 3.6), DARK, nil, false)

	-- Org chart on the back wall, facing the door.
	local board = make.box("OrgChart", v(X_BACK + 0.4, 3, doorZ - 10), v(X_BACK + 0.7, 9, doorZ + 10), WHITE)
	local ranks = {}
	for i = #Config.SupervisorStages, 1, -1 do
		local name = Config.SupervisorStages[i].displayName
		if not table.find(ranks, name) then
			table.insert(ranks, name)
		end
	end
	make.text(board, Enum.NormalId.Right, "ORG CHART\n" .. table.concat(ranks, "\n"), Color3.fromRGB(30, 60, 160))
	make.accent("OrgChartFrame", v(X_BACK + 0.4, 9, doorZ - 10.2), v(X_BACK + 0.8, 9.3, doorZ + 10.2), false)

	-- Lounge on the left: sofas around a coffee table.
	make.box("SofaA", v(-64, 0, -139), v(-61, 1.6, -129), SOFA, Enum.Material.Fabric)
	make.box("SofaABack", v(-64, 1.6, -139), v(-63.2, 3.6, -129), SOFA, Enum.Material.Fabric)
	make.box("SofaB", v(-58, 0, -140.6), v(-48, 1.6, -137.6), SOFA, Enum.Material.Fabric)
	make.box("SofaBBack", v(-58, 1.6, -140.6), v(-48, 3.6, -139.8), SOFA, Enum.Material.Fabric)
	make.box("CoffeeTable", v(-58, 1.2, -135), v(-52, 1.4, -130), DARK_WOOD)
	make.box("CoffeeTableBase", v(-56.5, 0, -133.8), v(-53.5, 1.2, -131.2), FRAME)

	-- Two executive desks on the right.
	for _, z in ipairs({ -104, -99 }) do
		make.box("ExecDesk", v(-60, 2.4, z - 1.6), v(-54, 2.6, z + 1.6), DARK_WOOD)
		make.box("ExecDeskBase", v(-59.6, 0, z - 1.4), v(-58.6, 2.4, z + 1.4), DARK_WOOD)
		make.box("ExecDeskBase", v(-55.4, 0, z - 1.4), v(-54.4, 2.4, z + 1.4), DARK_WOOD)
		make.box("ExecMonitor", v(-58.4, 2.6, z - 1.2), v(-58.1, 4.4, z + 1.2), DARK, nil, false)
		make.box("ExecChairSeat", v(-53.6, 0.6, z - 0.9), v(-51.8, 0.9, z + 0.9), DARK, nil, false)
		make.box("ExecChairBack", v(-51.8, 0.9, z - 0.9), v(-51.5, 3.6, z + 0.9), DARK, nil, false)
	end

	-- Plants and a water cooler.
	make.plant(-65, -98)
	make.plant(-30, -139)
	make.plant(-30, -98)
	make.plant(-65, -123)
	make.box("WaterCooler", v(-31, 0, -129), v(-29.6, 3.4, -127.6), WHITE)
	local jug = make.box("WaterCoolerJug", v(-30.9, 3.4, -128.9), v(-29.7, 5, -127.7), Color3.fromRGB(120, 200, 255), Enum.Material.Glass, false)
	jug:SetAttribute("SolidTransparency", 0.3)
end

-- Productivity Training sign, outside the front like floor 1's speed sign.
local function buildTrainingSign(make)
	local p = Config.TrainingSignPosition
	make.box("TrainingSignPost", v(p.X - 0.2, 0, p.Z - 0.2), v(p.X + 0.2, 2.2, p.Z + 0.2), GREY)
	local board = make.box("TrainingSign", v(p.X - 0.2, 2.2, p.Z - 2.8), v(p.X + 0.2, 6.2, p.Z + 2.8), DARK)
	board.Name = "TrainingSign"
	local label = make.text(board, Enum.NormalId.Right, "PRODUCTIVITY TRAINING", WHITE)
	label.Name = "Text" -- ManagerCenterService rewrites it with the current level
	make.accent("TrainingSignTrim", v(p.X - 0.25, 6.2, p.Z - 2.9), v(p.X + 0.25, 6.5, p.Z + 2.9), false)
end

---------------------------------------------------------------------------
-- Pads and saved values
---------------------------------------------------------------------------

-- Copies a first-floor pad (labels and look, no scripts or values) to a
-- plot-local spot on floor 2. Hidden until ManagerCenterService shows it.
local function copyPad(template, name, floorTop, storey, position, parent)
	local pad = template:Clone()
	for _, descendant in ipairs(pad:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("ValueBase") then
			descendant:Destroy()
		end
	end
	for name2 in pairs(pad:GetAttributes()) do
		if string.sub(name2, 1, 3) ~= "RBX" then
			pad:SetAttribute(name2, nil)
		end
	end
	pad.Name = name
	pad.CFrame = floorTop * CFrame.new(position.X, storey + pad.Size.Y / 2, position.Z)
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
		end
	end
	pad.Parent = parent
	return pad
end

--[[
	ctx = {
		centre (floor-2 Centre01_Worker model), floorTop (CFrame at floor 1's
		surface), storey (number), plotColor (Color3), accentTag (string),
		supervisorPadTemplate (BasePart), trainingPadTemplate (BasePart)
	}
]]
function Builder.Build(ctx)
	local centre = ctx.centre

	-- Floor-2 naming: the zone title and centre pad say "Manager Center".
	local displayName = centre:FindFirstChild("DisplayName")
	if displayName and displayName:IsA("StringValue") then
		displayName.Value = Config.ManagerCenterName
	end
	for _, label in ipairs(centre:GetDescendants()) do
		if label:IsA("TextLabel") and (label.Name == "NameText" or (label.Name == "Text" and label.Parent and label.Parent.Name == "AreaTitle")) then
			label.Text = label.Name == "NameText" and Config.ManagerCenterName or string.upper(Config.ManagerCenterName)
		end
	end

	-- Building + training sign.
	local layout = Instance.new("Folder")
	layout.Name = Config.LayoutFolderName
	layout.Parent = centre
	local make = newPartMaker(ctx.floorTop * CFrame.new(0, ctx.storey, 0), layout, ctx.plotColor, ctx.accentTag)
	buildBuilding(make)
	buildTrainingSign(make)

	-- Saved supervisor purchases.
	local activations = Instance.new("Folder")
	activations.Name = "WorkerActivations"
	activations.Parent = centre
	for _, stage in ipairs(Config.SupervisorStages) do
		local value = Instance.new("BoolValue")
		value.Name = stage.key
		value.Value = false
		value.Parent = activations
	end

	-- Pads.
	local upgrades = Instance.new("Folder")
	upgrades.Name = "Upgrades"
	upgrades.Parent = centre
	copyPad(ctx.supervisorPadTemplate, "SupervisorBuyPad", ctx.floorTop, ctx.storey, Config.SupervisorPadPosition, upgrades)

	local training = Instance.new("Folder")
	training.Name = "ProductivityTraining"
	training.Parent = upgrades
	copyPad(ctx.trainingPadTemplate, "BuyPad", ctx.floorTop, ctx.storey, Config.TrainingPadPosition, training)
	local level = Instance.new("IntValue")
	level.Name = "UpgradeLevel"
	level.Value = 1
	level.Parent = training

	local supervisors = Instance.new("Folder")
	supervisors.Name = "Supervisors"
	supervisors.Parent = centre
end

return Builder
