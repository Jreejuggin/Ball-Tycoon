--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("ThrowableBallConfig"))
local CombatDamageService = require(script.Parent:WaitForChild("CombatDamageService"))

type Profile = {
	Damage: number,
	Cooldown: number,
	Speed: number,
	Lifetime: number,
	MaxDistance: number,
	Radius: number,
	GravityScale: number,
	HorizontalKnockback: number,
	VerticalKnockback: number,
	AngularKnockback: number,
	RagdollSeconds: number,
}

type WireRecord = {
	player: Player,
	profile: Profile,
	handle: BasePart,
	transparency: number,
	visualToken: number,
	eventConnection: RBXScriptConnection?,
	destroyConnection: RBXScriptConnection?,
}

type Shot = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	tool: Tool,
	profile: Profile,
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	origin: Vector3,
	right: Vector3,
	age: number,
	distance: number,
	consumed: boolean,
}

local Service = {}
local template: Tool? = nil
local ownsBall: ((Player) -> boolean)? = nil
local projectileFolder: Folder? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local wiredTools: { [Tool]: WireRecord } = {}
local activeShots: { [BasePart]: Shot } = {}
local lastThrowByPlayer: { [Player]: number } = {}
local acceptedThrows = 0
local rejectedThrows = 0
local playerContacts = 0

local DEFAULT_PROFILE: Profile = {
	Damage = 10,
	Cooldown = 1.2,
	Speed = 95,
	Lifetime = 3,
	MaxDistance = 200,
	Radius = 0.7,
	GravityScale = 0.35,
	HorizontalKnockback = 184,
	VerticalKnockback = 52,
	AngularKnockback = 28,
	RagdollSeconds = 1.25,
}

local function isFiniteNumber(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector(value: Vector3): boolean
	return isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)
end

local function captureProfile(tool: Tool): Profile?
	local level = tonumber(tool:GetAttribute("WeaponLevel"))
		or tonumber(tool:GetAttribute("WeaponTier"))
		or 1
	local source = Config.Levels[level]
	if type(source) ~= "table" then
		return nil
	end
	local profile = {} :: any
	for key, default in pairs(DEFAULT_PROFILE) do
		local value = source[key]
		profile[key] = if type(value) == "number" and isFiniteNumber(value) then value else default
	end
	profile.Damage = math.clamp(profile.Damage, 0, 100)
	profile.Cooldown = math.clamp(profile.Cooldown, 0.2, 10)
	profile.Speed = math.clamp(profile.Speed, 1, 250)
	profile.Lifetime = math.clamp(profile.Lifetime, 0.1, 10)
	profile.MaxDistance = math.clamp(profile.MaxDistance, 1, 500)
	profile.Radius = math.clamp(profile.Radius, 0.1, 3)
	profile.GravityScale = math.clamp(profile.GravityScale, 0, 2)
	return table.freeze(profile) :: Profile
end

local function getProjectilesFolder(): Folder
	if projectileFolder and projectileFolder.Parent == workspace then
		return projectileFolder
	end
	local existing = workspace:FindFirstChild("ThrowableBallProjectiles")
	assert(existing == nil or existing:IsA("Folder"), "ThrowableBallProjectiles must be a Folder")
	local folder = existing :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ThrowableBallProjectiles"
		folder.Parent = workspace
	end
	projectileFolder = folder
	return folder
end

local function stopHeartbeatIfIdle()
	if next(activeShots) == nil and heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function discardShot(shot: Shot)
	if shot.consumed then
		return
	end
	shot.consumed = true
	activeShots[shot.part] = nil
	shot.part:Destroy()
end

local function findPlayerCharacter(part: BasePart): Model?
	local ancestor: Instance? = part
	while ancestor and ancestor ~= workspace do
		if ancestor:IsA("Model") and Players:GetPlayerFromCharacter(ancestor) then
			return ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local function consumeContact(shot: Shot, contactPart: BasePart)
	if shot.consumed then
		return
	end
	local character = findPlayerCharacter(contactPart)
	local targetPlayer = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local forward = if shot.velocity.Magnitude > 0.01 then shot.velocity.Unit else Vector3.new(0, 0, -1)
	-- Consume before yielding; one projectile can never register multiple hits.
	discardShot(shot)
	if character and targetPlayer and targetPlayer ~= shot.player
		and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")
	then
		playerContacts += 1
		if not character:FindFirstChildOfClass("ForceField") then
			task.spawn(function()
				CombatDamageService.ApplyHit(
					shot.player, shot.tool, humanoid, root,
					shot.origin, forward, shot.right, shot.profile.Damage
				)
			end)
		end
	end
end

local function makeQueryParameters(shot: Shot): (RaycastParams, RaycastParams, OverlapParams, OverlapParams)
	local characters: { Instance } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= shot.player and player.Character then
			table.insert(characters, player.Character)
		end
	end
	local worldCast = RaycastParams.new()
	worldCast.FilterType = Enum.RaycastFilterType.Exclude
	worldCast.FilterDescendantsInstances = { shot.character, getProjectilesFolder() }
	worldCast.IgnoreWater = true
	worldCast.RespectCanCollide = true
	local playerCast = RaycastParams.new()
	playerCast.FilterType = Enum.RaycastFilterType.Include
	playerCast.FilterDescendantsInstances = characters
	playerCast.IgnoreWater = true
	playerCast.RespectCanCollide = false
	local worldOverlap = OverlapParams.new()
	worldOverlap.FilterType = Enum.RaycastFilterType.Exclude
	worldOverlap.FilterDescendantsInstances = worldCast.FilterDescendantsInstances
	worldOverlap.RespectCanCollide = true
	worldOverlap.MaxParts = 24
	local playerOverlap = OverlapParams.new()
	playerOverlap.FilterType = Enum.RaycastFilterType.Include
	playerOverlap.FilterDescendantsInstances = characters
	playerOverlap.RespectCanCollide = false
	playerOverlap.MaxParts = 32
	return worldCast, playerCast, worldOverlap, playerOverlap
end

local function checkOverlap(shot: Shot, position: Vector3, worldParams: OverlapParams, playerParams: OverlapParams): boolean
	local worldParts = workspace:GetPartBoundsInRadius(position, shot.profile.Radius, worldParams)
	local playerParts = workspace:GetPartBoundsInRadius(position, shot.profile.Radius, playerParams)
	-- An overlapping solid consumes the shot, including walls at the spawn point.
	for _, part in ipairs(worldParts) do
		if not findPlayerCharacter(part) then
			consumeContact(shot, part)
			return true
		end
	end
	if #playerParts > 0 then
		consumeContact(shot, playerParts[1])
		return true
	end
	if #worldParts > 0 then
		consumeContact(shot, worldParts[1])
		return true
	end
	return false
end

local function sweep(shot: Shot, displacement: Vector3, worldParams: RaycastParams, playerParams: RaycastParams): boolean
	if displacement.Magnitude <= 0.0001 then
		return false
	end
	local worldHit = workspace:Spherecast(shot.position, shot.profile.Radius, displacement, worldParams)
	local playerHit = workspace:Spherecast(shot.position, shot.profile.Radius, displacement, playerParams)
	local result = worldHit
	if playerHit and (not result or playerHit.Distance < result.Distance) then
		result = playerHit
	end
	if result then
		consumeContact(shot, result.Instance)
		return true
	end
	return false
end

local function stepShots(deltaTime: number)
	for _, shot in pairs(activeShots) do
		if shot.player.Parent ~= Players or shot.player.Character ~= shot.character
			or shot.humanoid.Health <= 0 or not shot.part.Parent
		then
			discardShot(shot)
			continue
		end
		local remainingLife = shot.profile.Lifetime - shot.age
		local remainingDistance = shot.profile.MaxDistance - shot.distance
		if remainingLife <= 0 or remainingDistance <= 0 then
			discardShot(shot)
			continue
		end
		local dt = math.min(deltaTime, remainingLife)
		local acceleration = Vector3.new(0, -workspace.Gravity * shot.profile.GravityScale, 0)
		local displacement = shot.velocity * dt + acceleration * (0.5 * dt * dt)
		if displacement.Magnitude > remainingDistance then
			displacement = displacement.Unit * remainingDistance
		end
		local worldCast, playerCast, worldOverlap, playerOverlap = makeQueryParameters(shot)
		if checkOverlap(shot, shot.position, worldOverlap, playerOverlap)
			or sweep(shot, displacement, worldCast, playerCast)
		then
			continue
		end
		shot.position += displacement
		shot.velocity += acceleration * dt
		shot.age += dt
		shot.distance += displacement.Magnitude
		shot.part.CFrame = CFrame.new(shot.position) * CFrame.Angles(shot.age * 4, shot.age * 6, 0)
		if not checkOverlap(shot, shot.position, worldOverlap, playerOverlap)
			and (shot.age >= shot.profile.Lifetime or shot.distance >= shot.profile.MaxDistance)
		then
			discardShot(shot)
		end
	end
	stopHeartbeatIfIdle()
end

local function launch(player: Player, tool: Tool, record: WireRecord, aim: any)
	if typeof(aim) ~= "Vector3" or not isFiniteVector(aim) then
		rejectedThrows += 1
		return
	end
	local magnitude = aim.Magnitude
	if magnitude < 0.5 or magnitude > 2 then
		rejectedThrows += 1
		return
	end
	local now = os.clock()
	if now - (lastThrowByPlayer[player] or -math.huge) < record.profile.Cooldown then
		rejectedThrows += 1
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local ownershipCheck = ownsBall
	if not ownershipCheck or not ownershipCheck(player)
		or not character or tool.Parent ~= character or record.player ~= player
		or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart")
		or record.handle.Parent ~= tool
		or not isFiniteVector(root.Position) or not isFiniteVector(record.handle.Position)
		or (record.handle.Position - root.Position).Magnitude > 8
	then
		rejectedThrows += 1
		return
	end
	lastThrowByPlayer[player] = now
	acceptedThrows += 1
	local direction = aim.Unit
	local origin = root.Position + Vector3.yAxis
	local projectile = record.handle:Clone()
	for _, child in ipairs(projectile:GetChildren()) do
		if not child:IsA("SpecialMesh") and not child:IsA("Decal") and not child:IsA("Texture") and not child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
			descendant:Destroy()
		end
	end
	projectile.Name = "ThrowableBallProjectile"
	projectile.Anchored = true
	projectile.CanCollide = false
	projectile.CanTouch = false
	projectile.CanQuery = false
	projectile.CastShadow = true
	projectile.Transparency = record.transparency
	projectile.CFrame = CFrame.new(origin)
	projectile.Parent = getProjectilesFolder()
	local shot: Shot = {
		player = player,
		character = character,
		humanoid = humanoid,
		tool = tool,
		profile = record.profile,
		part = projectile,
		position = origin,
		velocity = direction * record.profile.Speed,
		origin = origin,
		right = root.CFrame.RightVector,
		age = 0,
		distance = 0,
		consumed = false,
	}
	activeShots[projectile] = shot
	record.visualToken += 1
	local token = record.visualToken
	record.handle.Transparency = 1
	tool.Enabled = false
	task.delay(record.profile.Cooldown, function()
		if wiredTools[tool] == record and record.visualToken == token and tool.Parent then
			record.handle.Transparency = record.transparency
			tool.Enabled = true
		end
	end)
	local worldCast, playerCast, worldOverlap, playerOverlap = makeQueryParameters(shot)
	local initialDisplacement = direction * (record.profile.Radius + 1.25)
	if not checkOverlap(shot, origin, worldOverlap, playerOverlap)
		and not sweep(shot, initialDisplacement, worldCast, playerCast)
	then
		shot.position += initialDisplacement
		shot.distance += initialDisplacement.Magnitude
		projectile.CFrame = CFrame.new(shot.position)
		checkOverlap(shot, shot.position, worldOverlap, playerOverlap)
	end
	if next(activeShots) ~= nil and not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(stepShots)
	end
end

local function unwireTool(tool: Tool)
	local record = wiredTools[tool]
	if not record then
		return
	end
	wiredTools[tool] = nil
	if record.eventConnection then
		record.eventConnection:Disconnect()
	end
	if record.destroyConnection then
		record.destroyConnection:Disconnect()
	end
	if record.handle.Parent then
		record.handle.Transparency = record.transparency
	end
	tool.Enabled = true
end

function Service.Configure(toolTemplate: Tool, ownsBallCallback: (Player) -> boolean)
	assert(toolTemplate:IsA("Tool"), "Throwable ball template must be a Tool")
	assert(template == nil or template == toolTemplate, "Throwable ball combat is already configured")
	template = toolTemplate
	ownsBall = ownsBallCallback
	getProjectilesFolder()
end

function Service.WireTool(instance: Instance, player: Player)
	local currentTemplate = template
	if not currentTemplate or not instance:IsA("Tool")
		or instance.Name ~= currentTemplate.Name or wiredTools[instance]
	then
		return
	end
	local event = instance:FindFirstChild("ThrowEvent")
	local handle = instance:FindFirstChild("Handle")
	local profile = captureProfile(instance)
	if not event or not event:IsA("RemoteEvent") or not handle or not handle:IsA("BasePart") or not profile then
		warn("[ThrowableBallCombatService] Invalid throwable ball tool: " .. instance:GetFullName())
		return
	end
	-- Snapshot tuning from the server registry, never from a remote payload.
	for _, attribute in ipairs({ "HorizontalKnockback", "VerticalKnockback", "AngularKnockback", "RagdollSeconds" }) do
		instance:SetAttribute(attribute, (profile :: any)[attribute])
	end
	instance:SetAttribute("ThrowCooldown", profile.Cooldown)
	local record: WireRecord = {
		player = player,
		profile = profile,
		handle = handle,
		transparency = handle.Transparency,
		visualToken = 0,
		eventConnection = nil,
		destroyConnection = nil,
	}
	wiredTools[instance] = record
	record.eventConnection = event.OnServerEvent:Connect(function(firingPlayer: Player, aim: any)
		if firingPlayer ~= record.player then
			rejectedThrows += 1
			return
		end
		launch(firingPlayer, instance, record, aim)
	end)
	record.destroyConnection = instance.Destroying:Connect(function()
		unwireTool(instance)
	end)
end

function Service.RemovePlayer(player: Player)
	lastThrowByPlayer[player] = nil
	for tool, record in pairs(wiredTools) do
		if record.player == player then
			unwireTool(tool)
		end
	end
	for _, shot in pairs(activeShots) do
		if shot.player == player then
			discardShot(shot)
		end
	end
	stopHeartbeatIfIdle()
end

function Service.GetStats(): { [string]: number }
	local activeCount, toolCount, cooldownCount = 0, 0, 0
	for _ in pairs(activeShots) do activeCount += 1 end
	for _ in pairs(wiredTools) do toolCount += 1 end
	for _ in pairs(lastThrowByPlayer) do cooldownCount += 1 end
	return {
		ActiveProjectiles = activeCount,
		WiredTools = toolCount,
		CooldownPlayers = cooldownCount,
		AcceptedThrows = acceptedThrows,
		RejectedThrows = rejectedThrows,
		PlayerContacts = playerContacts,
	}
end

return Service
