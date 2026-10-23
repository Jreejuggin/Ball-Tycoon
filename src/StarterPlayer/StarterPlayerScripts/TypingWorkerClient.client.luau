--[[
	TypingWorkerClient
	Placeholder "typing" motion for the second floor's computer workers.

	Purely cosmetic and client-side, so it costs no network traffic: it raises
	each worker's arms toward the keyboard and taps them up and down. Workers far
	from the camera are skipped.

	To swap in a real typing animation later, play it on the worker's Animator
	instead and delete this script.

	If the arms swing backward instead of forward, flip the sign of
	ARM_RAISE_DEGREES for that rig type.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG = "TypingWorker" -- must match SecondFloorConfig.TypingWorkerTag
local MAX_ANIMATE_DISTANCE = 120
local ARM_RAISE_DEGREES = 70 -- how far the arms reach forward toward the keyboard
local TAP_DEGREES = 6 -- size of the up/down typing tap
local TAP_SPEED = 12 -- taps per second, roughly divided by 2*pi

-- Shoulder joint names and the rotation that swings an arm forward, per rig type.
local RIGS = {
	R15 = {
		right = "RightShoulder",
		left = "LeftShoulder",
		pose = function(baseC0, angle, _isLeft)
			return baseC0 * CFrame.Angles(angle, 0, 0)
		end,
	},
	R6 = {
		right = "Right Shoulder",
		left = "Left Shoulder",
		pose = function(baseC0, angle, isLeft)
			return baseC0 * CFrame.Angles(0, 0, isLeft and -angle or angle)
		end,
	},
}

local workers = {} -- [model] = { phase = number, rig = table?, joints = table? }

local function findJoints(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil
	end
	local rig = humanoid.RigType == Enum.HumanoidRigType.R15 and RIGS.R15 or RIGS.R6
	local right = model:FindFirstChild(rig.right, true)
	local left = model:FindFirstChild(rig.left, true)
	if not (right and right:IsA("Motor6D") and left and left:IsA("Motor6D")) then
		return nil, nil
	end
	-- C0 is captured before this script changes it; the server never touches it.
	return rig, {
		{ motor = right, baseC0 = right.C0, isLeft = false },
		{ motor = left, baseC0 = left.C0, isLeft = true },
	}
end

local function track(model)
	if workers[model] == nil then
		workers[model] = { phase = math.random() * math.pi * 2 }
	end
end

local function untrack(model)
	workers[model] = nil
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	track(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

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
			local joints = entry.joints
			if not (joints and joints[1].motor.Parent and joints[2].motor.Parent) then
				entry.rig, entry.joints = findJoints(model)
			end

			local root = model:FindFirstChild("HumanoidRootPart")
			if entry.joints and root and (root.Position - cameraPosition).Magnitude <= MAX_ANIMATE_DISTANCE then
				for _, joint in ipairs(entry.joints) do
					local tap = math.sin(now * TAP_SPEED + entry.phase + (joint.isLeft and math.pi or 0))
					local angle = math.rad(ARM_RAISE_DEGREES + TAP_DEGREES * tap)
					joint.motor.C0 = entry.rig.pose(joint.baseC0, angle, joint.isLeft)
				end
			end
		end
	end
end)
