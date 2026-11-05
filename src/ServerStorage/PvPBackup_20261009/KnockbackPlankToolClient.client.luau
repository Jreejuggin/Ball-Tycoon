--!strict
-- Quick full-body forward flick for the Knockback Plank.
-- The client animates only presentation. The server still chooses the target,
-- calculates damage, enforces cooldowns, and applies knockback.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local tool = script.Parent :: Tool
local handle = tool:WaitForChild("Handle") :: BasePart
local blade = tool:WaitForChild("Blade_Wood") :: BasePart
local swingEvent = tool:WaitForChild("SwingEvent") :: RemoteEvent

local COOLDOWN_SECONDS = 0.65
local WINDUP_SECONDS = 0.10
local STRIKE_SECONDS = 0.09
local FOLLOW_THROUGH_SECONDS = 0.12
local RECOVERY_SECONDS = 0.18
local CONTACT_FRACTION = 0.72

type RigJoints = {
	character: Model,
	grip: JointInstance,
	shoulder: Instance?,
	torso: Instance?,
	baseGrip: CFrame,
	baseShoulder: CFrame?,
	baseTorso: CFrame?,
}

type Pose = {
	grip: CFrame,
	shoulder: CFrame?,
	torso: CFrame?,
}

local lastSwingAt = 0
local swinging = false
local swingToken = 0
local activeRig: RigJoints? = nil

local function findAnimatedJoint(character: Model, names: { [string]: boolean }): Instance?
	for _, descendant in ipairs(character:GetDescendants()) do
		if (descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint"))
			and names[descendant.Name]
		then
			return descendant
		end
	end
	return nil
end

local function getJointCFrame(joint: Instance?): CFrame?
	if not joint then
		return nil
	end
	if joint:IsA("Motor6D") then
		return joint.C0
	end
	if joint:IsA("AnimationConstraint") then
		return joint.Transform
	end
	return nil
end

local function setJointCFrame(joint: Instance?, value: CFrame?)
	if not joint or not value or not joint.Parent then
		return
	end
	if joint:IsA("Motor6D") then
		joint.C0 = value
	elseif joint:IsA("AnimationConstraint") then
		joint.Transform = value
	end
end

local function findRig(): RigJoints?
	local character = tool.Parent
	if not character or not character:IsA("Model") then
		return nil
	end

	local grip: JointInstance? = nil
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("JointInstance")
			and descendant.Name == "RightGrip"
			and descendant.Part1 == handle
		then
			grip = descendant
			break
		end
	end
	if not grip then
		return nil
	end

	local shoulder = findAnimatedJoint(character, {
		RightShoulder = true,
		["Right Shoulder"] = true,
	})
	-- R15 turns at Waist; R6 falls back to RootJoint/Root.
	local torso = findAnimatedJoint(character, { Waist = true })
		or findAnimatedJoint(character, { RootJoint = true, Root = true })

	return {
		character = character,
		grip = grip,
		shoulder = shoulder,
		torso = torso,
		baseGrip = grip.C0,
		baseShoulder = getJointCFrame(shoulder),
		baseTorso = getJointCFrame(torso),
	}
end

local function makePose(
	rig: RigJoints,
	gripOffset: CFrame,
	shoulderOffset: CFrame,
	torsoOffset: CFrame
): Pose
	return {
		grip = rig.baseGrip * gripOffset,
		shoulder = rig.baseShoulder and (rig.baseShoulder * shoulderOffset) or nil,
		torso = rig.baseTorso and (rig.baseTorso * torsoOffset) or nil,
	}
end

local function applyPose(rig: RigJoints, pose: Pose)
	if rig.grip.Parent then
		rig.grip.C0 = pose.grip
	end
	setJointCFrame(rig.shoulder, pose.shoulder)
	setJointCFrame(rig.torso, pose.torso)
end

local function restoreRig()
	local rig = activeRig
	if not rig then
		return
	end

	if rig.grip.Parent then
		rig.grip.C0 = rig.baseGrip
	end
	setJointCFrame(rig.shoulder, rig.baseShoulder)
	setJointCFrame(rig.torso, rig.baseTorso)
	activeRig = nil
end

local function lerpOptional(from: CFrame?, to: CFrame?, alpha: number): CFrame?
	if from and to then
		return from:Lerp(to, alpha)
	end
	return to or from
end

local function animatePhase(
	rig: RigJoints,
	fromPose: Pose,
	toPose: Pose,
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	token: number,
	onProgress: ((number) -> ())?
): boolean
	local startedAt = os.clock()
	while true do
		if token ~= swingToken
			or not rig.grip.Parent
			or tool.Parent ~= rig.character
		then
			return false
		end

		local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
		local eased = TweenService:GetValue(alpha, style, direction)
		applyPose(rig, {
			grip = fromPose.grip:Lerp(toPose.grip, eased),
			shoulder = lerpOptional(fromPose.shoulder, toPose.shoulder, eased),
			torso = lerpOptional(fromPose.torso, toPose.torso, eased),
		})
		if onProgress then
			onProgress(alpha)
		end
		if alpha >= 1 then
			break
		end
		RunService.PreSimulation:Wait()
	end
	return true
end

local function alignBladeHorizontal(rig: RigJoints)
	local hand = rig.grip.Part0
	local root = rig.character:FindFirstChild("HumanoidRootPart")
	if not hand or not root or not root:IsA("BasePart") then
		return
	end

	-- Predict the welded assembly from the current grip pose, then remove the
	-- blade's vertical tilt in world space. This stays exact even while the
	-- avatar's idle animation changes the arm's local joint basis.
	local bladeFromHandle = handle.CFrame:ToObjectSpace(blade.CFrame)
	local predictedHandle = hand.CFrame * rig.grip.C0 * rig.grip.C1:Inverse()
	local predictedBlade = predictedHandle * bladeFromHandle

	local playerForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if playerForward.Magnitude <= 0.01 then
		playerForward = Vector3.new(0, 0, -1)
	else
		playerForward = playerForward.Unit
	end

	-- Blade_Wood extends away from the handle along one of its two Z-axis
	-- directions. Choose the LookVector sign that puts that physical end in
	-- front of the player instead of merely preserving the previous rotation.
	local bladeEndUsesLookVector = bladeFromHandle.Position:Dot(bladeFromHandle.LookVector) >= 0
	local desiredBladeLook = bladeEndUsesLookVector and playerForward or -playerForward
	local horizontalBlade = CFrame.lookAt(
		predictedBlade.Position,
		predictedBlade.Position + desiredBladeLook,
		Vector3.yAxis
	)
	-- Rotate around the hand/handle, not the blade's centre, so the weapon
	-- stays firmly in the player's grip while its long axis levels out.
	local desiredHandleRotation = horizontalBlade.Rotation * bladeFromHandle.Rotation:Inverse()
	local desiredHandle = CFrame.new(predictedHandle.Position) * desiredHandleRotation
	rig.grip.C0 = hand.CFrame:ToObjectSpace(desiredHandle) * rig.grip.C1
end

local function playSwing(token: number)
	local rig = findRig()
	if not rig then
		-- Preserve combat if Roblox has not created the grip joint yet.
		swingEvent:FireServer()
		swinging = false
		return
	end
	activeRig = rig

	local basePose: Pose = {
		grip = rig.baseGrip,
		shoulder = rig.baseShoulder,
		torso = rig.baseTorso,
	}

	-- Pull back by rotation only. Keeping the grip's position unchanged
	-- prevents the handle from sliding or popping out of the player's hand.
	local windupPose = makePose(
		rig,
		CFrame.Angles(math.rad(14), 0, math.rad(-3)),
		CFrame.identity,
		CFrame.identity
	)

	-- Flick the plank forward around the fixed hand position. The shoulder
	-- lowers only slightly while the torso remains on its existing animation.
	local contactPose = makePose(
		rig,
		CFrame.Angles(math.rad(-90), 0, 0),
		CFrame.Angles(math.rad(8), 0, 0),
		CFrame.identity
	)

	-- Hold the forward blade while the arm settles a touch farther downward.
	local followPose = makePose(
		rig,
		CFrame.Angles(math.rad(-90), 0, 0),
		CFrame.Angles(math.rad(10), 0, 0),
		CFrame.identity
	)

	if not animatePhase(
		rig,
		basePose,
		windupPose,
		WINDUP_SECONDS,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		token,
		nil
	) then
		restoreRig()
		swinging = false
		return
	end

	local contactSent = false
	if not animatePhase(
		rig,
		windupPose,
		contactPose,
		STRIKE_SECONDS,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.In,
		token,
		function(alpha: number)
			if alpha >= CONTACT_FRACTION then
				alignBladeHorizontal(rig)
			end
			if not contactSent and alpha >= CONTACT_FRACTION then
				contactSent = true
				swingEvent:FireServer()
			end
		end
	) then
		restoreRig()
		swinging = false
		return
	end

	if not contactSent then
		contactSent = true
		swingEvent:FireServer()
	end

	if not animatePhase(
		rig,
		contactPose,
		followPose,
		FOLLOW_THROUGH_SECONDS,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		token,
		function()
			alignBladeHorizontal(rig)
		end
	) then
		restoreRig()
		swinging = false
		return
	end

	-- Recover from the corrected world-horizontal grip without a visible snap.
	followPose.grip = rig.grip.C0
	animatePhase(
		rig,
		followPose,
		basePose,
		RECOVERY_SECONDS,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		token,
		nil
	)

	if token == swingToken then
		restoreRig()
		swinging = false
	end
end

tool.Activated:Connect(function()
	local now = os.clock()
	if swinging or now - lastSwingAt < COOLDOWN_SECONDS then
		return
	end

	lastSwingAt = now
	swinging = true
	swingToken += 1
	local token = swingToken
	task.spawn(playSwing, token)
end)

tool.Unequipped:Connect(function()
	swingToken += 1
	restoreRig()
	swinging = false
end)
