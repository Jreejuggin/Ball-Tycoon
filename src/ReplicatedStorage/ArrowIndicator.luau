-- ArrowIndicator
-- A reusable, parts-only 3D marker that hovers and bobs above any BasePart
-- or Model, pointing straight down at it: a single blue chevron, built from
-- the same two-arm-piece trick as its sibling [[ArrowTrail]] (the flowing
-- path), so the destination marker and the path that leads to it read as
-- one visual language.
--
-- Shape note: this used to be a stack of flat, shrinking Neon plates
-- specifically because a plate looks identical from every horizontal
-- viewing angle, sidestepping any need to get a WedgePart/SpecialMesh axis
-- convention right without being able to see the result in Studio. A single
-- directional chevron reopens that question -- except here it doesn't,
-- because "pointing at the target" for a marker that only ever hovers
-- straight above it is always just "point down," and CFrame.lookAt derives
-- that frame from explicit vector math this module controls end to end:
-- LookVector is provably (0, -1, 0) by construction, not a convention
-- borrowed from a mesh/wedge asset. The `upHint` below only chooses which
-- compass direction the two arms flare out toward -- it can't change
-- whether the shape points down, only which way its "wings" face -- so
-- there's nothing here that needs a Studio eyeball to confirm, unlike the
-- WedgePart/cone route this project deliberately avoided.
--
-- Client-only by design: call this from a LocalScript (the tutorial
-- controller, Phase 5) so the parts it creates are parented to Workspace on
-- the client and therefore only ever visible to that one player -- exactly
-- what a personal "go here" tutorial marker should do. Calling this from the
-- server would replicate the marker to every player, which is never what
-- you want here.
--
-- Usage:
--   local arrow = ArrowIndicator.new(somePart)
--   arrow:SetTarget(someOtherModel) -- move it to point at something else
--   arrow:Destroy() -- stop the animation and remove the parts

local TweenService = game:GetService("TweenService")

local ArrowIndicator = {}
ArrowIndicator.__index = ArrowIndicator

local ARM_LENGTH = 2.4
local ARM_THICKNESS = 0.4
local ARM_HEIGHT = 0.4
local ARM_ANGLE = math.rad(40) -- half-angle of the chevron's "V", same as ArrowTrail
local HOVER_HEIGHT = 6 -- studs above the target's pivot the chevron floats at
local BOB_HEIGHT = 1 -- studs of vertical travel per bob
local BOB_DURATION = 0.9 -- seconds for one direction of the bob
local ARROW_COLOR = Color3.fromRGB(64, 170, 255)

-- Any fixed direction that isn't parallel to straight down works here --
-- it only decides which way the chevron's two arms flare, never whether it
-- points down. Kept as a named constant so that choice is deliberate and
-- in one place rather than a magic vector buried in the frame math.
local UP_HINT = Vector3.new(0, 0, -1)

local function resolvePivotPosition(target)
	assert(target ~= nil, "ArrowIndicator target cannot be nil")
	assert(typeof(target.GetPivot) == "function", "ArrowIndicator target must support GetPivot (a BasePart or Model)")
	return target:GetPivot().Position
end

-- Both arms of the chevron, as offsets from a frame whose origin is the
-- point of the "V" and whose LookVector aims at whatever the frame was
-- built to look at. Identical shape math to ArrowTrail.armOffsets() -- see
-- that module for why pushing an arm to local +Z (i.e. "behind" the point)
-- is what draws an arrowhead rather than a random V.
local function armOffsets()
	local offsets = {}
	for _, sign in ipairs({ 1, -1 }) do
		table.insert(offsets, CFrame.Angles(0, sign * ARM_ANGLE, 0) * CFrame.new(0, 0, ARM_LENGTH / 2))
	end
	return offsets
end

function ArrowIndicator.new(targetPart, options)
	options = options or {}
	local self = setmetatable({}, ArrowIndicator)

	self._color = options.color or ARROW_COLOR
	self._offsets = armOffsets()

	self._folder = Instance.new("Folder")
	self._folder.Name = "TutorialArrowIndicator"
	self._folder.Parent = workspace

	self._arms = {}
	for index, offset in ipairs(self._offsets) do
		local arm = Instance.new("Part")
		arm.Name = "IndicatorArm" .. index
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanTouch = false
		arm.CanQuery = false
		arm.CastShadow = false
		arm.Material = Enum.Material.Neon
		arm.Color = self._color
		arm.Size = Vector3.new(ARM_THICKNESS, ARM_HEIGHT, ARM_LENGTH)
		arm.Parent = self._folder
		table.insert(self._arms, { part = arm, offset = offset })
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
	local base = self._basePosition
	if not base then
		return
	end
	local point = base + Vector3.new(0, bobOffset, 0)
	local frame = CFrame.lookAt(point, point + Vector3.new(0, -1, 0), UP_HINT)
	for _, arm in ipairs(self._arms) do
		arm.part.CFrame = frame * arm.offset
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
	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
	self._arms = {}
end

return ArrowIndicator
