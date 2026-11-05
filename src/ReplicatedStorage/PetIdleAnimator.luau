-- Local cosmetic idles for the single-mesh pets. Stepped by PetFollowers' existing frame loop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("PetFollowConfig")).Idle
local Faces = require(ReplicatedStorage:WaitForChild("PetFaceData"))

local Animator = {}
Animator.__index = Animator

local function cosmetic(parent, name, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Size = Vector3.new(0.05, 0.05, 0.05)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function show(part, visible)
	local transparency = visible and 0 or 1
	if part.Transparency ~= transparency then part.Transparency = transparency end
end

local function smooth(value)
	value = math.clamp(value, 0, 1)
	return value * value * (3 - 2 * value)
end

function Animator.new(pet, petId, scale, seed)
	local rng = Random.new(seed)
	local now = workspace:GetServerTimeNow()
	local self = setmetatable({
		Pet = pet, Face = Faces[petId], Scale = scale, Rng = rng,
		BlinkAt = now + rng:NextNumber(0.8, Config.BlinkInterval.Y),
		IdleAt = now + rng:NextNumber(2, Config.GestureInterval.Y),
		Eyes = {}, Parts = {}, WasVisible = false,
	}, Animator)
	if self.Face then
		for index, side in ipairs({ -1, 1 }) do
			local normal = Vector3.new(side * 0.34, 0.05, -math.sqrt(1 - 0.34^2 - 0.05^2))
			local lid = cosmetic(pet, "IdleEyelid" .. index, self.Face.LidColors[index])
			local line = cosmetic(pet, "IdleClosedEye" .. index, Color3.fromRGB(48, 25, 47))
			table.insert(self.Eyes, { Normal = normal, Lid = lid, Line = line })
			table.insert(self.Parts, lid)
			table.insert(self.Parts, line)
		end
		if self.Face.Tongue then
			self.Tongue = cosmetic(pet, "IdleTongue", Color3.fromRGB(255, 137, 171))
			self.Crease = cosmetic(pet, "IdleTongueCrease", Color3.fromRGB(211, 82, 120))
			table.insert(self.Parts, self.Tongue)
			table.insert(self.Parts, self.Crease)
		end
	end
	return self
end

function Animator:Hide()
	for _, part in ipairs(self.Parts) do show(part, false) end
	self.WasVisible = false
end

function Animator:Step(now, baseCFrame, visible)
	if not visible then self:Hide(); return baseCFrame end
	if not self.WasVisible then
		self.WasVisible = true
		-- Do not queue a burst of old animations after death, first person, or distance culling.
		if self.BlinkAt < now then self.BlinkAt = now + self.Rng:NextNumber(0.5, 3) end
		if self.IdleAt < now then self.IdleAt = now + self.Rng:NextNumber(1, 4) end
	end
	if not self.BlinkStarted and now >= self.BlinkAt then
		self.BlinkStarted = now
		self.BlinkAt = now + self.Rng:NextNumber(Config.BlinkInterval.X, Config.BlinkInterval.Y)
		if self.Rng:NextNumber() < Config.DoubleBlinkChance then self.DoubleBlink = true end
	end
	if not self.ActionStarted and now >= self.IdleAt then
		local actions = self.Tongue and { "Tilt", "Hop", "Wiggle", "Blep" } or { "Tilt", "Hop", "Wiggle" }
		self.Action = actions[self.Rng:NextInteger(1, #actions)]
		self.ActionStarted = now
		self.ActionDirection = self.Rng:NextNumber() < 0.5 and -1 or 1
		self.IdleAt = now + self.Rng:NextNumber(Config.GestureInterval.X, Config.GestureInterval.Y)
	end

	local tilt, yaw, hop, tongue = 0, 0, 0, 0
	if self.ActionStarted then
		local progress = (now - self.ActionStarted) / Config.GestureDuration
		if progress >= 1 then
			self.ActionStarted = nil
			self.Action = nil
		else
			local envelope = math.sin(math.pi * progress)^2
			if self.Action == "Tilt" then
				tilt = math.rad(Config.TiltDegrees) * envelope * (self.ActionDirection or 1)
				yaw = math.rad(5) * envelope
			elseif self.Action == "Hop" then
				hop = math.sin(math.pi * progress) * Config.HopHeight * self.Scale
				tilt = math.sin(progress * math.pi * 2) * math.rad(4)
			elseif self.Action == "Wiggle" then
				tilt = math.sin(progress * math.pi * 8) * math.rad(7) * envelope
				yaw = math.sin(progress * math.pi * 4) * math.rad(8) * envelope
			elseif self.Action == "Blep" then
				tongue = smooth(progress / 0.2) * smooth((1 - progress) / 0.25)
				tilt = math.rad(5) * envelope
			end
		end
	end
	local centre = self.Face and self.Face.BodyCentre * self.Scale or Vector3.zero
	local cf = baseCFrame * CFrame.new(centre) * CFrame.new(0, hop, 0)
		* CFrame.Angles(0, yaw, tilt) * CFrame.new(-centre)

	local blink = 0
	if self.BlinkStarted then
		local elapsed = now - self.BlinkStarted
		local close, hold, open = Config.BlinkClose, Config.BlinkHold, Config.BlinkOpen
		if elapsed < close then blink = smooth(elapsed / close)
		elseif elapsed < close + hold then blink = 1
		elseif elapsed < close + hold + open then blink = 1 - smooth((elapsed - close - hold) / open)
		else
			self.BlinkStarted = nil
			if self.DoubleBlink then self.BlinkAt = now + 0.1; self.DoubleBlink = nil end
		end
	end
	for _, eye in ipairs(self.Eyes) do
		local active = blink > 0.02
		show(eye.Lid, active)
		show(eye.Line, blink > 0.85)
		if active then
			local position = centre + eye.Normal * (1.006 * self.Scale)
			local face = CFrame.lookAt(position, position + eye.Normal)
			local height = 0.45 * self.Scale * blink
			eye.Lid.Size = Vector3.new(0.355 * self.Scale, math.max(0.005, height), 0.2 * self.Scale)
			eye.Lid.CFrame = cf * face * CFrame.new(0, (0.45 * self.Scale - height) * 0.5, 0)
			eye.Line.Size = Vector3.new(0.245, 0.033, 0.04) * self.Scale
			eye.Line.CFrame = cf * face * CFrame.new(0, -0.01 * self.Scale, -0.112 * self.Scale)
		end
	end
	if self.Tongue then
		show(self.Tongue, tongue > 0.02)
		show(self.Crease, tongue > 0.1)
		if tongue > 0.02 then
			local normal = Vector3.new(0, -0.17, -math.sqrt(1 - 0.17^2))
			local position = centre + normal * (1.04 * self.Scale)
			local face = CFrame.lookAt(position, position + normal)
			self.Tongue.Size = Vector3.new(0.13, math.max(0.005, 0.2 * tongue), 0.085) * self.Scale
			self.Tongue.CFrame = cf * face * CFrame.new(0, -0.07 * tongue * self.Scale, -0.04 * self.Scale)
			self.Crease.Size = Vector3.new(0.009, 0.075 * tongue, 0.012) * self.Scale
			self.Crease.CFrame = self.Tongue.CFrame * CFrame.new(0, -0.01 * self.Scale, -0.045 * self.Scale)
		end
	end
	return cf
end

return Animator
