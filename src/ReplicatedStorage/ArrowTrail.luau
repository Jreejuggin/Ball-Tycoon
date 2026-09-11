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
-- Ground-height note: this used to find the floor by raycasting straight
-- down under each chevron -- which meant the trail happily climbed onto the
-- top of whatever it raycast into: a dropper, a buy pad, an invisible
-- collision box, anything sitting between the player and the target. Since
-- every tutorial target lives on the player's OWN plot (see TutorialConfig),
-- and that plot's own floor is a single flat part (the same one
-- PlotAssignmentScript already uses for teleport placement:
-- `plot.PrimaryPart or plot:FindFirstChild("Floor")`), the trail just reads
-- that one part's top height directly instead. It structurally cannot climb
-- onto a dropper or a button, because it never looks at them -- there's
-- nothing left in the geometry that COULD hit an obstacle.
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
	self._pathValid = false

	self._folder = Instance.new("Folder")
	self._folder.Name = "TutorialArrowTrail"
	self._folder.Parent = workspace

	local offsets = armOffsets()
	self._chevrons = {}
	-- Each chevron's OWN distance along the path, persistent frame to frame
	-- -- see the big comment on _advanceChevron below for why this replaced
	-- a single shared scroll value.
	self._chevronDistances = {}
	for index = 1, self._chevronCount do
		local arms = {}
		for armIndex, offset in ipairs(offsets) do
			local arm = Instance.new("Part")
			arm.Name = string.format("Chevron%dArm%d", index, armIndex)
			arm.Anchored = true
			arm.CanCollide = false
			arm.CanTouch = false
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
		self._chevronDistances[index] = (index - 1) * self._spacing
	end

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

-- The top surface height of the player's OWN plot floor -- the same part
-- PlotAssignmentScript resolves for teleport placement -- or nil if it
-- can't be found (no plot assigned yet, or an unexpected plot layout).
-- Deliberately doesn't look at anything else in the plot: a dropper, a buy
-- pad, or any other structure between the player and the target is simply
-- never queried, so there's nothing here that could climb onto one.
function ArrowTrail:_resolveFloorHeight()
	local plotName = self._player:GetAttribute("AssignedPlotName")
	if type(plotName) ~= "string" then
		return nil
	end
	local plot = workspace:FindFirstChild(plotName)
	if not plot then
		return nil
	end
	local floor = plot.PrimaryPart or plot:FindFirstChild("Floor")
	if not floor or not floor:IsA("BasePart") then
		return nil
	end
	return floor.Position.Y + floor.Size.Y / 2
end

-- Cheap, pure-vector geometry: where the path starts, which way it points,
-- how long it is, and how high its floor sits. Run every frame -- both the
-- player's position and (via SetTarget) the target change continuously
-- while walking, so this must too. An earlier version of this only updated
-- inside a throttled recompute, which caused the trail to visibly snap into
-- a new heading every ~0.1s while walking; resolving the floor plot lookup
-- is cheap enough (an attribute read and a couple of FindFirstChild calls,
-- no raycasts) that it belongs in the same untouched-every-frame bucket,
-- not a separate throttled step.
function ArrowTrail:_updateGeometry()
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

	self._start = playerPosition + direction * START_OFFSET
	self._direction = direction
	self._usableLength = usableLength
	-- No known plot floor (shouldn't normally happen during the tutorial,
	-- but keep the trail usable if it does): fall back to a straight line
	-- between the player's and target's own heights, same as before.
	self._floorHeight = self:_resolveFloorHeight()
	self._playerHeight = playerPosition.Y
	self._targetHeight = targetPosition.Y
	self._pathValid = true
end

function ArrowTrail:_heightAt(distance)
	if self._floorHeight then
		return self._floorHeight + GROUND_OFFSET
	end
	local alpha = 0
	if self._usableLength > 0 then
		alpha = distance / self._usableLength
	end
	return self._playerHeight + (self._targetHeight - self._playerHeight) * alpha + GROUND_OFFSET
end

function ArrowTrail:_step(deltaTime)
	if not self._visible then
		return
	end

	self:_updateGeometry()

	if not self._pathValid then
		self:_hideAll()
		return
	end

	for index, arms in ipairs(self._chevrons) do
		local distance = self:_advanceChevron(index, deltaTime)

		if distance > self._usableLength then
			-- Beyond the current path (a short path with less room than the
			-- full lap, or momentarily between laps): keep it out of the way
			-- entirely rather than cramming it into whatever room exists.
			for _, arm in ipairs(arms) do
				arm.part.Transparency = 1
			end
		else
			local point = self._start + self._direction * distance
			point = Vector3.new(point.X, self:_heightAt(distance), point.Z)

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

-- Advances one chevron's OWN distance along the path and wraps it back to
-- the player end once it completes a lap, and returns that distance.
--
-- Two earlier versions of this both broke in different ways:
--   1. All ten chevrons driven off ONE shared scroll value, each confined
--      to its own fixed SPACING-wide window. They all wrapped at the exact
--      same instant, and only the first/last of those windows sat inside
--      the fade zones, so every middle chevron teleported backward at FULL
--      OPACITY on a fixed rhythm -- regardless of terrain or movement.
--   2. Fixed that by giving each chevron a persistent distance wrapped
--      against the CURRENT usableLength -- which does stop the
--      synchronized teleport, but on a SHORT path (closer to the target
--      than CHEVRON_COUNT*SPACING studs) it forces all ten to cram into
--      that short remaining stretch, landing on only a handful of distinct
--      positions mod a small divisor -- the "pile of arrows" look.
--
-- The fix: wrap against a LAP LENGTH that's whichever is bigger, the
-- current usableLength or the full CHEVRON_COUNT*SPACING extension
-- (=60 studs by default). The ten starting offsets (0, 6, 12, ... 54) are
-- already every distinct multiple of SPACING up to CHEVRON_COUNT*SPACING,
-- so wrapping against that fixed minimum keeps them permanently spread
-- apart with zero collisions, no matter how short the visible path gets --
-- the render loop above just hides whichever ones currently fall beyond
-- usableLength, exactly like the ORIGINAL (pre-redesign) density behavior.
-- On a LONGER path, the lap length grows to match usableLength itself, so
-- each chevron travels the whole path and only ever wraps at the target
-- end, which is already inside the fadeOut zone -- fixing problem 1 for
-- paths of any length, not just ones shorter than the default extension.
function ArrowTrail:_advanceChevron(index, deltaTime)
	local lapLength = math.max(self._usableLength, self._chevronCount * self._spacing)
	local distance = self._chevronDistances[index] + self._scrollSpeed * deltaTime
	if lapLength > 0 then
		distance = distance % lapLength
	end
	self._chevronDistances[index] = distance
	return distance
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
