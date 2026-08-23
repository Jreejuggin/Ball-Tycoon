-- PurchaseEffectModule
-- Single shared "purchase confirmed" particle burst, used by every buy pad
-- and machine upgrade feedback path in the game.

local PurchaseEffectModule = {}

--local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SPARKLE_TEXTURE = "rbxassetid://81738678082113"
local GOLD_COLOR = Color3.fromRGB(255, 254, 143)
local EFFECT_LIFETIME = 1.0
local CLEANUP_DELAY = EFFECT_LIFETIME + 0.5
local BURST_WINDOW = 0.8

local DEFAULTS = {
	color = GOLD_COLOR,
	lightEmission = 0,
	lightInfluence = 0,

	size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	}),

	-- Sparkles stay visible for their lifetime.
	transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0),
	}),

	lifetime = NumberRange.new(0.6, EFFECT_LIFETIME),
	speed = NumberRange.new(3, 8),
	spreadAngle = Vector2.new(180, 180),
	rotation = NumberRange.new(0, 360),
	rotSpeed = NumberRange.new(-120, 120),
	acceleration = Vector3.new(0, 2, 0),
	particleCount = 24,
}

local function randomBetween(minValue, maxValue)
	return minValue + (maxValue - minValue) * math.random()
end

local function getRandomSurfacePosition(part)
	local half = part.Size / 2
	local insetX = randomBetween(-half.X, half.X)
	local insetY = randomBetween(-half.Y, half.Y)
	local insetZ = randomBetween(-half.Z, half.Z)
	local padding = 0.08
	local face = math.random(6)
	local localOffset

	if face == 1 then
		localOffset = Vector3.new(half.X + padding, insetY, insetZ)
	elseif face == 2 then
		localOffset = Vector3.new(-half.X - padding, insetY, insetZ)
	elseif face == 3 then
		localOffset = Vector3.new(insetX, half.Y + padding, insetZ)
	elseif face == 4 then
		localOffset = Vector3.new(insetX, -half.Y - padding, insetZ)
	elseif face == 5 then
		localOffset = Vector3.new(insetX, insetY, half.Z + padding)
	else
		localOffset = Vector3.new(insetX, insetY, -half.Z - padding)
	end

	return part.CFrame:PointToWorldSpace(localOffset)
end

function PurchaseEffectModule.Play(position, styleOverrides)
	local style = table.clone(DEFAULTS)

	if styleOverrides then
		for key, value in pairs(styleOverrides) do
			style[key] = value
		end
	end

	task.spawn(function()
		local anchor = Instance.new("Part")
		anchor.Name = "PurchaseEffectAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Position = position
		anchor.Parent = workspace

		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SPARKLE_TEXTURE
		emitter.Color = ColorSequence.new(style.color)
		emitter.LightEmission = style.lightEmission
		emitter.LightInfluence = style.lightInfluence
		emitter.Size = style.size
		emitter.Transparency = style.transparency
		emitter.Lifetime = style.lifetime
		emitter.Rate = 0
		emitter.Speed = style.speed
		emitter.SpreadAngle = style.spreadAngle
		emitter.Rotation = style.rotation
		emitter.RotSpeed = style.rotSpeed
		emitter.Acceleration = style.acceleration
		emitter.Parent = anchor

		-- Keep a tiny live burst in addition to Emit(). The sparkle still uses the
		-- same texture/properties, but clients have time to receive and render it.
		emitter.Rate = math.max(1, math.floor(style.particleCount / BURST_WINDOW))
		task.wait(0.05)
		emitter:Emit(style.particleCount)

		task.delay(BURST_WINDOW, function()
			if emitter.Parent then
				emitter.Rate = 0
				emitter.Enabled = false
			end
		end)

		task.delay(CLEANUP_DELAY, function()
			if anchor.Parent then
				anchor:Destroy()
			end
		end)
	end)
end

local DEFAULT_POINT_COUNT = 10
local DEFAULT_PARTICLE_BUDGET = 60

function PurchaseEffectModule.PlayAcrossParts(parts, styleOverrides, coverage)
	if #parts == 0 then return end

	coverage = coverage or {}
	local pointCount = coverage.pointCount or DEFAULT_POINT_COUNT
	local totalParticleBudget = coverage.totalParticleBudget or DEFAULT_PARTICLE_BUDGET
	local perPointCount = math.max(2, math.floor(totalParticleBudget / pointCount))

	local selection = {}

	if #parts >= pointCount then
		local shuffled = table.clone(parts)

		for i = #shuffled, 2, -1 do
			local j = math.random(i)
			shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
		end

		for i = 1, pointCount do
			selection[i] = shuffled[i]
		end
	else
		for i = 1, pointCount do
			selection[i] = parts[math.random(#parts)]
		end
	end

	local pointOverrides = table.clone(styleOverrides or {})
	pointOverrides.particleCount = perPointCount

	for _, part in ipairs(selection) do
		PurchaseEffectModule.Play(getRandomSurfacePosition(part), pointOverrides)
	end
end

return PurchaseEffectModule
