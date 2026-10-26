--[[
	TypingWorkerClient
	Placeholder motion for the second floor's office workers.

	Purely cosmetic and client-side, so it costs no network traffic. Two kinds:
	  * TypingWorker  (cubicles, senior desks, manager): arms reach toward the
	    keyboard and tap up and down.
	  * TalkingWorker (meeting room): arms rest on the table; now and then one
	    hand lifts to gesture, and the head turns around the table as if
	    following the discussion.
	Workers far from the camera are skipped. Seated poses (hips/knees) are set on
	the server and are left alone here; only shoulders and neck move.

	To swap in real animations later, play them on each worker's Animator
	instead and delete this script.

	If the arms swing backward instead of forward, flip the sign of the arm
	angles for that rig type.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TYPING_TAG = "TypingWorker" -- must match SecondFloorConfig.TypingWorkerTag
local TALKING_TAG = "TalkingWorker" -- must match SecondFloorConfig.TalkingWorkerTag
local MAX_ANIMATE_DISTANCE = 120

-- Typing
local ARM_RAISE_DEGREES = 70 -- how far the arms reach forward toward the keyboard
local TAP_DEGREES = 6 -- size of the up/down typing tap
local TAP_SPEED = 12 -- taps per second, roughly divided by 2*pi

-- Talking
local REST_ARM_DEGREES = 35 -- forearms resting toward the table
local GESTURE_DEGREES = 50 -- extra lift while gesturing
local GESTURE_SPEED = 0.7 -- how often a gesture comes round
local HEAD_TURN_DEGREES = 25 -- looking around the table
local HEAD_TURN_SPEED = 0.35

-- Joint names and rotations, per rig type.
local RIGS = {
	R15 = {
		right = "RightShoulder",
		left = "LeftShoulder",
		neck = "Neck",
		arm = function(baseC0, angle, _isLeft)
			return baseC0 * CFrame.Angles(angle, 0, 0)
		end,
		head = function(baseC0, yaw)
			return baseC0 * CFrame.Angles(0, yaw, 0)
		end,
	},
	R6 = {
		right = "Right Shoulder",
		left = "Left Shoulder",
		neck = "Neck",
		arm = function(baseC0, angle, isLeft)
			return baseC0 * CFrame.Angles(0, 0, isLeft and -angle or angle)
		end,
		head = function(baseC0, yaw)
			return baseC0 * CFrame.Angles(0, 0, yaw)
		end,
	},
}

local workers = {} -- [model] = { kind, phase, rig?, joints? }

local function findMotor(model, name)
	local motor = model:FindFirstChild(name, true)
	return motor and motor:IsA("Motor6D") and motor or nil
end

-- C0 values are captured before this script changes them; the server never
-- touches shoulders or neck.
local function findJoints(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil
	end
	local rig = humanoid.RigType == Enum.HumanoidRigType.R15 and RIGS.R15 or RIGS.R6
	local right = findMotor(model, rig.right)
	local left = findMotor(model, rig.left)
	if not (right and left) then
		return nil, nil
	end
	local neck = findMotor(model, rig.neck)
	return rig, {
		right = { motor = right, baseC0 = right.C0 },
		left = { motor = left, baseC0 = left.C0 },
		neck = neck and { motor = neck, baseC0 = neck.C0 } or nil,
	}
end

local function jointsAlive(joints)
	return joints ~= nil and joints.right.motor.Parent ~= nil and joints.left.motor.Parent ~= nil
end

local function track(model, kind)
	if workers[model] == nil then
		workers[model] = { kind = kind, phase = math.random() * math.pi * 2 }
	end
end

local function untrack(model)
	workers[model] = nil
end

for _, entry in ipairs({ { TYPING_TAG, "Typing" }, { TALKING_TAG, "Talking" } }) do
	local tag, kind = entry[1], entry[2]
	for _, model in ipairs(CollectionService:GetTagged(tag)) do
		track(model, kind)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		track(model, kind)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
end

local function animateTyping(entry, now)
	local joints, rig = entry.joints, entry.rig
	for _, side in ipairs({ "right", "left" }) do
		local isLeft = side == "left"
		local joint = joints[side]
		local tap = math.sin(now * TAP_SPEED + entry.phase + (isLeft and math.pi or 0))
		local angle = math.rad(ARM_RAISE_DEGREES + TAP_DEGREES * tap)
		joint.motor.C0 = rig.arm(joint.baseC0, angle, isLeft)
	end
end

local function animateTalking(entry, now)
	local joints, rig = entry.joints, entry.rig
	-- A gesture is a smooth bump that comes round every few seconds, with a
	-- little hand wobble while it lasts.
	local wave = math.max(0, math.sin(now * GESTURE_SPEED + entry.phase))
	local bump = wave ^ 4
	local wobble = math.sin(now * 6 + entry.phase) * 8 * bump
	local rightAngle = math.rad(REST_ARM_DEGREES + GESTURE_DEGREES * bump + wobble)
	local leftAngle = math.rad(REST_ARM_DEGREES)
	joints.right.motor.C0 = rig.arm(joints.right.baseC0, rightAngle, false)
	joints.left.motor.C0 = rig.arm(joints.left.baseC0, leftAngle, true)

	if joints.neck then
		local yaw = math.rad(HEAD_TURN_DEGREES * math.sin(now * HEAD_TURN_SPEED + entry.phase * 1.7))
		joints.neck.motor.C0 = rig.head(joints.neck.baseC0, yaw)
	end
end

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local now = os.clock()

	for model, entry in pairs(workers) do
		if not model.Parent then
			workers[model] = nil
		else
			-- Joints can arrive late or be replaced when streaming; find them lazily.
			if not jointsAlive(entry.joints) then
				entry.rig, entry.joints = findJoints(model)
			end

			local root = model:FindFirstChild("HumanoidRootPart")
			if entry.joints and root and (root.Position - cameraPosition).Magnitude <= MAX_ANIMATE_DISTANCE then
				if entry.kind == "Talking" then
					animateTalking(entry, now)
				else
					animateTyping(entry, now)
				end
			end
		end
	end
end)
