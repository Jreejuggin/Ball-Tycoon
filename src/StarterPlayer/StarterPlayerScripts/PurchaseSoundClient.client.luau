-- PurchaseSoundClient
-- Plays buyer-only local 3D sounds sent by the server after real server-side
-- events: purchases, worker spawns, and direct player cash-ball pickups.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local soundEvent = ReplicatedStorage:WaitForChild("PurchaseSoundEvent")
local SFXSettings = require(ReplicatedStorage:WaitForChild("SFXSettings"))

local SOUND_IDS_TO_PRELOAD = {
	"rbxassetid://110958027662273",
	"rbxassetid://122282820787536",
	"rbxassetid://76398666043856",
	"rbxassetid://111426373017081",
	"rbxassetid://73964096479702",
	"rbxassetid://78005173847052",
	"rbxassetid://106850643686640",
	"rbxassetid://73796372556822",
}

local lastPlayedByCategory = {}

local function preloadSounds()
	local preloadSounds = {}
	for _, soundId in ipairs(SOUND_IDS_TO_PRELOAD) do
		local sound = Instance.new("Sound")
		sound.Name = "PreloadGameSound"
		sound.SoundId = soundId
		sound.Volume = 0
		SFXSettings.ApplyToSound(sound)
		sound.Parent = SoundService
		table.insert(preloadSounds, sound)
	end

	pcall(function()
		ContentProvider:PreloadAsync(preloadSounds)
	end)

	for _, sound in ipairs(preloadSounds) do
		sound:Destroy()
	end
end

task.spawn(preloadSounds)

local function canPlayCategory(category, minInterval)
	if typeof(category) ~= "string" or category == "" then
		return true
	end

	local now = os.clock()
	local lastPlayed = lastPlayedByCategory[category]
	if lastPlayed and now - lastPlayed < (tonumber(minInterval) or 0) then
		return false
	end

	lastPlayedByCategory[category] = now
	return true
end

local function playLocalPositionalSound(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.soundId) ~= "string" or payload.soundId == "" then
		return
	end
	if typeof(payload.position) ~= "Vector3" then
		return
	end
	if not canPlayCategory(payload.category, payload.minInterval) then
		return
	end

	workspace:SetAttribute("LastLocalGameSoundId", payload.soundId)
	workspace:SetAttribute("LastLocalGameSoundCategory", payload.category or "")
	workspace:SetAttribute("LastLocalGameSoundAt", os.clock())

	local anchor = Instance.new("Part")
	anchor.Name = "LocalGameSoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = payload.position
	anchor.Parent = workspace

	local sound = Instance.new("Sound")
	sound.Name = "LocalGameSFX"
	sound.SoundId = payload.soundId
	sound.Volume = tonumber(payload.volume) or 0.9
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = tonumber(payload.rollOffMinDistance) or 10
	sound.RollOffMaxDistance = tonumber(payload.rollOffMaxDistance) or 130
	sound.PlaybackSpeed = tonumber(payload.playbackSpeed) or 1
	sound.Looped = false
	SFXSettings.ApplyToSound(sound)
	sound.Parent = anchor

	local endedConnection
	endedConnection = sound.Ended:Connect(function()
		if endedConnection then
			endedConnection:Disconnect()
		end
		task.delay(1, function()
			if anchor.Parent then
				anchor:Destroy()
			end
		end)
	end)

	sound:Play()
	Debris:AddItem(anchor, 10)
end

soundEvent.OnClientEvent:Connect(playLocalPositionalSound)
