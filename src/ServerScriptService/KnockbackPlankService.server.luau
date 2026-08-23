--!strict
-- Server-authoritative Knockback Plank purchase, persistence, granting, and combat.
-- The client only requests a swing; this service selects and validates the target.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlotTheme = require(ReplicatedStorage:WaitForChild("PlotTheme"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local STATION_NAME = "KnockbackPlankStation"
local TOOL_NAME = "KnockbackPlank"
local PAD_REFRESH_SECONDS = 0.5
local HITBOX_SIZE = Vector3.new(7, 5, 8)
local HITBOX_FORWARD_OFFSET = 3.5
local MAX_TARGET_DISTANCE = 8.5
local RAGDOLL_SECONDS = 1.25
local DEFAULT_HORIZONTAL_KNOCKBACK = 184
local DEFAULT_VERTICAL_KNOCKBACK = 52
local DEFAULT_ANGULAR_KNOCKBACK = 28

local COLOR_GREEN = Color3.fromRGB(30, 255, 75)
local COLOR_RED = Color3.fromRGB(215, 28, 38)
local COLOR_LOCKED = Color3.fromRGB(105, 110, 120)
local COLOR_DARK = Color3.fromRGB(43, 47, 54)
local COLOR_COLUMN = Color3.fromRGB(52, 56, 64)
local COLOR_TOP = Color3.fromRGB(64, 68, 76)

local DISPLAY_STYLE: { [string]: { color: Color3, material: Enum.Material } } = {
	Blade_Wood = { color = Color3.fromRGB(168, 111, 50), material = Enum.Material.Wood },
	Guard_Wood = { color = Color3.fromRGB(168, 111, 50), material = Enum.Material.Wood },
	Pommel_Wood = { color = Color3.fromRGB(168, 111, 50), material = Enum.Material.Wood },
	Grip_Core = { color = Color3.fromRGB(74, 45, 29), material = Enum.Material.Wood },
	Grip_Wrap = { color = Color3.fromRGB(50, 34, 27), material = Enum.Material.Fabric },
	Band_Lower = { color = Color3.fromRGB(87, 81, 74), material = Enum.Material.Metal },
	Band_Upper = { color = Color3.fromRGB(87, 81, 74), material = Enum.Material.Metal },
	Rivets = { color = Color3.fromRGB(87, 81, 74), material = Enum.Material.Metal },
	Accent_Mark = { color = Color3.fromRGB(166, 64, 50), material = Enum.Material.SmoothPlastic },
}

local toolsFolder = ServerStorage:WaitForChild("Tools")
local toolTemplate = toolsFolder:WaitForChild(TOOL_NAME)

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

local refreshers: { () -> () } = {}
local lastOwnerByPlot: { [Instance]: Player } = {}
local lastSwingByPlayer: { [Player]: number } = {}
local wiredTools: { [Tool]: boolean } = setmetatable({}, { __mode = "k" })
local ragdollStates: { [Model]: RagdollState } = {}

local function formatCash(amount: number): string
	local text = tostring(math.max(0, math.floor(amount)))
	while true do
		local updated, replacements = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = updated
		if replacements == 0 then
			break
		end
	end
	return "$" .. text
end

local function getCash(player: Player?): ValueBase?
	local leaderstats = player and player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
		return cash
	end
	return nil
end

local function getToolContainers(player: Player): { Instance }
	local containers: { Instance } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	local starterGear = player:FindFirstChild("StarterGear")
	if backpack then
		table.insert(containers, backpack)
	end
	if starterGear then
		table.insert(containers, starterGear)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end
	return containers
end

local function removeGrantedTools(player: Player)
	for _, container in ipairs(getToolContainers(player)) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child.Name == TOOL_NAME then
				child:Destroy()
			end
		end
	end
end

local function hasToolIn(container: Instance?, toolName: string): boolean
	if not container then
		return false
	end
	local found = container:FindFirstChild(toolName)
	return found ~= nil and found:IsA("Tool")
end

local function hasLineOfSight(attackerCharacter: Model, targetCharacter: Model, origin: Vector3, target: Vector3): boolean
	local direction = target - origin
	if direction.Magnitude <= 0.01 then
		return true
	end

	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { attackerCharacter }
	parameters.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, parameters)
	return result == nil or result.Instance:IsDescendantOf(targetCharacter)
end

local function findSwingTarget(player: Player, character: Model, root: BasePart): (Humanoid?, BasePart?)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	overlap.MaxParts = 80

	local boxCFrame = root.CFrame * CFrame.new(0, 0, -HITBOX_FORWARD_OFFSET)
	local parts = workspace:GetPartBoundsInBox(boxCFrame, HITBOX_SIZE, overlap)
	local seenCharacters: { [Model]: boolean } = {}
	local closestHumanoid: Humanoid? = nil
	local closestRoot: BasePart? = nil
	local closestDistance = math.huge

	for _, part in ipairs(parts) do
		local targetCharacter = part:FindFirstAncestorOfClass("Model")
		if targetCharacter
			and targetCharacter ~= character
			and not seenCharacters[targetCharacter]
		then
			seenCharacters[targetCharacter] = true
			local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
			local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
			local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

			if targetPlayer
				and targetPlayer ~= player
				and targetHumanoid
				and targetHumanoid.Health > 0
				and targetRoot
				and targetRoot:IsA("BasePart")
				and not targetCharacter:FindFirstChildOfClass("ForceField")
			then
				local offset = targetRoot.Position - root.Position
				local distance = offset.Magnitude
				local direction = distance > 0.01 and offset.Unit or root.CFrame.LookVector
				local forwardAmount = direction:Dot(root.CFrame.LookVector)

				if distance <= MAX_TARGET_DISTANCE
					and forwardAmount > 0.05
					and distance < closestDistance
					and hasLineOfSight(character, targetCharacter, root.Position, targetRoot.Position)
				then
					closestDistance = distance
					closestHumanoid = targetHumanoid
					closestRoot = targetRoot
				end
			end
		end
	end

	return closestHumanoid, closestRoot
end

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

local function processSwing(player: Player, tool: Tool)
	if tool.Parent ~= player.Character then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character
		or not humanoid
		or humanoid.Health <= 0
		or not root
		or not root:IsA("BasePart")
	then
		return
	end

	local cooldown = tonumber(tool:GetAttribute("SwingCooldown")) or 0.65
	local now = os.clock()
	local previous = lastSwingByPlayer[player] or 0
	if now - previous < cooldown then
		return
	end
	lastSwingByPlayer[player] = now

	local targetHumanoid, targetRoot = findSwingTarget(player, character, root)
	if not targetHumanoid or not targetRoot then
		return
	end

	local targetCharacter = targetHumanoid.Parent
	if not targetCharacter or not targetCharacter:IsA("Model") then
		return
	end

	local damageFraction = math.clamp(tonumber(tool:GetAttribute("DamageFraction")) or 0.05, 0, 0.25)
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
		targetRoot.Position.X - root.Position.X,
		0,
		targetRoot.Position.Z - root.Position.Z
	)
	if horizontal.Magnitude <= 0.01 then
		horizontal = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	horizontal = horizontal.Unit

	targetHumanoid:TakeDamage(math.max(1, targetHumanoid.MaxHealth * damageFraction))
	startTemporaryRagdoll(targetCharacter, targetHumanoid, ragdollSeconds)

	-- Wait until the ragdoll constraints and server network ownership are active.
	-- Setting assembly velocity directly prevents the target client or Humanoid
	-- state transition from cancelling a same-frame impulse.
	RunService.Heartbeat:Wait()
	if targetRoot.Parent and targetHumanoid.Health > 0 then
		targetRoot.AssemblyLinearVelocity =
			horizontal * horizontalKnockback + Vector3.yAxis * verticalKnockback
		targetRoot.AssemblyAngularVelocity = root.CFrame.RightVector * angularKnockback
	end
end

local function wireCombatTool(instance: Instance, player: Player)
	if not instance:IsA("Tool") or instance.Name ~= TOOL_NAME or wiredTools[instance] then
		return
	end

	local swingEvent = instance:FindFirstChild("SwingEvent")
	if not swingEvent or not swingEvent:IsA("RemoteEvent") then
		warn(("[KnockbackPlankService] %s is missing SwingEvent."):format(instance:GetFullName()))
		return
	end

	wiredTools[instance] = true
	swingEvent.OnServerEvent:Connect(function(firingPlayer: Player)
		if firingPlayer ~= player then
			return
		end
		processSwing(player, instance)
	end)
end

local function configureGrantedTool(tool: Tool, station: Model)
	local config = station:FindFirstChild("Config")
	local damageFraction = config and config:FindFirstChild("DamageFraction")
	local horizontalKnockback = config and config:FindFirstChild("HorizontalKnockback")
	local verticalKnockback = config and config:FindFirstChild("VerticalKnockback")
	local swingCooldown = config and config:FindFirstChild("SwingCooldown")

	tool:SetAttribute("GrantedByKnockbackPlankStation", true)
	tool:SetAttribute("DamageFraction", damageFraction and damageFraction.Value or 0.05)
	tool:SetAttribute(
		"HorizontalKnockback",
		horizontalKnockback and horizontalKnockback.Value or DEFAULT_HORIZONTAL_KNOCKBACK
	)
	tool:SetAttribute(
		"VerticalKnockback",
		verticalKnockback and verticalKnockback.Value or DEFAULT_VERTICAL_KNOCKBACK
	)
	tool:SetAttribute("AngularKnockback", DEFAULT_ANGULAR_KNOCKBACK)
	tool:SetAttribute("SwingCooldown", swingCooldown and swingCooldown.Value or 0.65)
end

local function grantTool(player: Player, station: Model)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local starterGear = player:FindFirstChild("StarterGear")
	local character = player.Character

	if backpack
		and not hasToolIn(backpack, TOOL_NAME)
		and not hasToolIn(character, TOOL_NAME)
	then
		local backpackTool = toolTemplate:Clone()
		configureGrantedTool(backpackTool, station)
		backpackTool.Parent = backpack
		wireCombatTool(backpackTool, player)
	end

	if starterGear and not hasToolIn(starterGear, TOOL_NAME) then
		local starterTool = toolTemplate:Clone()
		configureGrantedTool(starterTool, station)
		starterTool.Parent = starterGear
	end
end

local function setLabel(station: Model, enabled: boolean, statusText: string, color: Color3)
	local buyPad = station:FindFirstChild("BuyPad")
	local label = buyPad and buyPad:FindFirstChild("PurchaseLabel")
	if not label or not label:IsA("BillboardGui") then
		return
	end

	label.Enabled = enabled
	local panel = label:FindFirstChild("Panel")
	local status = panel and panel:FindFirstChild("Status")
	local border = panel and panel:FindFirstChild("Border")
	if status and status:IsA("TextLabel") then
		status.Text = statusText
		status.TextColor3 = color
	end
	if border and border:IsA("UIStroke") then
		border.Color = color
	end
end

local function getDisplayParts(station: Model): { BasePart }
	local result: { BasePart } = {}
	local display = station:FindFirstChild("DisplayModel")
	if display then
		for _, descendant in ipairs(display:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(result, descendant)
			end
		end
	end
	return result
end

local function applyStationVisuals(station: Model, plot: Instance, unlocked: boolean, purchased: boolean)
	for _, part in ipairs(getDisplayParts(station)) do
		local style = DISPLAY_STYLE[part.Name]
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false

		if unlocked and style then
			part.Color = style.color
			part.Material = style.material
			part.Transparency = purchased and 0 or 0.1
			part.CastShadow = true
		else
			part.Color = COLOR_LOCKED
			part.Material = Enum.Material.SmoothPlastic
			part.Transparency = 0.55
			part.CastShadow = false
		end
	end

	local standBase = station:FindFirstChild("StandBase")
	local standColumn = station:FindFirstChild("StandColumn")
	local standTop = station:FindFirstChild("StandTop")
	local accent = station:FindFirstChild("Theme_Accent")

	for _, part in ipairs({ standBase, standColumn, standTop }) do
		if part and part:IsA("BasePart") then
			part.Transparency = unlocked and 0 or 0.25
			part.CanCollide = unlocked
		end
	end
	if standBase and standBase:IsA("BasePart") then
		standBase.Color = unlocked and COLOR_DARK or COLOR_LOCKED
	end
	if standColumn and standColumn:IsA("BasePart") then
		standColumn.Color = unlocked and COLOR_COLUMN or COLOR_LOCKED
	end
	if standTop and standTop:IsA("BasePart") then
		standTop.Color = unlocked and COLOR_TOP or COLOR_LOCKED
	end
	if accent and accent:IsA("BasePart") then
		accent.Color = unlocked and PlotTheme.GetPlotColor(plot) or COLOR_LOCKED
		accent.Material = Enum.Material.SmoothPlastic
		accent.Transparency = unlocked and 0 or 0.3
	end
end

local function findOwnedPlot(player: Player): Instance?
	for index = 1, 10 do
		local plot = workspace:FindFirstChild("P" .. index)
		if plot and tonumber(plot:GetAttribute("Owner")) == player.UserId then
			return plot
		end
	end
	return nil
end

local function findStation(plot: Instance): Model?
	local centreSlots = plot:FindFirstChild("CentreSlots")
	local avatarCentre = centreSlots and centreSlots:FindFirstChild("Centre03_Avatar")
	local upgrades = avatarCentre and avatarCentre:FindFirstChild("Upgrades")
	local station = upgrades and upgrades:FindFirstChild(STATION_NAME)
	return station and station:IsA("Model") and station or nil
end

local function connectPlayer(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if backpack then
		backpack.ChildAdded:Connect(function(child)
			wireCombatTool(child, player)
		end)
		for _, child in ipairs(backpack:GetChildren()) do
			wireCombatTool(child, player)
		end
	end

	player.CharacterAdded:Connect(function(character)
		character.ChildAdded:Connect(function(child)
			wireCombatTool(child, player)
		end)

		task.defer(function()
			local plot = findOwnedPlot(player)
			local station = plot and findStation(plot)
			local activated = station and station:FindFirstChild("Activated")
			if station and activated and activated:IsA("BoolValue") and activated.Value then
				grantTool(player, station)
			end
			for _, child in ipairs(character:GetChildren()) do
				wireCombatTool(child, player)
			end
		end)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(connectPlayer, player)
end
Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player)
	lastSwingByPlayer[player] = nil
end)

local function wirePlot(plot: Instance): boolean
	local centreSlots = plot:FindFirstChild("CentreSlots")
	local avatarCentre = centreSlots and centreSlots:FindFirstChild("Centre03_Avatar")
	local avatarActivated = avatarCentre and avatarCentre:FindFirstChild("Activated")
	local station = findStation(plot)
	if not avatarCentre
		or not avatarActivated
		or not avatarActivated:IsA("BoolValue")
		or not station
	then
		warn(("[KnockbackPlankService] Incomplete station in %s."):format(plot:GetFullName()))
		return false
	end

	local activated = station:FindFirstChild("Activated")
	local config = station:FindFirstChild("Config")
	local price = config and config:FindFirstChild("Price")
	local requiresStructure = config and config:FindFirstChild("RequiresStructure")
	local buyPad = station:FindFirstChild("BuyPad")
	if not activated
		or not activated:IsA("BoolValue")
		or not price
		or not price:IsA("IntValue")
		or not requiresStructure
		or not requiresStructure:IsA("StringValue")
		or not buyPad
		or not buyPad:IsA("BasePart")
	then
		warn(("[KnockbackPlankService] Invalid station configuration in %s."):format(plot:GetFullName()))
		return false
	end

	local processing = false

	local function getOwner(): Player?
		local ownerId = tonumber(plot:GetAttribute("Owner"))
		return ownerId and Players:GetPlayerByUserId(ownerId) or nil
	end

	local function dependencyMet(): boolean
		return requiresStructure.Value == "Centre03_Avatar" and avatarActivated.Value
	end

	local function applyState()
		local owner = getOwner()
		local previousOwner = lastOwnerByPlot[plot]
		if previousOwner and previousOwner ~= owner and previousOwner.Parent then
			removeGrantedTools(previousOwner)
		end
		lastOwnerByPlot[plot] = owner

		local unlocked = owner ~= nil and dependencyMet()
		applyStationVisuals(station, plot, unlocked, activated.Value)

		buyPad.CanCollide = false
		buyPad.Material = Enum.Material.Neon

		if activated.Value and owner then
			buyPad.Transparency = 1
			buyPad.CanTouch = false
			buyPad.CanQuery = false
			setLabel(station, false, "OWNED", COLOR_GREEN)
			grantTool(owner, station)
			return
		end

		buyPad.CanQuery = true
		buyPad.Transparency = unlocked and 0.45 or 0.68

		if not owner then
			buyPad.Color = COLOR_LOCKED
			buyPad.CanTouch = false
			setLabel(station, true, "CLAIM THIS PLOT", COLOR_LOCKED)
			return
		end
		if not dependencyMet() then
			buyPad.Color = COLOR_LOCKED
			buyPad.CanTouch = false
			setLabel(station, true, "REQUIRES AVATAR CENTRE", COLOR_LOCKED)
			return
		end

		local cash = getCash(owner)
		local affordable = cash ~= nil and (cash :: any).Value >= price.Value
		local color = affordable and COLOR_GREEN or COLOR_RED
		buyPad.Color = color
		buyPad.CanTouch = true
		setLabel(station, true, formatCash(price.Value), color)
	end

	buyPad.Touched:Connect(function(hit: BasePart)
		if processing or activated.Value or not dependencyMet() then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or player ~= getOwner() then
			return
		end

		local cash = getCash(player)
		if not cash or (cash :: any).Value < price.Value then
			applyState()
			return
		end

		processing = true
		(cash :: any).Value -= price.Value
		activated.Value = true
		grantTool(player, station)

		PurchaseEffectModule.PlayAcrossParts(getDisplayParts(station), {
			color = PlotTheme.GetPlotColor(plot),
		}, {
			pointCount = 8,
			totalParticleBudget = 72,
		})
		PurchaseSoundModule.PlayPurchaseForTarget(player, buyPad)

		task.delay(0.6, function()
			processing = false
			applyState()
		end)
	end)

	activated.Changed:Connect(function()
		if not activated.Value then
			local owner = getOwner()
			if owner then
				removeGrantedTools(owner)
			end
		end
		applyState()
	end)
	avatarActivated.Changed:Connect(applyState)
	price.Changed:Connect(applyState)
	plot:GetAttributeChangedSignal("Owner"):Connect(applyState)
	plot:GetAttributeChangedSignal("PlotColor"):Connect(applyState)

	table.insert(refreshers, applyState)
	applyState()
	return true
end

local wiredCount = 0
for plotIndex = 1, 10 do
	local plot = workspace:FindFirstChild("P" .. plotIndex)
	if plot and wirePlot(plot) then
		wiredCount += 1
	end
end

task.spawn(function()
	while true do
		task.wait(PAD_REFRESH_SECONDS)
		for _, refresh in ipairs(refreshers) do
			refresh()
		end
	end
end)

print(("[KnockbackPlankService] Wired %d buy station(s)."):format(wiredCount))
