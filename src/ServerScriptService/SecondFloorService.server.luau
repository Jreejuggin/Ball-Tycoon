--[[
	SecondFloorService
	Builds a second floor into every plot when the server starts, then runs its
	unlock and purchase flow for each plot independently.

	Why it is built in code: one definition, placed with each plot's own Floor
	CFrame, comes out identical and correctly rotated on all 10 plots, and the
	plot .rbxm files stay untouched.

	It reuses the existing systems instead of replacing them:
	  * Walls / Glass / Roof / Ceiling Lights are copies of the first floor's own
	    structure parts, one storey up, sold through StructurePurchaseService.
	  * Every purchase is an "Activated" / "UpgradeLevel" value inside the plot,
	    which TycoonProgressService already saves, restores and resets.
	  * Accent parts carry the PlotThemeAccent tag, so plot colors apply.
	CubicleWorkstationService runs the cubicles this script builds.

	States per plot:
	  Hidden    - Home Centre level 1 not finished: nothing of floor 2 shows.
	  Preview   - Home Centre and all its structures bought: ghost stairs + pad.
	  Purchased - floor bought: solid stairs, walkable floor, floor-2 upgrades.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ServerScriptService:WaitForChild("SecondFloorConfig"))
local StructurePurchaseService = require(ServerScriptService:WaitForChild("StructurePurchaseService"))
local PlotThemeConfig = require(ReplicatedStorage:WaitForChild("PlotThemeConfig"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local COPIED_GROUPS = { Walls = true, Glass = true, Roof = true, CeilingLights = true }
local COLOR_GREEN = Color3.new(0, 1, 0)
local COLOR_RED = Color3.new(0.8, 0.1, 0.1)
local STAIR_COLOR = Color3.fromRGB(60, 62, 68)
local CUBICLE_WOOD = Color3.fromRGB(166, 98, 33)
local CUBICLE_DARK = Color3.fromRGB(28, 29, 31)
local CUBICLE_PANEL = Color3.fromRGB(232, 225, 208)
local UPDATE_INTERVAL_SECONDS = 0.5

---------------------------------------------------------------------------
-- Shared helpers
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

local function getPlotColor(plot)
	local color = plot:GetAttribute("PlotColor")
	if typeof(color) == "Color3" then
		return color
	end
	return PlotThemeConfig.PlotColors[plot.Name] or Color3.fromRGB(150, 150, 150)
end

local function findChildPath(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function stripScripts(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end
end

local function setBillboardsEnabled(part, enabled)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("BillboardGui") then
			child.Enabled = enabled
		end
	end
end

-- Returns the Activated value of the structure slot that owns a group.
local function findSlotActivated(structureSlots, groupName)
	if not structureSlots then
		return nil
	end
	for _, slot in ipairs(structureSlots:GetChildren()) do
		local group = slot:FindFirstChild("StructureGroup")
		if group and group.Value == groupName then
			return findChildPath(slot, "BuyPad", "Activated")
		end
	end
	return nil
end

-- Anchored box spanning two corners in the given frame. It starts hidden; the
-- state code reveals it. SolidTransparency / SolidCanCollide record the look it
-- should have once purchased.
local function makeBox(name, frame, cornerA, cornerB, color, material, parent)
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
	part:SetAttribute("SolidTransparency", 0)
	part:SetAttribute("SolidCanCollide", true)
	part.Parent = parent
	return part
end

local function showParts(parts)
	for _, part in ipairs(parts) do
		part.Transparency = part:GetAttribute("SolidTransparency") or 0
		part.CanCollide = part:GetAttribute("SolidCanCollide") ~= false
	end
end

local function ghostParts(parts)
	for _, part in ipairs(parts) do
		part.Transparency = Config.GhostTransparency
		part.CanCollide = false
	end
end

local function hideParts(parts)
	for _, part in ipairs(parts) do
		part.Transparency = 1
		part.CanCollide = false
	end
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

-- Copies every first-floor Walls/Glass/Roof/CeilingLights part one storey up,
-- moved into the floor-2 groups. Copies keep their tags (plot colors) and any
-- lights inside them.
local function copyStructureShell(plot, storey, shell)
	local lift = Vector3.new(0, storey, 0) -- plots are only rotated around Y
	for _, part in ipairs(plot:GetDescendants()) do
		local group = part:IsA("BasePart") and part:GetAttribute("StructureGroup")
		if group and COPIED_GROUPS[group] then
			local copy = part:Clone()
			stripScripts(copy)
			copy:SetAttribute("StructureGroup", group .. Config.GroupSuffix)

			-- Floor 1's pad may already have hidden the original. Restore the
			-- authored look it remembered, so floor 2 reveals the right state.
			local transparency = part:GetAttribute("OriginalTransparency")
			local canCollide = part:GetAttribute("OriginalCanCollide")
			if transparency ~= nil then
				copy.Transparency = transparency
			end
			if canCollide ~= nil then
				copy.CanCollide = canCollide
			end
			copy:SetAttribute("OriginalTransparency", nil)
			copy:SetAttribute("OriginalCanCollide", nil)

			copy.Anchored = true
			copy.CFrame = part.CFrame + lift
			copy.Parent = shell
		end
	end
end

-- Floor 1's back wall has a gap for the laser door. On floor 2 that gap would be
-- an open drop, so each wall layer is extended across it.
local function fillBackWallGap(floorPart, shell)
	for _, left in ipairs(shell:GetChildren()) do
		local layer = left:IsA("BasePart") and string.match(left.Name, "^BackWallLeft_(.+)$")
		local right = layer and shell:FindFirstChild("BackWallRight_" .. layer)
		if right and right:IsA("BasePart") then
			local leftLocal = floorPart.CFrame:ToObjectSpace(left.CFrame)
			local rightLocal = floorPart.CFrame:ToObjectSpace(right.CFrame)
			local aligned = math.abs(leftLocal.XVector.X) > 0.999 and math.abs(rightLocal.XVector.X) > 0.999
			if aligned then
				local gapStart = leftLocal.X + left.Size.X / 2
				local gapEnd = rightLocal.X - right.Size.X / 2
				if leftLocal.X > rightLocal.X then
					gapStart = rightLocal.X + right.Size.X / 2
					gapEnd = leftLocal.X - left.Size.X / 2
				end
				if gapEnd - gapStart > 0.05 then
					local filler = left:Clone()
					filler.Name = "BackWallGap_" .. layer
					filler.Size = Vector3.new(gapEnd - gapStart, left.Size.Y, left.Size.Z)
					filler.CFrame = floorPart.CFrame
						* CFrame.new((gapStart + gapEnd) / 2, leftLocal.Y, leftLocal.Z)
						* leftLocal.Rotation
					filler.Parent = shell
				end
			else
				warn("[SecondFloorService] Back wall pieces are not plot-aligned; gap left open for layer " .. layer)
			end
		end
	end
end

-- L-shaped staircase with two turns: flight 1 along +Z, flight 2 along +X,
-- flight 3 back along -Z, ending level with floor 2. Returns its parts and the
-- plot-local rectangles that must stay open in floor 2 for headroom.
local function buildStairs(floorTop, storey, slabThickness, plotColor, parent)
	local origin = Config.StairOrigin
	local frame = floorTop * CFrame.new(origin.X, 0, origin.Z)
	local width = Config.StairWidth
	local depth = Config.StepDepth
	local totalSteps = math.max(3, math.floor(storey / Config.TargetStepRise + 0.5))
	local rise = storey / totalSteps
	local flight1 = math.floor(totalSteps / 3)
	local flight2 = flight1
	local flight3 = totalSteps - flight1 - flight2
	local parts = {}

	local function block(name, cornerA, cornerB, isAccent)
		local part = makeBox(name, frame, cornerA, cornerB, isAccent and plotColor or STAIR_COLOR, nil, parent)
		if isAccent then
			CollectionService:AddTag(part, PlotThemeConfig.AccentPartTag)
		end
		table.insert(parts, part)
	end

	-- Flight 1 climbs along +Z.
	for i = 1, flight1 do
		local top = i * rise
		block("Flight1_Step" .. i, Vector3.new(0, top - 1, (i - 1) * depth), Vector3.new(width, top, i * depth))
	end

	-- First turn, then flight 2 climbs along +X.
	local landingZ = flight1 * depth
	local landing1Top = flight1 * rise
	block("Landing1", Vector3.new(0, landing1Top - 1, landingZ), Vector3.new(width, landing1Top, landingZ + width), true)
	for j = 1, flight2 do
		local top = (flight1 + j) * rise
		block(
			"Flight2_Step" .. j,
			Vector3.new(width + (j - 1) * depth, top - 1, landingZ),
			Vector3.new(width + j * depth, top, landingZ + width)
		)
	end

	-- Second turn, then flight 3 climbs along -Z and ends level with floor 2.
	local landing2X = width + flight2 * depth
	local landing2Top = (flight1 + flight2) * rise
	block(
		"Landing2",
		Vector3.new(landing2X, landing2Top - 1, landingZ),
		Vector3.new(landing2X + width, landing2Top, landingZ + width),
		true
	)
	for k = 1, flight3 do
		local top = (flight1 + flight2 + k) * rise
		block(
			"Flight3_Step" .. k,
			Vector3.new(landing2X, top - 1, landingZ - k * depth),
			Vector3.new(landing2X + width, top, landingZ - (k - 1) * depth)
		)
	end

	-- Openings in floor 2 (plot-local), so no step is closer to its underside
	-- than StairHeadroom. 1-stud side margins; no margin at flight 3's arrival
	-- edge, so the last step meets the floor without a gap.
	local slabBottom = storey - slabThickness
	local function needsHeadroom(stepTop)
		return stepTop + Config.StairHeadroom > slabBottom
	end
	local holes = {}
	local function addHole(x0, x1, z0, z1)
		table.insert(holes, {
			x0 = origin.X + x0,
			x1 = origin.X + x1,
			z0 = origin.Z + z0,
			z1 = origin.Z + z1,
		})
	end

	-- Upper part of flight 2: from the first step that needs the room, up to landing 2.
	for j = 1, flight2 do
		if needsHeadroom((flight1 + j) * rise) then
			addHole(width + (j - 1) * depth - 1, landing2X, landingZ - 1, landingZ + width + 1)
			break
		end
	end

	-- Landing 2 and all of flight 3 always reach up to floor 2.
	addHole(landing2X - 1, landing2X + width + 1, landingZ - flight3 * depth, landingZ + width + 1)

	return parts, holes
end

-- Splits the full floor rectangle into pieces that avoid every hole rectangle.
-- Cuts the floor into strips at every hole edge along X, then leaves out the
-- parts of each strip that a hole covers. Returns {x0, z0, x1, z1} pieces.
local function subtractHoles(minX, maxX, minZ, maxZ, holes)
	local xs = { minX, maxX }
	for _, hole in ipairs(holes) do
		table.insert(xs, math.clamp(hole.x0, minX, maxX))
		table.insert(xs, math.clamp(hole.x1, minX, maxX))
	end
	table.sort(xs)

	local pieces = {}
	for i = 1, #xs - 1 do
		local x0, x1 = xs[i], xs[i + 1]
		if x1 - x0 > 0.01 then
			local blocked = {}
			for _, hole in ipairs(holes) do
				if hole.x0 <= x0 + 0.001 and hole.x1 >= x1 - 0.001 then
					table.insert(blocked, { math.max(hole.z0, minZ), math.min(hole.z1, maxZ) })
				end
			end
			table.sort(blocked, function(a, b)
				return a[1] < b[1]
			end)

			local z = minZ
			for _, range in ipairs(blocked) do
				if range[1] - z > 0.01 then
					table.insert(pieces, { x0, z, x1, range[1] })
				end
				z = math.max(z, range[2])
			end
			if maxZ - z > 0.01 then
				table.insert(pieces, { x0, z, x1, maxZ })
			end
		end
	end
	return pieces
end

-- Walkable floor 2, built where floor 1's roof slab sits, with the stairwell
-- openings cut out.
local function buildFloorSlab(floorPart, firstFloorRoof, floorTop, storey, holes, parent)
	local halfX = floorPart.Size.X / 2
	local halfZ = floorPart.Size.Z / 2
	local top = storey
	local bottom = storey - firstFloorRoof.Size.Y
	local parts = {}
	for index, piece in ipairs(subtractHoles(-halfX, halfX, -halfZ, halfZ, holes)) do
		local part = makeBox(
			"Slab" .. index,
			floorTop,
			Vector3.new(piece[1], bottom, piece[2]),
			Vector3.new(piece[3], top, piece[4]),
			firstFloorRoof.Color,
			firstFloorRoof.Material,
			parent
		)
		table.insert(parts, part)
	end
	return parts
end

-- Floor 1's walls are authored non-collidable, so floor 2 gets an invisible
-- solid barrier around its edge to stop players walking off.
local function buildSafetyRails(floorPart, floorTop, storey, parent)
	local halfX = floorPart.Size.X / 2
	local halfZ = floorPart.Size.Z / 2
	local bottom = storey
	local top = storey + Config.SafetyRailHeight
	local boxes = {
		{ Vector3.new(-halfX - 1, bottom, -halfZ - 1), Vector3.new(halfX + 1, top, -halfZ) },
		{ Vector3.new(-halfX - 1, bottom, halfZ), Vector3.new(halfX + 1, top, halfZ + 1) },
		{ Vector3.new(-halfX - 1, bottom, -halfZ), Vector3.new(-halfX, top, halfZ) },
		{ Vector3.new(halfX, bottom, -halfZ), Vector3.new(halfX + 1, top, halfZ) },
	}
	local parts = {}
	for index, box in ipairs(boxes) do
		local part = makeBox("SafetyRail" .. index, floorTop, box[1], box[2], Color3.new(1, 1, 1), nil, parent)
		part:SetAttribute("SolidTransparency", 1) -- invisible, but solid
		table.insert(parts, part)
	end
	return parts
end

-- Places a copied pad at a plot-local X/Z while keeping the source pad's height
-- above its floor and its rotation, so it looks exactly like the original.
local function placeLikeSource(copy, source, floorTop, x, z, extraHeight)
	local sourceLocal = floorTop:ToObjectSpace(source.CFrame)
	copy.CFrame = floorTop * CFrame.new(x, sourceLocal.Y + extraHeight, z) * sourceLocal.Rotation
end

-- The green floor-2 buy pad at the foot of the stairs: a copy of a Home Centre
-- structure pad, with its own logic in this script.
local function buildFloorPad(padSource, floorTop, parent)
	local pad = padSource:Clone()
	stripScripts(pad)
	for _, child in ipairs(pad:GetChildren()) do
		if child:IsA("ValueBase") then
			child:Destroy()
		end
	end
	pad.Name = "FloorBuyPad"
	local position = Config.StairOrigin + Config.FloorPadOffset
	placeLikeSource(pad, padSource, floorTop, position.X, position.Z, 0)
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanTouch = false
	pad.Transparency = 1
	pad.Material = Enum.Material.Neon
	if pad:IsA("UnionOperation") then
		pad.UsePartColor = true
	end

	-- Name label, styled as a copy of the pad's own price label.
	local priceLabel = pad:FindFirstChild("PriceLabel")
	if priceLabel and priceLabel:IsA("BillboardGui") then
		local nameLabel = priceLabel:Clone()
		nameLabel.Name = "NameLabel"
		nameLabel.StudsOffset = priceLabel.StudsOffset + Vector3.new(0, 1.5, 0)
		for _, label in ipairs(nameLabel:GetDescendants()) do
			if label:IsA("TextLabel") then
				label.Text = "Second Floor"
				label.TextColor3 = Color3.new(1, 1, 1)
			end
		end
		nameLabel.Parent = pad
	end

	setBillboardsEnabled(pad, false)
	pad.Parent = parent
	return pad
end

-- Floor-2 structure slots, laid out exactly like the Home Centre's so that
-- StructurePurchaseService can run them unchanged.
local function buildStructureSlots(padSource, floorTop, storey, secondFloor)
	local folder = Instance.new("Folder")
	folder.Name = "StructureSlots"
	folder.Parent = secondFloor

	local pads = {}
	for _, slotConfig in ipairs(Config.StructureSlots) do
		local slot = Instance.new("Model")
		slot.Name = slotConfig.slotName

		local group = Instance.new("StringValue")
		group.Name = "StructureGroup"
		group.Value = slotConfig.group .. Config.GroupSuffix
		group.Parent = slot

		local dependency = Instance.new("StringValue")
		dependency.Name = "Dependency"
		dependency.Value = slotConfig.dependency
		dependency.Parent = slot

		local pad = padSource:Clone()
		stripScripts(pad)
		pad.Name = "BuyPad"

		local price = pad:FindFirstChild("Price") or Instance.new("IntValue")
		price.Name = "Price"
		price.Value = Config.StructurePrice
		price.Parent = pad

		local activated = pad:FindFirstChild("Activated") or Instance.new("BoolValue")
		activated.Name = "Activated"
		activated.Value = false
		activated.Parent = pad

		placeLikeSource(pad, padSource, floorTop, slotConfig.padPosition.X, slotConfig.padPosition.Z, storey)
		pad.Anchored = true
		pad.Parent = slot
		slot.Parent = folder
		table.insert(pads, pad)
	end
	return folder, pads
end

-- One cubicle above a first-floor dropper slot: desk, monitor, keyboard and
-- partitions, plus a buy pad and an upgrade pad copied from that dropper's pad.
-- Cubicle-local +X points the same way as the dropper sits from its pad.
local function buildCubicle(index, head, floorTop, storey, plotColor, parent)
	local cubicle = Instance.new("Model")
	cubicle.Name = "Cubicle" .. index
	cubicle:SetAttribute("Order", index)

	local function addValue(className, name, value)
		local valueObject = Instance.new(className)
		valueObject.Name = name
		valueObject.Value = value
		valueObject.Parent = cubicle
	end
	addValue("BoolValue", "Activated", false)
	addValue("IntValue", "UpgradeLevel", 1)
	addValue("IntValue", "Price", Config.CubiclePrice)
	addValue("NumberValue", "BaseIncomePerMinute", Config.CubicleBaseIncomePerMinute)
	addValue("NumberValue", "CycleSeconds", Config.CubicleCycleSeconds)

	local localPosition = floorTop:PointToObjectSpace(head.Position)
	local frame = floorTop * CFrame.new(localPosition.X, storey, localPosition.Z)
	cubicle:SetAttribute("CubicleFrame", frame)

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = cubicle

	local function piece(name, cornerA, cornerB, color, material, collide)
		local part = makeBox(name, frame, cornerA, cornerB, color, material, geometry)
		part:SetAttribute("SolidCanCollide", collide ~= false)
		return part
	end
	local function accent(name, cornerA, cornerB)
		local part = piece(name, cornerA, cornerB, plotColor)
		CollectionService:AddTag(part, PlotThemeConfig.AccentPartTag)
		return part
	end

	piece("Desk", Vector3.new(4.8, 0, -3), Vector3.new(6.6, 3.4, 3), CUBICLE_WOOD)
	piece("Keyboard", Vector3.new(5.0, 3.4, -1.2), Vector3.new(5.6, 3.55, 1.2), CUBICLE_DARK, nil, false)
	piece("MonitorStand", Vector3.new(6.05, 3.4, -0.3), Vector3.new(6.25, 3.9, 0.3), CUBICLE_DARK, nil, false)
	piece("Monitor", Vector3.new(6.0, 3.9, -1.6), Vector3.new(6.3, 6.4, 1.6), CUBICLE_DARK, nil, false)
	local screen = piece(
		"Screen",
		Vector3.new(5.95, 4.05, -1.45),
		Vector3.new(6.0, 6.25, 1.45),
		Config.CubicleLevels[1].screenColor,
		Enum.Material.Neon,
		false
	)
	piece("PartitionBack", Vector3.new(7.4, 0, -4.7), Vector3.new(7.8, 5, 4.7), CUBICLE_PANEL)
	piece("PartitionLeft", Vector3.new(1.5, 0, 4.3), Vector3.new(7.4, 5, 4.7), CUBICLE_PANEL)
	piece("PartitionRight", Vector3.new(1.5, 0, -4.7), Vector3.new(7.4, 5, -4.3), CUBICLE_PANEL)
	accent("TrimBack", Vector3.new(7.4, 5, -4.7), Vector3.new(7.8, 5.3, 4.7))
	accent("TrimLeft", Vector3.new(1.5, 5, 4.3), Vector3.new(7.4, 5.3, 4.7))
	accent("TrimRight", Vector3.new(1.5, 5, -4.7), Vector3.new(7.4, 5.3, -4.3))

	-- Income label above the monitor, styled like the machines' IncomeLabel.
	local incomeLabel = Instance.new("BillboardGui")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.Size = UDim2.new(0, 170, 0, 56)
	incomeLabel.StudsOffset = Vector3.new(0, 2.4, 0)
	incomeLabel.MaxDistance = 80
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

	-- Buy and upgrade pads share the dropper pad's spot and look; only one is
	-- ever visible (buy before purchase, upgrade after).
	local lift = Vector3.new(0, storey, 0)
	local function makePad(name, labelText)
		local pad = head:Clone()
		stripScripts(pad)
		pad.Name = name
		pad.CFrame = head.CFrame + lift
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanTouch = false
		pad.Transparency = 1
		pad.Material = Enum.Material.Neon
		if pad:IsA("UnionOperation") then
			pad.UsePartColor = true
		end
		local nameLabel = pad:FindFirstChild("DropperLabel")
		if nameLabel then
			for _, label in ipairs(nameLabel:GetDescendants()) do
				if label:IsA("TextLabel") then
					label.Text = labelText
				end
			end
		end
		setBillboardsEnabled(pad, false)
		pad.Parent = cubicle
	end
	makePad("BuyPad", "Computer Worker")
	makePad("UpgradePad", "Upgrade")

	cubicle.Parent = parent
end

local function buildCubicles(plot, floorTop, storey, plotColor, parent)
	local index = 0
	for _, source in ipairs(Config.CubicleSources) do
		local machineFolder = plot:FindFirstChild(source.folder)
		for _, slotName in ipairs(source.slots) do
			index += 1
			local head = findChildPath(machineFolder, slotName, "BuyPad", "Head")
			if head and head:IsA("BasePart") then
				buildCubicle(index, head, floorTop, storey, plotColor, parent)
			else
				warn(("[SecondFloorService] %s: no dropper pad at %s/%s; cubicle %d skipped."):format(
					plot.Name,
					source.folder,
					slotName,
					index
				))
			end
		end
	end
end

local function collectGroupLights(shell, groupName)
	local lights = {}
	for _, descendant in ipairs(shell:GetDescendants()) do
		if descendant:IsA("Light") then
			local part = descendant:FindFirstAncestorWhichIsA("BasePart")
			if part and part:GetAttribute("StructureGroup") == groupName then
				descendant.Enabled = false
				table.insert(lights, descendant)
			end
		end
	end
	return lights
end

local function buildSecondFloor(plot)
	if plot:FindFirstChild("SecondFloor") then
		warn("[SecondFloorService] " .. plot.Name .. " already has a SecondFloor; skipping.")
		return nil
	end

	local floorPart = plot:FindFirstChild("Floor")
	local firstFloorRoof = findChildPath(plot, "PerimeterWall", "Roof")
	local homeCentre = findChildPath(plot, "CentreSlots", "Centre02_Home")
	local firstFloorSlots = homeCentre and homeCentre:FindFirstChild("StructureSlots")
	local padSource = findChildPath(firstFloorSlots, "Slot_Walls", "BuyPad")
	if not (floorPart and floorPart:IsA("BasePart")
		and firstFloorRoof and firstFloorRoof:IsA("BasePart")
		and firstFloorSlots
		and padSource and padSource:IsA("BasePart"))
	then
		warn("[SecondFloorService] " .. plot.Name .. " is missing first-floor parts; second floor not built.")
		return nil
	end

	local floorTop = floorPart.CFrame * CFrame.new(0, floorPart.Size.Y / 2, 0)
	local storey = (firstFloorRoof.Position.Y + firstFloorRoof.Size.Y / 2) - floorTop.Position.Y
	local plotColor = getPlotColor(plot)

	local secondFloor = Instance.new("Model")
	secondFloor.Name = "SecondFloor"
	-- Lets StructurePurchaseService accept this model as a structure-slot gate.
	secondFloor:SetAttribute("StructureGate", true)

	-- The floor purchase. Named Activated so TycoonProgressService saves it.
	local activated = Instance.new("BoolValue")
	activated.Name = "Activated"
	activated.Parent = secondFloor

	local shell = Instance.new("Folder")
	shell.Name = "Shell"
	shell.Parent = secondFloor
	copyStructureShell(plot, storey, shell)
	fillBackWallGap(floorPart, shell)

	local stairsFolder = Instance.new("Folder")
	stairsFolder.Name = "Stairs"
	stairsFolder.Parent = secondFloor
	local stairs, holes = buildStairs(floorTop, storey, firstFloorRoof.Size.Y, plotColor, stairsFolder)

	local slabFolder = Instance.new("Folder")
	slabFolder.Name = "FloorSlab"
	slabFolder.Parent = secondFloor
	local slab = buildFloorSlab(floorPart, firstFloorRoof, floorTop, storey, holes, slabFolder)
	local rails = buildSafetyRails(floorPart, floorTop, storey, slabFolder)

	local floorPad = buildFloorPad(padSource, floorTop, secondFloor)
	local secondFloorSlots, structurePads = buildStructureSlots(padSource, floorTop, storey, secondFloor)

	local cubicleFolder = Instance.new("Folder")
	cubicleFolder.Name = "Cubicles"
	cubicleFolder.Parent = secondFloor
	buildCubicles(plot, floorTop, storey, plotColor, cubicleFolder)

	local lightsGroup = "CeilingLights" .. Config.GroupSuffix
	local lights = collectGroupLights(shell, lightsGroup)

	secondFloor.Parent = plot

	-- Wire after parenting, so the service can find the plot and the floor-2 parts.
	for _, pad in ipairs(structurePads) do
		StructurePurchaseService.Wire(pad)
	end

	plot:SetAttribute("SecondFloorBuilt", true)

	return {
		activated = activated,
		stairs = stairs,
		slab = slab,
		rails = rails,
		floorPad = floorPad,
		lights = lights,
		lightsActivated = findSlotActivated(secondFloorSlots, lightsGroup),
		homeActivated = homeCentre:FindFirstChild("Activated"),
		firstFloorSlots = firstFloorSlots,
		firstFloorRoof = firstFloorRoof,
		firstFloorRoofActivated = findSlotActivated(firstFloorSlots, "Roof"),
	}
end

---------------------------------------------------------------------------
-- Unlock and purchase flow
---------------------------------------------------------------------------

local function runPlot(plot, built)
	local state = nil
	local isProcessingPurchase = false
	local lightsOn = nil

	-- Level 1 complete = Home Centre bought and every one of its structure slots bought.
	local function isLevelOneComplete()
		if not (built.homeActivated and built.homeActivated.Value) then
			return false
		end
		for _, slot in ipairs(built.firstFloorSlots:GetChildren()) do
			local slotActivated = findChildPath(slot, "BuyPad", "Activated")
			if slotActivated and not slotActivated.Value then
				return false
			end
		end
		return true
	end

	local function getState()
		if built.activated.Value then
			return "Purchased"
		end
		if isLevelOneComplete() then
			return "Preview"
		end
		return "Hidden"
	end

	local function updateFloorPad(visible)
		local pad = built.floorPad
		pad.Transparency = visible and 0.5 or 1
		pad.CanTouch = visible
		setBillboardsEnabled(pad, visible)
		if not visible then
			return
		end

		local cash = getCash(getOwnerPlayer(plot))
		local price = Config.FloorPrice
		local affordable = price == 0 or (cash ~= nil and cash.Value >= price)
		local color = affordable and COLOR_GREEN or COLOR_RED
		pad.Color = color
		local priceText = findChildPath(pad, "PriceLabel", "PriceText")
		if priceText then
			priceText.Text = price == 0 and "FREE" or ("$" .. tostring(price))
			priceText.TextColor3 = color
		end
	end

	-- While floor 2 is owned, its own floor (with the stairwell cut out) replaces
	-- floor 1's roof slab. The slab must be made invisible AND non-solid: the
	-- roof is solid at runtime, and an invisible solid roof is a ceiling across
	-- the whole stairwell. When floor 2 is not owned, the first floor's own
	-- structure logic keeps full control of the roof.
	local roofSuppressed = false
	local roofSavedCanCollide = nil
	local function syncFirstFloorRoof(ownsSecondFloor)
		local roof = built.firstFloorRoof
		if ownsSecondFloor then
			if not roofSuppressed then
				roofSuppressed = true
				roofSavedCanCollide = roof.CanCollide
			end
			if roof.Transparency ~= 1 then
				roof.Transparency = 1
			end
			if roof.CanCollide then
				roof.CanCollide = false
			end
		elseif roofSuppressed then
			roofSuppressed = false
			-- Hand the roof back as floor 1 left it, but only if floor 1 still
			-- owns it as purchased; otherwise its own logic keeps it hidden.
			if built.firstFloorRoofActivated and built.firstFloorRoofActivated.Value then
				roof.Transparency = roof:GetAttribute("OriginalTransparency") or 0
				local originalCanCollide = roof:GetAttribute("OriginalCanCollide")
				if originalCanCollide ~= nil then
					roof.CanCollide = originalCanCollide
				else
					roof.CanCollide = roofSavedCanCollide == true
				end
			end
		end
	end

	-- Floor-2 lights follow floor 2's own Ceiling Lights purchase.
	local function syncLights(ownsSecondFloor)
		local on = ownsSecondFloor and built.lightsActivated ~= nil and built.lightsActivated.Value
		if on == lightsOn then
			return
		end
		lightsOn = on
		for _, light in ipairs(built.lights) do
			light.Enabled = on
		end
	end

	local function applyState(force)
		local newState = getState()
		if force or newState ~= state then
			state = newState
			if state == "Purchased" then
				showParts(built.stairs)
				showParts(built.slab)
				showParts(built.rails)
			elseif state == "Preview" then
				ghostParts(built.stairs)
				hideParts(built.slab)
				hideParts(built.rails)
			else
				hideParts(built.stairs)
				hideParts(built.slab)
				hideParts(built.rails)
			end
		end
		updateFloorPad(state == "Preview")
		syncFirstFloorRoof(state == "Purchased")
		syncLights(state == "Purchased")
	end

	built.floorPad.Touched:Connect(function(hit)
		if state ~= "Preview" or isProcessingPurchase or built.activated.Value then
			return
		end

		local player = getPlayerFromHit(hit)
		if not player or getOwnerPlayer(plot) ~= player then
			return
		end
		if not isLevelOneComplete() then
			return
		end

		local price = Config.FloorPrice
		local cash = getCash(player)
		if price > 0 and (not cash or cash.Value < price) then
			return
		end

		-- Lock before charging, so repeated touches cannot charge twice.
		isProcessingPurchase = true
		if price > 0 then
			cash.Value -= price
		end
		built.activated.Value = true
		applyState(true)

		PurchaseSoundModule.PlayPurchaseForTarget(player, built.floorPad)
		PurchaseSoundModule.PlayAreaUnlocked(player, built.floorPad)
		PurchaseEffectModule.PlayAcrossParts(built.stairs, nil, {
			pointCount = 30,
			totalParticleBudget = 120,
		})

		task.delay(0.4, function()
			isProcessingPurchase = false
		end)
	end)

	applyState(true)
	task.spawn(function()
		while plot.Parent do
			task.wait(UPDATE_INTERVAL_SECONDS)
			applyState(false)
		end
	end)
end

---------------------------------------------------------------------------
-- Startup: build every plot first (no yields), then start their flows.
---------------------------------------------------------------------------

for _, plot in ipairs(Workspace:GetChildren()) do
	if plot:IsA("Model") and string.match(plot.Name, "^P%d+$") then
		local ok, result = pcall(buildSecondFloor, plot)
		if not ok then
			warn("[SecondFloorService] Failed to build " .. plot.Name .. ": " .. tostring(result))
		elseif result then
			runPlot(plot, result)
		end
	end
end
