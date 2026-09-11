-- ArrowTrail
-- A reusable, parts-only 3D "go this way" path: a line of chevrons running
-- from the local player toward a target, flowing target-ward like a conveyor
-- and recomputing as the player moves.
--
-- Shape note (this is the counterpart to the decision in ArrowIndicator):
-- ArrowIndicator only ever points straight DOWN, so it could sidestep
-- rotation entirely with flat, rotation-invariant plates. A trail arrow must
-- point along an arbitrary horizontal direction, so rotation is unavoidable.
-- Rather than rely on a WedgePart's slope convention or a SpecialMesh cone's
-- axis -- neither of which can be verified from outside Studio, and either of
-- which fails silently and backwards -- each chevron is two plain boxes
-- placed with explicit math in a frame this module builds itself via
-- CFrame.lookAt. The two arms are mirror images (+/- the same angle), so even
-- a sign error in the rotation produces the same visible shape.
--
-- Client-only by design: it follows Players.LocalPlayer and drives itself off
-- RenderStepped, and the parts it makes are client-side, so the trail is
-- visible only to the player being tutorialised. Creating one on the server
-- would replicate it to everybody.
--
-- Usage:
--   local trail = ArrowTrail.new(someBuyPad)
--   trail:SetTarget(someOtherModel) -- repoint without rebuilding
--   trail:SetVisible(false)         -- temporarily hide, keeps running
--   trail:Destroy()                 -- disconnect and remove all parts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ArrowTrail = {}
ArrowTrail.__index = ArrowTrail

local CHEVRON_COUNT = 10 -- how many chevrons exist at once
local SPACING = 6 -- studs between consecutive chevrons along the path
local SCROLL_SPEED = 9 -- studs/second the chevrons flow toward the target
local START_OFFSET = 5 -- studs ahead of the player the path begins, so
	-- chevrons never spawn inside the character
local STOP_OFFSET = 3 -- studs short of the target the path ends
local HIDE_WITHIN = 10 -- hide the whole trail once this close to the target
local FADE_STUDS = 6 -- distance over which chevrons fade in/out at each end

local ARM_LENGTH = 1.8
local ARM_THICKNESS = 0.35
local ARM_HEIGHT = 0.25 -- flat slabs, so they read as painted on the ground
local ARM_ANGLE = math.rad(40) -- half-angle of the chevron's "V"
local GROUND_OFFSET = 0.6 -- studs above the floor the chevrons float

local RECOMPUTE_INTERVAL = 0.1 -- seconds between path/ground recomputes
local RECOMPUTE_MOVE_THRESHOLD = 2 -- studs of player or target movement that
	-- forces an immediate recompute regardless of the interval

local GROUND_SAMPLE_SPACING = 4 -- studs between downward ground raycasts
local MAX_GROUND_SAMPLES = 64
local RAY_UP = 8 -- start each ground ray this far above the sample point
local RAY_DOWN = 60 -- and cast this far down from there

local TRAIL_COLOR = Color3.fromRGB(255, 221, 64)

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Both arms of one chevron, as offsets from a chevron-local frame whose
-- origin is the point of the "V" and whose LookVector is the direction of
-- travel. CFrame.lookAt makes -Z the forward axis, so pushing an arm to +Z
-- trails it BEHIND the point, which is what an arrowhead looks like.
local function armOffsets()
	local offsets = {}
	for _, sign in ipairs({ 1, -1 }) do
		table.insert(offsets, CFrame.Angles(0, sign * ARM_ANGLE, 0) * CFrame.new(0, 0, ARM_LENGTH / 2))
	end
	return offsets
end

function ArrowTrail.new(target, options)
	assert(RunService:IsClient(), "ArrowTrail is client-only; create it from a LocalScript")

	options = options or {}
	local self = setmetatable({}, ArrowTrail)

	self._color = options.color or TRAIL_COLOR
	self._chevronCount = options.chevronCount or CHEVRON_COUNT
	self._spacing = options.spacing or SPACING
	self._scrollSpeed = options.scrollSpeed or SCROLL_SPEED

	self._player = Players.LocalPlayer
	self._visible = true
	self._scroll = 0
	self._timeSinceRecompute = math.huge -- force a recompute on the first frame
	self._pathValid = false
	self._lastStart = nil
	self._lastFinish = nil
	self._groundHeights = {}
	self._groundStep = GROUND_SAMPLE_SPACING

	self._folder = Instance.new("Folder")
	self._folder.Name = "TutorialArrowTrail"
	self._folder.Parent = workspace

	local offsets = armOffsets()
	self._chevrons = {}
	for index = 1, self._chevronCount do
		local arms = {}
		for armIndex, offset in ipairs(offsets) do
			local arm = Instance.new("Part")
			arm.Name = string.format("Chevron%dArm%d", index, armIndex)
			arm.Anchored = true
			arm.CanCollide = false
			arm.CanTouch = false
			-- CanQuery = false also keeps the trail out of its own ground rays.
			arm.CanQuery = false
			arm.CastShadow = false
			arm.Material = Enum.Material.Neon
			arm.Color = self._color
			arm.Size = Vector3.new(ARM_THICKNESS, ARM_HEIGHT, ARM_LENGTH)
			arm.Transparency = 1
			arm.Parent = self._folder
			table.insert(arms, { part = arm, offset = offset })
		end
		table.insert(self._chevrons, arms)
	end

	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self._rayParams.IgnoreWater = true
	self._rayParams.FilterDescendantsInstances = {}

	self:SetTarget(target)

	self._renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		self:_step(deltaTime)
	end)

	return self
end

-- Repoints the same trail at a different target instead of rebuilding it --
-- the tutorial controller reuses one ArrowTrail across every step this way.
function ArrowTrail:SetTarget(target)
	assert(target ~= nil, "ArrowTrail target cannot be nil")
	assert(typeof(target.GetPivot) == "function", "ArrowTrail target must support GetPivot (a BasePart or Model)")
	self._target = target
	self._timeSinceRecompute = math.huge
end

function ArrowTrail:SetVisible(visible)
	self._visible = visible and true or false
	if not self._visible then
		self:_hideAll()
	end
end

function ArrowTrail:_hideAll()
	for _, arms in ipairs(self._chevrons) do
		for _, arm in ipairs(arms) do
			arm.part.Transparency = 1
		end
	end
end

function ArrowTrail:_characterRoot()
	local character = self._player.Character
	if not character or not character.Parent then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Samples the floor height at regular intervals along the path once, so the
-- per-frame update can interpolate a height for any distance without
-- raycasting every chevron every frame.
function ArrowTrail:_sampleGround(startPosition, direction, length, finishHeight)
	local sampleCount = math.clamp(math.ceil(length / GROUND_SAMPLE_SPACING) + 1, 2, MAX_GROUND_SAMPLES)
	local step = length / (sampleCount - 1)

	local character = self._player.Character
	self._rayParams.FilterDescendantsInstances = character and { character } or {}

	local heights = {}
	for index = 1, sampleCount do
		local distance = (index - 1) * step
		local point = startPosition + direction * distance
		local origin = Vector3.new(point.X, point.Y + RAY_UP, point.Z)
		local result = workspace:Raycast(origin, Vector3.new(0, -(RAY_UP + RAY_DOWN), 0), self._rayParams)
		if result then
			heights[index] = result.Position.Y + GROUND_OFFSET
		else
			-- No floor found (a gap, or the area isn't streamed in yet): fall
			-- back to the straight line between the two endpoints.
			local alpha = 0
			if length > 0 then
				alpha = distance / length
			end
			local lineHeight = startPosition.Y + (finishHeight - startPosition.Y) * alpha
			heights[index] = lineHeight + GROUND_OFFSET
		end
	end

	self._groundHeights = heights
	self._groundStep = step
end

function ArrowTrail:_heightAt(distance)
	local heights = self._groundHeights
	local count = #heights
	if count == 0 then
		return nil
	end
	if count == 1 or self._groundStep <= 0 then
		return heights[1]
	end

	local position = distance / self._groundStep
	local lower = math.clamp(math.floor(position) + 1, 1, count)
	local upper = math.clamp(lower + 1, 1, count)
	local alpha = math.clamp(position - (lower - 1), 0, 1)
	return heights[lower] + (heights[upper] - heights[lower]) * alpha
end

function ArrowTrail:_recomputePath()
	self._pathValid = false

	local root = self:_characterRoot()
	if not root then
		return
	end
	local target = self._target
	if not target or not target.Parent then
		-- Target destroyed, or streamed out on this client.
		return
	end

	local playerPosition = root.Position
	local targetPosition = target:GetPivot().Position
	self._lastStart = playerPosition
	self._lastFinish = targetPosition

	local flatDelta = flatten(targetPosition - playerPosition)
	local groundDistance = flatDelta.Magnitude
	if groundDistance < HIDE_WITHIN then
		-- Close enough that the trail would pile up on top of the player.
		return
	end

	local direction = flatDelta.Unit
	local usableLength = groundDistance - START_OFFSET - STOP_OFFSET
	if usableLength <= 0 then
		return
	end

	local startPosition = playerPosition + direction * START_OFFSET
	self:_sampleGround(startPosition, direction, usableLength, targetPosition.Y)

	self._start = startPosition
	self._direction = direction
	self._usableLength = usableLength
	self._pathValid = true
end

function ArrowTrail:_step(deltaTime)
	if not self._visible then
		return
	end

	self._timeSinceRecompute += deltaTime

	local needsRecompute = self._timeSinceRecompute >= RECOMPUTE_INTERVAL
	if not needsRecompute and self._lastStart then
		local root = self:_characterRoot()
		if not root or (root.Position - self._lastStart).Magnitude > RECOMPUTE_MOVE_THRESHOLD then
			needsRecompute = true
		end
	end
	if not needsRecompute and self._lastFinish then
		local target = self._target
		if not target or not target.Parent then
			needsRecompute = true
		elseif (target:GetPivot().Position - self._lastFinish).Magnitude > RECOMPUTE_MOVE_THRESHOLD then
			needsRecompute = true
		end
	end

	if needsRecompute then
		self._timeSinceRecompute = 0
		self:_recomputePath()
	end

	if not self._pathValid then
		self:_hideAll()
		return
	end

	-- One scroll cycle is exactly one spacing, so the chevron that runs off
	-- the target end is replaced by a new one at the player end and the chain
	-- reads as continuous.
	self._scroll = (self._scroll + self._scrollSpeed * deltaTime) % self._spacing

	for index, arms in ipairs(self._chevrons) do
		local distance = self._scroll + (index - 1) * self._spacing
		if distance > self._usableLength then
			for _, arm in ipairs(arms) do
				arm.part.Transparency = 1
			end
		else
			local height = self:_heightAt(distance)
			local point = self._start + self._direction * distance
			if height then
				point = Vector3.new(point.X, height, point.Z)
			end

			local frame = CFrame.lookAt(point, point + self._direction)
			local fadeIn = math.clamp(distance / FADE_STUDS, 0, 1)
			local fadeOut = math.clamp((self._usableLength - distance) / FADE_STUDS, 0, 1)
			local transparency = 1 - math.min(fadeIn, fadeOut)

			for _, arm in ipairs(arms) do
				arm.part.CFrame = frame * arm.offset
				arm.part.Transparency = transparency
			end
		end
	end
end

function ArrowTrail:Destroy()
	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end
	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
	self._chevrons = {}
	self._pathValid = false
end

return ArrowTrail
