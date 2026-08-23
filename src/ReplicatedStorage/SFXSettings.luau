-- SFXSettings
-- Central client-side settings for every non-music sound effect.
-- Route any new Sound through SFXSettings.ApplyToSound(sound); it will then
-- automatically respect the player's SFX setting without extra UI wiring.

local SoundService = game:GetService("SoundService")

local SFXSettings = {}

local SFX_GROUP_NAME = "SFX"
local DEFAULT_VOLUME = 1
local isMuted = false

function SFXSettings.GetSoundGroup()
	return SoundService:WaitForChild(SFX_GROUP_NAME)
end

function SFXSettings.ApplyToSound(sound)
	assert(sound:IsA("Sound"), "SFXSettings.ApplyToSound expects a Sound")
	sound.SoundGroup = SFXSettings.GetSoundGroup()
	return sound
end

function SFXSettings.SetMuted(shouldMute)
	isMuted = shouldMute == true
	SFXSettings.GetSoundGroup().Volume = isMuted and 0 or DEFAULT_VOLUME
end

function SFXSettings.IsMuted()
	return isMuted
end

return SFXSettings

--NOTE: For future sound effects, use this one line whenever a new non-music Sound is created:
--local SFXSettings = require(game.ReplicatedStorage.SFXSettings)
--SFXSettings.ApplyToSound(sound)