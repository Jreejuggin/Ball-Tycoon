-- PurchaseEffectModule
-- Single shared "purchase confirmed" particle burst, used by every buy pad
-- script in the game (workers, droppers, structure pieces, and any future
-- purchasable thing). Centralizing this here means the look only needs to
-- be built and tuned once -- every buy pad script just calls
-- PurchaseEffectModule.Play(position) at the moment of a successful purchase.
--
-- Runs on the SERVER (called from Scripts, not LocalScripts) so the burst
-- replicates and is visible to every nearby player, not just the buyer --
-- unlike the ghost-preview system, this effect is meant to be seen by
-- everyone, matching how purchase confirmations work in other Roblox games.
--
-- Uses Roblox's own built-in sparkle texture (rbxasset://textures/particles/
-- sparkles_main.dds) -- this is Roblox's default ParticleEmitter texture, so
-- it's guaranteed to always be available with no external asset dependency.
--
-- IMPORTANT: calling ParticleEmitter:Emit() in the exact same tick an emitter
-- is created and parented is a well-documented Roblox quirk -- the particle
-- system hasn't registered the new emitter yet, so the Emit() call silently
-- does nothing. The fix is a brief yield between parenting the emitter and
-- calling Emit(). To make sure that yield never delays whatever purchase
-- logic calls Play() (cash deduction, revealing the purchased thing, etc.),
-- the actual work happens inside task.spawn -- Play() itself always returns
-- immediately.
--
-- STYLE OVERRIDES: Play(position) alone always gives the exact default look
-- below. Pass a second table to override specific properties for a single
-- call site without touching anyone else's look or duplicating this module --
-- e.g. Play(position, {lightEmission = 0}) for a flatter, less glowy variant.
-- Any key you omit keeps the default. Valid keys mirror the DEFAULTS table.

local PurchaseEffectModule = {}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD_COLOR = Color3.fromRGB(255, 221, 64)
local EFFECT_LIFETIME = 1.0 -- seconds, longest a single particle can live
local CLEANUP_DELAY = EFFECT_LIFETIME + 0.5 -- buffer so all particles finish fading before cleanup

local DEFAULTS = {
	color = GOLD_COLOR,
	lightEmission = 1, -- 1 = bright/glowy/"shiny"; 0 = flat/matte, no bloom
	lightInfluence = 0, -- 0 = unaffected by scene lighting (consistent everywhere)
	size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	}),
	transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	}),
	lifetime = NumberRange.new(0.6, EFFECT_LIFETIME),
	speed = NumberRange.new(3, 8),
	spreadAngle = Vector2.new(180, 180), -- scatter outward in all directions
	rotation = NumberRange.new(0, 360), -- random start rotation per particle
	rotSpeed = NumberRange.new(-120, 120), -- spin speed; higher = more frantic twinkle
	acceleration = Vector3.new(0, 2, 0), -- gentle upward drift
	particleCount = 24,
}

-- Plays a one-shot sparkle burst at a world position. Cleans up after itself.
-- Returns immediately; the actual effect runs in its own spawned thread.
-- styleOverrides (optional): table of any DEFAULTS keys to override for just
-- this call, e.g. {lightEmission = 0, particleCount = 14}.
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
		emitter.Rate = 0 -- burst only via Emit(), no continuous stream
		emitter.Speed = style.speed
		emitter.SpreadAngle = style.spreadAngle
		emitter.Rotation = style.rotation
		emitter.RotSpeed = style.rotSpeed
		emitter.Acceleration = style.acceleration
		emitter.Parent = anchor

		-- Let the particle system register the new emitter before emitting --
		-- see the IMPORTANT note above. This is a single frame, imperceptible.
		task.wait()

		emitter:Emit(style.particleCount)

		task.delay(CLEANUP_DELAY, function()
			anchor:Destroy()
		end)
	end)
end

-- Plays the burst spread across several actual parts of an object, instead
-- of one single burst at one averaged/shared point. Use this for anything
-- made of multiple parts spanning real distance (a wall made of many bands,
-- a dropper made of many small parts) -- a single averaged center point
-- collapses toward the middle of the object regardless of which part you're
-- actually looking at, which reads as "it's all happening in one spot."
--
-- Points are NOT one-per-part -- coverage.pointCount controls how many
-- scattered points to use overall. If there are at least that many parts,
-- parts are shuffled and used without repeats (even spread, no part hit
-- twice). If there are FEWER parts than points -- e.g. a single huge roof
-- slab, or a handful of wide glass panes -- parts are reused so a single big
-- part can still receive many scattered points across its own surface,
-- rather than being capped at one point no matter how large it is. Jitter
-- for each point spans that part's FULL size (edge to edge), so a big flat
-- part gets real coverage across its whole face, not just near its center.
--
-- coverage (optional): {pointCount = N, totalParticleBudget = N}. Defaults
-- below suit a compact object like a dropper; pass larger values for big,
-- spread-out things like a full wall or roof (e.g. {pointCount = 30,
-- totalParticleBudget = 120}) without changing the default for anyone else.
-- styleOverrides (optional): same as Play() -- applies to every point.
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
		-- Enough parts to cover every point without repeating any one part --
		-- shuffle and take the first pointCount for an even spread.
		local shuffled = table.clone(parts)
		for i = #shuffled, 2, -1 do
			local j = math.random(i)
			shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
		end
		for i = 1, pointCount do
			selection[i] = shuffled[i]
		end
	else
		-- Fewer parts than requested points -- reuse parts (with
		-- replacement) so a single large part can still get several
		-- scattered points across its own surface.
		for i = 1, pointCount do
			selection[i] = parts[math.random(#parts)]
		end
	end

	local pointOverrides = table.clone(styleOverrides or {})
	pointOverrides.particleCount = perPointCount

	for _, part in ipairs(selection) do
		local half = part.Size / 2
		local jitter = Vector3.new(
			(math.random() * 2 - 1) * half.X,
			(math.random() * 2 - 1) * half.Y,
			(math.random() * 2 - 1) * half.Z
		)
		PurchaseEffectModule.Play(part.Position + jitter, pointOverrides)
	end
end

return PurchaseEffectModule