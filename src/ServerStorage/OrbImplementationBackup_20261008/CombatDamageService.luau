--!strict
-- Shared server damage and temporary ragdoll behavior for Avatar weapons.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CombatDamageService = {}
local RAGDOLL_SECONDS = 1.25
local DEFAULT_HORIZONTAL_KNOCKBACK = 184
local DEFAULT_VERTICAL_KNOCKBACK = 52
local DEFAULT_ANGULAR_KNOCKBACK = 28
type PartCollisionState = {
	part: BasePart,
	canCollide: boolean,
}

type RagdollState = {
	humanoid: Humanoid,
	root: BasePart?,
	networkOwnershipChanged: boolean,
	joints: { Instance },
	temporaryInstances: { Instance },
	collisionStates: { PartCollisionState },
	autoRotate: boolean,
	platformStand: boolean,
	token: number,
}


local ragdollStates: { [Model]: RagdollState } = {}
local function shouldRagdollMotor(character: Model, motor: Motor6D): boolean
	local part0 = motor.Part0
	local part1 = motor.Part1
	if not motor.Enabled
		or not part0
		or not part1
		or motor.Name == "RootJoint"
		or motor.Name == "Root"
		or motor.Name == "Neck"
	then
		return false
	end

	return part0:IsDescendantOf(character)
		and part1:IsDescendantOf(character)
		and part0:FindFirstAncestorOfClass("Tool") == nil
		and part1:FindFirstAncestorOfClass("Tool") == nil
end

local function shouldRagdollAnimationConstraint(
	character: Model,
	constraint: AnimationConstraint
): boolean
	local attachment0 = constraint.Attachment0
	local attachment1 = constraint.Attachment1
	local part0 = attachment0 and attachment0.Parent
	local part1 = attachment1 and attachment1.Parent
	if not constraint.Enabled
		or not attachment0
		or not attachment1
		or not part0
		or not part0:IsA("BasePart")
		or not part1
		or not part1:IsA("BasePart")
		or constraint.Name == "RootJoint"
		or constraint.Name == "Root"
		or constraint.Name == "Neck"
	then
		return false
	end

	return part0:IsDescendantOf(character)
		and part1:IsDescendantOf(character)
		and part0:FindFirstAncestorOfClass("Tool") == nil
		and part1:FindFirstAncestorOfClass("Tool") == nil
end

local function createRagdollSocket(
	state: RagdollState,
	attachment0: Attachment,
	attachment1: Attachment,
	part0: BasePart,
	part1: BasePart
)
	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "KnockbackRagdollSocket"
	socket.Attachment0 = attachment0
	socket.Attachment1 = attachment1
	socket.LimitsEnabled = true
	socket.UpperAngle = 75
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -45
	socket.TwistUpperAngle = 45
	socket.Parent = part0

	local noCollision = Instance.new("NoCollisionConstraint")
	noCollision.Name = "KnockbackRagdollNoCollision"
	noCollision.Part0 = part0
	noCollision.Part1 = part1
	noCollision.Parent = part0

	table.insert(state.temporaryInstances, socket)
	table.insert(state.temporaryInstances, noCollision)
end

local function restoreRagdoll(character: Model, token: number)
	local state = ragdollStates[character]
	if not state or state.token ~= token then
		return
	end
	ragdollStates[character] = nil

	for _, joint in ipairs(state.joints) do
		if joint.Parent then
			if joint:IsA("Motor6D") then
				joint.Enabled = true
			elseif joint:IsA("AnimationConstraint") then
				joint.Enabled = true
			end
		end
	end
	for _, instance in ipairs(state.temporaryInstances) do
		if instance.Parent then
			instance:Destroy()
		end
	end
	for _, collisionState in ipairs(state.collisionStates) do
		if collisionState.part.Parent then
			collisionState.part.CanCollide = collisionState.canCollide
		end
	end

	local humanoid = state.humanoid
	if humanoid.Parent and humanoid.Health > 0 then
		humanoid.AutoRotate = state.autoRotate
		humanoid.PlatformStand = state.platformStand
		if not state.platformStand then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

	if state.networkOwnershipChanged and state.root and state.root.Parent then
		pcall(function()
			state.root:SetNetworkOwnershipAuto()
		end)
	end
end

local function startTemporaryRagdoll(character: Model, humanoid: Humanoid, duration: number)
	if humanoid.Health <= 0 then
		return
	end

	local existing = ragdollStates[character]
	if existing then
		existing.token += 1
		local extendedToken = existing.token
		task.delay(duration, function()
			restoreRagdoll(character, extendedToken)
		end)
		return
	end

	local rootInstance = character:FindFirstChild("HumanoidRootPart")
	local ragdollRoot = if rootInstance and rootInstance:IsA("BasePart") then rootInstance else nil
	local networkOwnershipChanged = false
	if ragdollRoot then
		local checked, canSetOwnership = pcall(function()
			return ragdollRoot:CanSetNetworkOwnership()
		end)
		if checked and canSetOwnership then
			networkOwnershipChanged = pcall(function()
				ragdollRoot:SetNetworkOwner(nil)
			end)
		end
	end

	local state: RagdollState = {
		humanoid = humanoid,
		root = ragdollRoot,
		networkOwnershipChanged = networkOwnershipChanged,
		joints = {},
		temporaryInstances = {},
		collisionStates = {},
		autoRotate = humanoid.AutoRotate,
		platformStand = humanoid.PlatformStand,
		token = 1,
	}
	ragdollStates[character] = state

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and shouldRagdollMotor(character, descendant) then
			local part0 = descendant.Part0 :: BasePart
			local part1 = descendant.Part1 :: BasePart

			local attachment0 = Instance.new("Attachment")
			attachment0.Name = "KnockbackRagdollAttachment0"
			attachment0.CFrame = descendant.C0
			attachment0.Parent = part0

			local attachment1 = Instance.new("Attachment")
			attachment1.Name = "KnockbackRagdollAttachment1"
			attachment1.CFrame = descendant.C1
			attachment1.Parent = part1

			createRagdollSocket(state, attachment0, attachment1, part0, part1)
			table.insert(state.joints, descendant)
			table.insert(state.temporaryInstances, attachment0)
			table.insert(state.temporaryInstances, attachment1)
			descendant.Enabled = false
		elseif descendant:IsA("AnimationConstraint")
			and shouldRagdollAnimationConstraint(character, descendant)
		then
			local attachment0 = descendant.Attachment0 :: Attachment
			local attachment1 = descendant.Attachment1 :: Attachment
			local part0 = attachment0.Parent :: BasePart
			local part1 = attachment1.Parent :: BasePart

			createRagdollSocket(state, attachment0, attachment1, part0, part1)
			table.insert(state.joints, descendant)
			descendant.Enabled = false
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant.Name ~= "HumanoidRootPart"
			and descendant:FindFirstAncestorOfClass("Tool") == nil
			and descendant:FindFirstAncestorOfClass("Accessory") == nil
		then
			table.insert(state.collisionStates, {
				part = descendant,
				canCollide = descendant.CanCollide,
			})
			descendant.CanCollide = true
		end
	end

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local token = state.token
	task.delay(duration, function()
		restoreRagdoll(character, token)
	end)
end


function CombatDamageService.ValidateTarget(player: Player, character: Model): (Humanoid?, BasePart?)
	local targetPlayer = Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not targetPlayer or targetPlayer == player or targetPlayer.Character ~= character
		or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart")
		or character:FindFirstChildOfClass("ForceField") then
		return nil, nil
	end
	return humanoid, root
end

function CombatDamageService.ApplyHit(player: Player, tool: Tool, targetHumanoid: Humanoid,
	targetRoot: BasePart, origin: Vector3, forward: Vector3, right: Vector3, damageAmount: number): boolean
	local targetCharacter = targetHumanoid.Parent
	if not targetCharacter or not targetCharacter:IsA("Model") then return false end
	local validHumanoid, validRoot = CombatDamageService.ValidateTarget(player, targetCharacter)
	if validHumanoid ~= targetHumanoid or validRoot ~= targetRoot
		or damageAmount ~= damageAmount or damageAmount <= 0 or damageAmount == math.huge then return false end
	local horizontalKnockback = math.clamp(
		tonumber(tool:GetAttribute("HorizontalKnockback")) or DEFAULT_HORIZONTAL_KNOCKBACK,
		0,
		200
	)
	local verticalKnockback = math.clamp(
		tonumber(tool:GetAttribute("VerticalKnockback")) or DEFAULT_VERTICAL_KNOCKBACK,
		0,
		75
	)
	local angularKnockback = math.clamp(
		tonumber(tool:GetAttribute("AngularKnockback")) or DEFAULT_ANGULAR_KNOCKBACK,
		0,
		60
	)
	local ragdollSeconds = math.clamp(tonumber(tool:GetAttribute("RagdollSeconds")) or RAGDOLL_SECONDS, 0.25, 3)

	local horizontal = Vector3.new(
		targetRoot.Position.X - origin.X,
		0,
		targetRoot.Position.Z - origin.Z
	)
	if horizontal.Magnitude <= 0.01 then
		horizontal = Vector3.new(forward.X, 0, forward.Z)
	end
	if horizontal.Magnitude <= 0.01 then
		horizontal = Vector3.new(0, 0, -1)
	end
	horizontal = horizontal.Unit

	targetHumanoid:TakeDamage(damageAmount)
	startTemporaryRagdoll(targetCharacter, targetHumanoid, ragdollSeconds)

	-- Wait until the ragdoll constraints and server network ownership are active.
	-- Setting assembly velocity directly prevents the target client or Humanoid
	-- state transition from cancelling a same-frame impulse.
	RunService.Heartbeat:Wait()
	if targetRoot.Parent and targetHumanoid.Health > 0 then
		targetRoot.AssemblyLinearVelocity =
			horizontal * horizontalKnockback + Vector3.yAxis * verticalKnockback
		targetRoot.AssemblyAngularVelocity = right * angularKnockback
	end
	return true
end

return CombatDamageService

