-- PurchaseSoundModule
-- Server-side sound router. Purchase logic and cash rewards stay authoritative
-- on the server, then this module tells only the relevant player's client to
-- play local 3D audio at the confirmed world position.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PurchaseSoundModule = {}

local PURCHASE_SOUND_ID = "rbxassetid://110958027662273"
local WORKER_SPAWN_SOUND_ID = "rbxassetid://122282820787536"
local BALL_PICKUP_SOUND_ID = "rbxassetid://76398666043856"
local AREA_UNLOCK_SOUND_ID = "rbxassetid://106850643686640"
local MACHINE_UPGRADE_SOUND_ID = "rbxassetid://73796372556822"

local soundEvent = ReplicatedStorage:FindFirstChild("PurchaseSoundEvent")
if not soundEvent then
	soundEvent = Instance.new("RemoteEvent")
	soundEvent.Name = "PurchaseSoundEvent"
	soundEvent.Parent = ReplicatedStorage
end

local DEFAULTS = {
	volume = 0.9,
	rollOffMinDistance = 10,
	rollOffMaxDistance = 130,
}

local function isPlayer(value)
	return typeof(value) == "Instance" and value:IsA("Player")
end

local function findBasePart(target)
	if typeof(target) ~= "Instance" then
		return nil
	end

	if target:IsA("BasePart") then
		return target
	end

	if target:IsA("Attachment") and target.Parent and target.Parent:IsA("BasePart") then
		return target.Parent
	end

	if target:IsA("Model") then
		local humanoidRootPart = target:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			return humanoidRootPart
		end

		if target.PrimaryPart then
			return target.PrimaryPart
		end
	end

	for _, descendant in ipairs(target:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function getSoundPosition(target)
	local basePart = findBasePart(target)
	return basePart and basePart.Position or nil
end

local function fireSound(player, soundId, target, options)
	if not isPlayer(player) then
		return false
	end

	local position = getSoundPosition(target)
	if not position then
		return false
	end

	options = options or {}
	soundEvent:FireClient(player, {
		soundId = soundId,
		position = position,
		volume = options.volume or DEFAULTS.volume,
		rollOffMinDistance = options.rollOffMinDistance or DEFAULTS.rollOffMinDistance,
		rollOffMaxDistance = options.rollOffMaxDistance or DEFAULTS.rollOffMaxDistance,
		category = options.category,
		minInterval = options.minInterval,
		playbackSpeed = options.playbackSpeed,
	})

	return true
end

function PurchaseSoundModule.PlayPurchaseForTarget(player, target)
	return fireSound(player, PURCHASE_SOUND_ID, target, {
		volume = 0.9,
	})
end

function PurchaseSoundModule.PlayWorkerSpawn(player, target)
	return fireSound(player, WORKER_SPAWN_SOUND_ID, target, {
		volume = 0.95,
		rollOffMinDistance = 10,
		rollOffMaxDistance = 130,
	})
end

function PurchaseSoundModule.PlayBallPickup(player, target)
	return fireSound(player, BALL_PICKUP_SOUND_ID, target, {
		volume = 0.65,
		rollOffMinDistance = 6,
		rollOffMaxDistance = 55,
		category = "BallPickup",
		minInterval = 0.075,
		playbackSpeed = math.random(96, 104) / 100,
	})
end

function PurchaseSoundModule.PlayAreaUnlocked(player, target)
	return fireSound(player, AREA_UNLOCK_SOUND_ID, target, {
		volume = 0.9,
		rollOffMinDistance = 10,
		rollOffMaxDistance = 130,
		category = "AreaUnlock",
		minInterval = 1.25,
	})
end

function PurchaseSoundModule.PlayMachineUpgrade(player, target)
	return fireSound(player, MACHINE_UPGRADE_SOUND_ID, target, {
		volume = 0.9,
		rollOffMinDistance = 10,
		rollOffMaxDistance = 130,
		category = "MachineUpgrade",
		minInterval = 0.08,
	})
end

return PurchaseSoundModule
