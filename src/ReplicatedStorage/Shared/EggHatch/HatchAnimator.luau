-- HatchAnimator (ModuleScript, CLIENT ONLY)
-- Location: ReplicatedStorage/Shared/EggHatch/HatchAnimator
--
-- Plays the egg hatch animation for a result the SERVER already decided.
-- Nothing here can change what the player gets: the server rolls, grants and saves first,
-- then fires the result to this client, and this module just shows it.
--
-- Two presentations:
--   HatchAnimator.Enqueue(eggId, results)          Full-screen "pet sim" hatch (default, mobile-friendly)
--                                                  results = { { PetId = "CoinPup", Rarity = "Rare" }, ... }
--   HatchAnimator.PlayWorld(baseCFrame, eggId, opts) 3D hatch on the nest's PetSpot (optional)
--   HatchAnimator.Preload()                        Preloads every configured image (call once on join)
--
-- The screen UI is built in code, so nothing needs to be set up by hand in StarterGui.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

assert(RunService:IsClient(), "HatchAnimator must only be required from the client")

local Config = require(script.Parent:WaitForChild("HatchConfig"))
local KitData = require(script.Parent:WaitForChild("HatchKitData"))

local T = Config.Timing
local player = Players.LocalPlayer
local rng = Random.new()

local HatchAnimator = {}

----------------------------------------------------------------------------------------------------
-- Small utilities
----------------------------------------------------------------------------------------------------

-- Cleanup bag: everything created during one hatch goes in here and is destroyed at the end,
-- even if the sequence errors, so nothing leaks (connections, GUIs, parts).
local Bag = {}
Bag.__index = Bag

function Bag.new()
	return setmetatable({ items = {} }, Bag)
end

function Bag:add(item)
	table.insert(self.items, item)
	return item
end

function Bag:clean()
	for i = #self.items, 1, -1 do
		local item = self.items[i]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			task.spawn(item)
		end
		self.items[i] = nil
	end
end

local function hasId(id)
	return type(id) == "string" and id ~= ""
end

-- Skip support: tapping speeds up every step that hasn't started yet, and ends the "hold".
local Playback = { speed = 1, skipHold = false, phase = "idle" }

local function dur(seconds)
	return seconds / Playback.speed
end

local function waitScaled(seconds)
	task.wait(dur(seconds))
end

local function tween(obj, seconds, props, style, direction, delayTime)
	local info = TweenInfo.new(dur(seconds), style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out, 0, false, dur(delayTime or 0))
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end

local function playSound(id)
	if not hasId(id) then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Config.Sounds.Volume
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	Debris:AddItem(sound, 6)
end

local function rarityInfo(rarity)
	return Config.Rarity[rarity] or Config.Rarity.Common
end

local function newImage(parent, name, image, zIndex)
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image or ""
	img.ZIndex = zIndex or 1
	img.Parent = parent
	return img
end

-- Use the imported models when PNG asset ids have not been supplied.
-- Every egg layer uses the same camera, keeping the two shell halves aligned.
local function modelPreview(parent, template, eggId, shellName)
	if not template then return end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ModelPreview"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = parent.ZIndex
	viewport.Ambient = Color3.fromRGB(190, 190, 205)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1, -2)
	viewport.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local clone = template:Clone()
	local parts = {}
	if clone:IsA("BasePart") then table.insert(parts, clone) end
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then table.insert(parts, part) end
	end
	local centre, size
	local kit = eggId and KitData[eggId]
	if kit then
		centre, size = kit.Whole.Centre, kit.Whole.Size
		for _, part in ipairs(parts) do
			if kit[part.Name] then part.CFrame = CFrame.new(kit[part.Name].Centre) end
			if shellName and part.Name ~= shellName then part:Destroy() end
		end
	else
		local cf
		if clone:IsA("Model") then cf, size = clone:GetBoundingBox() else cf, size = clone.CFrame, clone.Size end
		centre = Vector3.zero
		for _, part in ipairs(parts) do part.CFrame = cf:ToObjectSpace(part.CFrame) end
	end
	clone.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	local distance = math.max(size.X, size.Y, size.Z) * 2.15
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0.12 * size.Y, -distance), centre)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

local function hatchTemplate(eggId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("EggHatch")
	local template = folder and folder:FindFirstChild(eggId .. "_Hatch")
	if template then return template end
	local kit = KitData[eggId]
	if not kit then return nil end
	local placeholder = Instance.new("Model")
	local egg = Instance.new("Part")
	egg.Name = "Whole"
	egg.Shape = Enum.PartType.Ball
	egg.Size = kit.Whole.Size
	egg.CFrame = CFrame.new(kit.Whole.Centre)
	egg.Color = kit.ShardColor
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.Parent = placeholder
	Debris:AddItem(placeholder, 10)
	return placeholder
end

local function newScaledFrame(parent, name, zIndex)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = zIndex or 1
	frame.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = frame
	return frame, scale
end

-- Fades every visible element under root to fully transparent.
local function fadeOutAll(root, seconds)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ImageLabel") or obj:IsA("ViewportFrame") then
			tween(obj, seconds, { ImageTransparency = 1 })
		elseif obj:IsA("TextLabel") then
			tween(obj, seconds, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
		if obj:IsA("GuiObject") and obj.BackgroundTransparency < 1 then
			tween(obj, seconds, { BackgroundTransparency = 1 })
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Screen hatch
----------------------------------------------------------------------------------------------------
local SLOT_HEIGHT = { 0.46, 0.36, 0.3 } -- fraction of screen height, by number of eggs shown
local SLOT_SPACING = 0.28               -- fraction of screen width between egg centres
local CRACK_Y = 0.55                    -- where the crack sits inside the egg images (shards start here)

local function createRoot(bag)
	local gui = bag:add(Instance.new("ScreenGui"))
	gui.Name = "EggHatchGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = 1
	backdrop.Parent = gui

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 40
	flash.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, backdrop, flash
end

-- Builds one egg slot. All egg layers are the same size at the same spot, because the
-- PNGs were rendered with the same camera: stacking them lines up exactly.
local function createSlot(gui, index, count, eggId, result)
	local images = Config.EggImages[eggId] or {}
	local crackIds = images.Crack or {}
	local kit = KitData[eggId]
	local rarity = rarityInfo(result.Rarity)

	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. index
	slot.BackgroundTransparency = 1
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.Position = UDim2.fromScale(0.5 + (index - (count + 1) / 2) * SLOT_SPACING, 0.46)
	local h = SLOT_HEIGHT[count] or SLOT_HEIGHT[#SLOT_HEIGHT]
	slot.Size = UDim2.fromScale(h, h)
	slot.ZIndex = 2
	slot.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = slot

	-- Behind everything: rarity light rays
	local burst = newImage(slot, "Burst", Config.SharedImages.Burst, 3)
	burst.Size = UDim2.fromScale(0, 0)
	burst.ImageColor3 = rarity.Color
	burst.ImageTransparency = 0.1
	if not hasId(Config.SharedImages.Burst) then
		for i = 1, 12 do
			local ray = Instance.new("Frame")
			ray.Name = "Ray"
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.fromScale(0.055, 1)
			ray.Rotation = i * 30
			ray.BorderSizePixel = 0
			ray.BackgroundColor3 = rarity.Color
			ray.BackgroundTransparency = 0.35
			ray.ZIndex = 3
			ray.Parent = burst
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 90
			gradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1)})
			gradient.Parent = ray
		end
	end

	-- Egg (scaled as one group with UIScale)
	local eggFrame, eggScale = newScaledFrame(slot, "Egg", 4)
	local whole = newImage(eggFrame, "Whole", images.Whole, 5)
	local crack = newImage(eggFrame, "Crack", "", 6)
	local top = newImage(eggFrame, "Top", images.Top, 6)
	local bottom = newImage(eggFrame, "Bottom", images.Bottom, 5)
	top.Visible = false
	bottom.Visible = false
	local template = hatchTemplate(eggId)
	if not hasId(images.Whole) then modelPreview(whole, template, eggId) end
	if not hasId(images.Top) then modelPreview(top, template, eggId, "ShellTop") end
	if not hasId(images.Bottom) then modelPreview(bottom, template, eggId, "ShellBottom") end

	-- Pet + labels (scaled as one group)
	local petFrame, petScale = newScaledFrame(slot, "Pet", 8)
	local petIcon = newImage(petFrame, "PetIcon", Config.GetPetIcon(result.PetId), 9)
	if not hasId(Config.GetPetIcon(result.PetId)) then
		modelPreview(petIcon, Config.GetPetModel(result.PetId))
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PetName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.fromScale(0.5, 0.98)
	nameLabel.Size = UDim2.fromScale(1.3, 0.14)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.Text = Config.GetPetDisplayName(result.PetId)
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(30, 27, 46)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.ZIndex = 10
	nameLabel.Parent = petFrame

	local tagId = Config.SharedImages.RarityTags[result.Rarity]
	if hasId(tagId) then
		local tag = newImage(petFrame, "RarityTag", tagId, 10)
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.fromScale(0.5, 1.13)
		tag.Size = UDim2.fromScale(0.62, 0.19)
	else -- text fallback until the tag images are uploaded
		local tag = nameLabel:Clone()
		tag.Name = "RarityText"
		tag.Position = UDim2.fromScale(0.5, 1.13)
		tag.Size = UDim2.fromScale(1, 0.11)
		tag.Text = string.upper(result.Rarity)
		tag.TextColor3 = rarity.Color
		tag.Parent = petFrame
	end

	return {
		slot = slot, burst = burst, eggScale = eggScale, whole = whole, crack = crack,
		top = top, bottom = bottom, petScale = petScale, crackIds = crackIds,
		rarity = rarity, result = result,
		shardColor = kit and kit.ShardColor or Color3.new(1, 1, 1),
	}
end

local function spawnShards(s, count)
	if not hasId(Config.SharedImages.Shard) then
		return
	end
	for _ = 1, count do
		local shard = newImage(s.slot, "Shard", Config.SharedImages.Shard, 7)
		shard.ImageColor3 = s.shardColor
		local size = rng:NextNumber(0.09, 0.15)
		shard.Size = UDim2.fromScale(size, size)
		shard.Position = UDim2.fromScale(rng:NextNumber(0.35, 0.65), CRACK_Y)
		shard.Rotation = rng:NextNumber(0, 360)
		-- Mostly outward and upward, like a real burst
		local angle = math.rad(rng:NextNumber(-170, -10))
		local dist = rng:NextNumber(0.45, 0.8)
		local target = UDim2.fromScale(0.5 + math.cos(angle) * dist, CRACK_Y + math.sin(angle) * dist * 0.8 + 0.25)
		tween(shard, T.SplitTime * 1.3, { Position = target, Rotation = shard.Rotation + rng:NextNumber(-400, 400) },
			Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tween(shard, T.SplitTime * 0.7, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, T.SplitTime * 0.6)
	end
end

local function spawnSparkles(s, count)
	if count <= 0 or not hasId(Config.SharedImages.Sparkle) then
		return
	end
	for i = 1, count do
		local sparkle = newImage(s.slot, "Sparkle", Config.SharedImages.Sparkle, 11)
		local size = rng:NextNumber(0.1, 0.2)
		sparkle.Size = UDim2.fromScale(size, size)
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(0.38, 0.62)
		sparkle.Position = UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius)
		sparkle.ImageColor3 = s.rarity.Color:Lerp(Color3.new(1, 1, 1), 0.5)
		sparkle.ImageTransparency = 1
		-- Endless twinkle; destroyed with the GUI at the end
		local info = TweenInfo.new(rng:NextNumber(0.35, 0.6), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut,
			-1, true, (i - 1) * 0.08)
		TweenService:Create(sparkle, info, { ImageTransparency = 0, Rotation = 90 }):Play()
	end
end

local function playScreenGroup(bag, eggId, results, opts)
	opts = opts or {}
	Playback.speed, Playback.skipHold, Playback.phase = 1, false, "intro"

	local gui, backdrop, flash = createRoot(bag)
	local slots = {}
	for i, result in ipairs(results) do
		slots[i] = createSlot(gui, i, #results, eggId, result)
	end

	bag:add(UserInputService.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			if Playback.phase == "hold" then
				Playback.skipHold = true
			else
				Playback.speed = T.SkipSpeedMultiplier
			end
		end
	end))

	-- 1) Dim the screen and pop the egg in
	tween(backdrop, T.BackdropFade, { BackgroundTransparency = 0.45 })
	if opts.RevealOnly then
		-- The egg already broke open in the world (E-open on the nest): go straight to the reveal
		for _, s in ipairs(slots) do
			s.whole.Visible = false
			s.crack.Visible = false
		end
		tween(flash, 0.06, { BackgroundTransparency = 0.35 })
		waitScaled(0.06)
		tween(flash, T.FlashOut, { BackgroundTransparency = 1 })
	else
		for _, s in ipairs(slots) do
			tween(s.eggScale, T.DropIn, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
		waitScaled(T.DropIn + 0.15)

		-- 2) Shake rounds, each ending with the next crack stage
		Playback.phase = "shake"
		for round = 1, T.ShakeRounds do
			playSound(Config.Sounds.Shake)
			local angle = Config.ShakeAngles[round] or Config.ShakeAngles[#Config.ShakeAngles]
			for swing = 1, T.SwingsPerRound do
				local target = (swing % 2 == 1) and angle or -angle
				for _, s in ipairs(slots) do
					tween(s.whole, T.SwingTime, { Rotation = target }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					tween(s.crack, T.SwingTime, { Rotation = target }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				end
				waitScaled(T.SwingTime)
			end
			for _, s in ipairs(slots) do
				tween(s.whole, T.SwingTime, { Rotation = 0 })
				tween(s.crack, T.SwingTime, { Rotation = 0 })
				if hasId(s.crackIds[round]) then
					s.crack.Image = s.crackIds[round]
				end
				-- little "thump" as the crack appears
				s.eggScale.Scale = 1.08
				tween(s.eggScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end
			playSound(Config.Sounds.Crack)
			waitScaled(T.SwingTime + T.PauseBetweenRounds)
		end

		-- 3) Flash, the shell breaks, halves fly apart, shards burst out
		Playback.phase = "break"
		tween(flash, T.FlashIn, { BackgroundTransparency = 0.1 })
		waitScaled(T.FlashIn)
		playSound(Config.Sounds.Pop)
		for _, s in ipairs(slots) do
			s.whole.Visible = false
			s.crack.Visible = false
			s.top.Visible = true
			s.bottom.Visible = true
			local side = rng:NextNumber() < 0.5 and -1 or 1
			tween(s.top, T.SplitTime, { Position = UDim2.fromScale(0.5 + side * 0.12, 0.08), Rotation = side * rng:NextNumber(18, 32) })
			tween(s.top, T.SplitTime * 0.6, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, T.SplitTime * 0.4)
			tween(s.bottom, T.SplitTime, { Position = UDim2.fromScale(0.5, 0.66) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(s.bottom, T.SplitTime * 0.6, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, T.SplitTime * 0.3)
			spawnShards(s, 8)
		end
		tween(flash, T.FlashOut, { BackgroundTransparency = 1 })
	end

	-- 4) Reveal: rays + pet pop + name/rarity + sparkles for the good stuff
	Playback.phase = "reveal"
	local best = slots[1] -- the rarest pet in this group decides the reveal sound and hold time
	for _, s in ipairs(slots) do
		tween(s.burst, T.RevealPop, { Size = UDim2.fromScale(1.75, 1.75) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.08)
		-- small delay so the shell halves visibly clear before the pet pops in
		tween(s.petScale, T.RevealPop, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.18)
		spawnSparkles(s, s.rarity.Sparkles)
		if s.rarity.ExtraHold > best.rarity.ExtraHold then
			best = s
		end
	end
	local extraHold = best.rarity.ExtraHold
	playSound(Config.Sounds.Reveal[best.result.Rarity])

	-- Rays spin slowly; Mythic rays cycle through the rainbow
	bag:add(RunService.RenderStepped:Connect(function(dt)
		for _, s in ipairs(slots) do
			s.burst.Rotation += dt * 35
			if s.rarity.Rainbow then
				s.burst.ImageColor3 = Color3.fromHSV((os.clock() * 0.35) % 1, 0.6, 1)
				for _, ray in ipairs(s.burst:GetChildren()) do
					if ray:IsA("Frame") then ray.BackgroundColor3 = s.burst.ImageColor3 end
				end
			end
		end
	end))
	waitScaled(T.RevealPop + 0.18)

	-- 5) Hold (tap to close), then fade out
	Playback.phase = "hold"
	local holdEnd = os.clock() + T.Hold + extraHold
	while os.clock() < holdEnd and not Playback.skipHold do
		task.wait()
	end
	Playback.speed = 1
	Playback.phase = "outro"
	fadeOutAll(gui, T.FadeOut)
	task.wait(T.FadeOut)
end

-- Queue so results that arrive while a hatch is playing wait their turn.
local queue = {}
local running = false

local function runQueue()
	running = true
	while #queue > 0 do
		local job = table.remove(queue, 1)
		local max = Config.MaxSlotsOnScreen
		for first = 1, #job.results, max do
			local group = table.move(job.results, first, math.min(first + max - 1, #job.results), 1, {})
			local bag = Bag.new()
			local ok, err = pcall(playScreenGroup, bag, job.eggId, group, job.opts)
			bag:clean()
			if not ok then
				warn("[HatchAnimator] screen hatch failed: " .. tostring(err))
			end
		end
	end
	Playback.phase = "idle"
	running = false
end

-- opts.RevealOnly = true skips the egg (used after the egg already cracked open on the nest)
function HatchAnimator.Enqueue(eggId: string, results, opts)
	if type(results) ~= "table" or #results == 0 then
		return
	end
	table.insert(queue, { eggId = eggId, results = results, opts = opts })
	if not running then
		running = true
		task.spawn(runQueue)
	end
end

function HatchAnimator.IsPlaying(): boolean
	return running
end

----------------------------------------------------------------------------------------------------
-- 3D hatch on the nest (optional)
----------------------------------------------------------------------------------------------------
local function findHatchTemplate(eggId)
	local node = ReplicatedStorage
	for _, name in ipairs(Config.WorldHatchFolderPath) do
		node = node and node:FindFirstChild(name)
	end
	return node and node:FindFirstChild(eggId .. "_Hatch")
end

local function prepLocalPart(part, parent)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Parent = parent
	return part
end

-- Runs fn(alpha) every frame for `seconds`, alpha going 0 -> 1. Yields until done.
local function animate(seconds, fn)
	local length = math.max(seconds, 1 / 60) -- world timing is independent of screen skip taps
	local start = os.clock()
	while true do
		local alpha = math.min((os.clock() - start) / length, 1)
		fn(alpha)
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

--[[
	baseCFrame : the egg's BOTTOM-CENTRE in the world (e.g. PetSpot.WorldCFrame), same orientation the egg uses
	eggId      : e.g. "CottonCandyEgg"
	opts.HideParts : { BasePart }  real egg parts to hide on THIS client while the local copy animates
	opts.PetModel  : Model or BasePart template of the hatched pet to rise out of the shell (optional)
	opts.Rarity    : rarity name, tints the glow
	opts.OnBreak   : function called the moment the shell breaks (e.g. start the screen reveal)
	Yields until the animation is finished and returns true, or false if it couldn't play.
	Everything it creates is local to this client.
]]
function HatchAnimator.PlayWorld(baseCFrame: CFrame, eggId: string, opts)
	opts = opts or {}
	local kit = KitData[eggId]
	local template = findHatchTemplate(eggId)
	if not kit or not template then
		warn("[HatchAnimator] no 3D hatch kit for " .. tostring(eggId))
		return false
	end
	local rarity = rarityInfo(opts.Rarity)
	local bag = Bag.new()

	local ok, err = pcall(function()
		local fx = bag:add(Instance.new("Model"))
		fx.Name = "LocalEggHatchFX"
		fx.Parent = workspace

		local topTemplate = template:FindFirstChild("ShellTop")
		local bottomTemplate = template:FindFirstChild("ShellBottom")
		assert(topTemplate and bottomTemplate, eggId .. "_Hatch needs MeshParts named ShellTop and ShellBottom")
		local top = prepLocalPart(topTemplate:Clone(), fx)
		local bottom = prepLocalPart(bottomTemplate:Clone(), fx)
		local topOffset = CFrame.new(kit.ShellTop.Centre)
		local bottomOffset = CFrame.new(kit.ShellBottom.Centre)

		-- Hide the real egg on this client only; restore at the end if it still exists
		for _, part in ipairs(opts.HideParts or {}) do
			if typeof(part) == "Instance" and part:IsA("BasePart") then
				local previous = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 1
				bag:add(function()
					if part.Parent then
						part.LocalTransparencyModifier = previous
					end
				end)
			end
		end

		-- Tilt both halves together around the egg's bottom so it rocks like one egg
		local function place(angleDeg)
			local pivot = baseCFrame * CFrame.Angles(0, 0, math.rad(angleDeg))
			top.CFrame = pivot * topOffset
			bottom.CFrame = pivot * bottomOffset
		end
		place(0)

		local glow = Instance.new("Highlight")
		glow.Adornee = fx
		glow.FillColor = Color3.new(1, 1, 1)
		glow.OutlineColor = rarity.Color
		glow.FillTransparency = 1
		glow.OutlineTransparency = 0.4
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = fx

		-- 1) Shake rounds, getting stronger and brighter
		for round = 1, T.ShakeRounds do
			playSound(Config.Sounds.Shake)
			local amp = (Config.ShakeAngles[round] or 15) * 0.6 -- 3D tilts read stronger than 2D
			local length = T.SwingsPerRound * T.SwingTime * 2
			animate(length, function(a)
				local envelope = math.sin(math.pi * a)
				place(amp * envelope * math.sin(a * T.SwingsPerRound * math.pi))
			end)
			place(0)
			glow.FillTransparency = 1 - 0.18 * round
			playSound(Config.Sounds.Crack)
			task.wait(T.PauseBetweenRounds)
		end

		-- 2) Break: light flash + shard particles + halves fly apart
		if opts.OnBreak then
			task.spawn(opts.OnBreak)
		end
		playSound(Config.Sounds.Pop)
		local burstPoint = Instance.new("Attachment")
		burstPoint.Parent = bottom
		burstPoint.WorldPosition = (baseCFrame * CFrame.new(0, kit.CrackHeight, 0)).Position

		local light = Instance.new("PointLight")
		light.Color = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.5)
		light.Range = 14
		light.Brightness = 0
		light.Parent = burstPoint
		tween(light, 0.08, { Brightness = 6 })
		task.delay(dur(0.1), function()
			if light.Parent then
				tween(light, 0.6, { Brightness = 0 })
			end
		end)

		if hasId(Config.SharedImages.Shard) then
			local shards = Instance.new("ParticleEmitter")
			shards.Texture = Config.SharedImages.Shard
			shards.Color = ColorSequence.new(kit.ShardColor)
			shards.Size = NumberSequence.new(0.45, 0.2)
			shards.Lifetime = NumberRange.new(0.6, 1)
			shards.Speed = NumberRange.new(9, 15)
			shards.SpreadAngle = Vector2.new(75, 75)
			shards.EmissionDirection = Enum.NormalId.Top
			shards.Acceleration = Vector3.new(0, -35, 0)
			shards.Rotation = NumberRange.new(0, 360)
			shards.RotSpeed = NumberRange.new(-360, 360)
			shards.Enabled = false
			shards.Parent = burstPoint
			shards:Emit(18)
		end
		if hasId(Config.SharedImages.Sparkle) then
			local sparkles = Instance.new("ParticleEmitter")
			sparkles.Texture = Config.SharedImages.Sparkle
			sparkles.Color = ColorSequence.new(rarity.Color:Lerp(Color3.new(1, 1, 1), 0.4))
			sparkles.LightEmission = 1
			sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
			sparkles.Lifetime = NumberRange.new(0.5, 0.9)
			sparkles.Speed = NumberRange.new(5, 10)
			sparkles.SpreadAngle = Vector2.new(180, 180)
			sparkles.Enabled = false
			sparkles.Parent = burstPoint
			sparkles:Emit(10 + rarity.Sparkles * 2)
		end

		-- Simple shell fragments keep the effect visible without uploaded PNGs.
		local fragments = {}
		if not hasId(Config.SharedImages.Shard) then
			for i = 1, 12 do
				local shard = Instance.new("WedgePart")
				shard.Size = Vector3.new(0.14, 0.22, 0.28)
				shard.Color = kit.ShardColor
				shard.Material = Enum.Material.SmoothPlastic
				prepLocalPart(shard, fx)
				local angle = i / 12 * math.pi * 2
				table.insert(fragments, {part = shard, velocity = Vector3.new(math.cos(angle) * 5, rng:NextNumber(5, 9), math.sin(angle) * 5)})
			end
		end

		-- burstPoint lives on the bottom half; keep it in the world while the half fades
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local spin = rng:NextNumber(200, 320) * side
		glow.FillTransparency = 1
		local splitDone = false
		task.spawn(function()
		local splitOk, splitError = pcall(function()
		animate(T.SplitTime * 1.4, function(a)
			local elapsed = a * T.SplitTime * 1.4
			for _, fragment in ipairs(fragments) do
				fragment.part.CFrame = baseCFrame * CFrame.new(Vector3.new(0, kit.CrackHeight, 0)
					+ fragment.velocity * elapsed + Vector3.new(0, -12 * elapsed * elapsed, 0))
					* CFrame.Angles(elapsed * 8, elapsed * 5, elapsed * 4)
				fragment.part.Transparency = math.max(0, (a - 0.6) / 0.4)
			end
			-- top half: hops up and away, tumbling, fades at the end
			local up = 3.2 * a - 1.4 * a * a
			top.CFrame = baseCFrame * CFrame.new(side * 1.4 * a, up, 0) * topOffset
				* CFrame.Angles(math.rad(spin * 0.3 * a), 0, math.rad(spin * a))
			top.Transparency = math.max(0, (a - 0.55) / 0.45)
			-- bottom half: sinks a little and fades
			bottom.CFrame = baseCFrame * CFrame.new(0, -0.5 * a, 0) * bottomOffset
			bottom.Transparency = math.max(0, (a - 0.35) / 0.65)
		end)
		end)
		if not splitOk then warn("[HatchAnimator] shell split: " .. tostring(splitError)) end
		splitDone = true
		end)

		-- 3) Pet rises out of the shell (optional)
		local pet = opts.PetModel and opts.PetModel:Clone()
		if pet then
			local parts = {}
			if pet:IsA("BasePart") then
				table.insert(parts, pet)
			end
			for _, d in ipairs(pet:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(parts, d)
				end
			end
			-- Per-part CFrames relative to the bounding box (avoids PivotTo / stale WorldPivotData)
			local boxCFrame, boxSize
			if pet:IsA("Model") then
				boxCFrame, boxSize = pet:GetBoundingBox()
			else
				boxCFrame, boxSize = pet.CFrame, pet.Size
			end
			local relative = {}
			for _, p in ipairs(parts) do
				relative[p] = boxCFrame:ToObjectSpace(p.CFrame)
				prepLocalPart(p, p.Parent)
			end
			pet.Parent = fx
			local startCF = baseCFrame * CFrame.new(0, boxSize.Y * 0.3, 0)
			local endCF = baseCFrame * CFrame.new(0, boxSize.Y * 0.5 + 0.8, 0)
			animate(T.RevealPop * 1.4, function(a)
				local eased = TweenService:GetValue(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				local cf = startCF:Lerp(endCF, eased) * CFrame.Angles(0, math.rad(360 * eased), 0)
				for p, rel in pairs(relative) do
					p.CFrame = cf * rel
				end
			end)
			playSound(Config.Sounds.Reveal[opts.Rarity or "Common"])
			task.wait(dur(T.Hold + rarity.ExtraHold))
			animate(T.FadeOut, function(a)
				for p in pairs(relative) do
					p.LocalTransparencyModifier = a
				end
			end)
		end
		while not splitDone do RunService.Heartbeat:Wait() end
	end)
	bag:clean()
	if not ok then
		warn("[HatchAnimator] world hatch failed: " .. tostring(err))
	end
	return ok
end

----------------------------------------------------------------------------------------------------
-- Preload every configured image so the hatch never shows blank frames
----------------------------------------------------------------------------------------------------
function HatchAnimator.Preload()
	local ids = {}
	local function add(id)
		if hasId(id) then
			table.insert(ids, id)
		end
	end
	add(Config.SharedImages.Burst)
	add(Config.SharedImages.Sparkle)
	add(Config.SharedImages.Shard)
	for _, id in pairs(Config.SharedImages.RarityTags) do
		add(id)
	end
	for _, images in pairs(Config.EggImages) do
		add(images.Whole)
		add(images.Top)
		add(images.Bottom)
		for _, id in ipairs(images.Crack or {}) do
			add(id)
		end
	end
	for _, id in pairs(Config.PetIcons) do add(id) end
	if #ids > 0 then
		ContentProvider:PreloadAsync(ids)
	end
end

return HatchAnimator
