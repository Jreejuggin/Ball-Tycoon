-- ArrowIndicator
-- A reusable, parts-only 3D marker that hovers and bobs above any BasePart
-- or Model, pointing straight down at it. Built entirely from plain Neon
-- Parts (a stack of flat plates, shrinking toward the target) rather than a
-- WedgePart or a SpecialMesh cone -- both of those have axis/orientation
-- conventions that are easy to get backwards without being able to see the
-- result in Studio, and a sideways or upside-down arrow is a real, silent
-- bug. A stack of flat square plates looks identical from every horizontal
-- viewing angle, so there's no rotation to get wrong: only Size and a
-- vertical offset, both fully deterministic.
--
-- Client-only by design: call this from a LocalScript (the tutorial
-- controller, Phase 5) so the parts it creates are parented to Workspace on
-- the client and therefore only ever visible to that one player -- exactly
-- what a personal "go here" tutorial marker should do. Calling this from the
-- server would replicate the arrow to every player, which is never what you
-- want here.
--
-- Usage:
--   local arrow = ArrowIndicator.new(somePart)
--   arrow:SetTarget(someOtherModel) -- move it to point at something else
--   arrow:Destroy() -- stop the animation and remove the parts

local TweenService = game:GetService("TweenService")

local ArrowIndicator = {}
ArrowIndicator.__index = ArrowIndicator

local PLATE_COUNT = 4
local PLATE_THICKNESS = 0.3
local PLATE_SPACING = 0.7 -- studs between plate centers, top to bottom
local TOP_PLATE_WIDTH = 2.4
local BOTTOM_PLATE_WIDTH = 0.6 -- smallest plate is closest to the target
local HOVER_HEIGHT = 6 -- studs above the target's pivot the stack floats at
local BOB_HEIGHT = 1 -- studs of vertical travel per bob
local BOB_DURATION = 0.9 -- seconds for one direction of the bob
local ARROW_COLOR = Color3.fromRGB(255, 221, 64)

local function plateWidth(index)
	-- Linearly interpolate plate width from top (widest) to bottom (narrowest).
	local t = (index - 1) / (PLATE_COUNT - 1)
	return TOP_PLATE_WIDTH + (BOTTOM_PLATE_WIDTH - TOP_PLATE_WIDTH) * t
end

local function resolvePivotPosition(target)
	assert(target ~= nil, "ArrowIndicator target cannot be nil")
	assert(typeof(target.GetPivot) == "function", "ArrowIndicator target must support GetPivot (a BasePart or Model)")
	return target:GetPivot().Position
end

function ArrowIndicator.new(targetPart, options)
	options = options or {}
	local self = setmetatable({}, ArrowIndicator)

	self._color = options.color or ARROW_COLOR
	self._plates = {}
	-- Offset of each plate from the stack's own base position, in studs
	-- above the base. Plate 1 (widest) is on top; the last plate (narrowest)
	-- sits closest to the target.
	self._plateOffsets = {}

	for index = 1, PLATE_COUNT do
		local plate = Instance.new("Part")
		plate.Name = "ArrowPlate" .. index
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanTouch = false
		plate.CanQuery = false
		plate.CastShadow = false
		plate.Material = Enum.Material.Neon
		plate.Color = self._color
		local width = plateWidth(index)
		plate.Size = Vector3.new(width, PLATE_THICKNESS, width)
		plate.Parent = workspace

		-- Widest plate on top, narrowest at the bottom, moving toward the target.
		self._plateOffsets[index] = -(index - 1) * PLATE_SPACING
		table.insert(self._plates, plate)
	end

	self._bobValue = Instance.new("NumberValue")
	self._bobValue.Value = 0
	self._bobChangedConnection = self._bobValue.Changed:Connect(function(newBobOffset)
		self:_applyBob(newBobOffset)
	end)

	local bobTweenInfo = TweenInfo.new(BOB_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	self._bobTween = TweenService:Create(self._bobValue, bobTweenInfo, { Value = BOB_HEIGHT })
	self._bobTween:Play()

	self:SetTarget(targetPart)

	return self
end

function ArrowIndicator:_applyBob(bobOffset)
	for index, plate in ipairs(self._plates) do
		local base = self._basePosition
		if base then
			plate.Position = base + Vector3.new(0, self._plateOffsets[index] + bobOffset, 0)
		end
	end
end

-- Repoints the same arrow at a different target instead of destroying and
-- recreating it -- the tutorial controller reuses one ArrowIndicator across
-- every step this way.
function ArrowIndicator:SetTarget(targetPart)
	local targetPosition = resolvePivotPosition(targetPart)
	self._basePosition = targetPosition + Vector3.new(0, HOVER_HEIGHT, 0)
	self:_applyBob(self._bobValue.Value)
end

function ArrowIndicator:Destroy()
	if self._bobTween then
		self._bobTween:Cancel()
		self._bobTween = nil
	end
	if self._bobChangedConnection then
		self._bobChangedConnection:Disconnect()
		self._bobChangedConnection = nil
	end
	if self._bobValue then
		self._bobValue:Destroy()
		self._bobValue = nil
	end
	for _, plate in ipairs(self._plates) do
		plate:Destroy()
	end
	self._plates = {}
end

return ArrowIndicator
