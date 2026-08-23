-- UISoundConfig
-- Central place to configure UI sound effects. Edit the IDs below once you
-- have real sound assets -- nothing else needs to change.
--
-- IMPORTANT: hoverSoundId is a PLACEHOLDER (empty string = silent/disabled).
-- I tested Roblox's built-in local sound files (rbxasset://sounds/...) and
-- none of them actually resolved to real audio in this project, so I'm not
-- guessing a Marketplace asset ID either -- a wrong one could be deleted,
-- private, or moderated, and would fail silently or throw errors.
--
-- To add a real hover sound:
--   1. Upload an audio file in Roblox Studio: Asset Manager > Import (or
--      grab a free one from the Creator Store > Audio).
--   2. Copy its asset ID (looks like rbxassetid://123456789).
--   3. Paste it below as hoverSoundId.
-- Until then, hover sound is simply skipped -- no errors, no placeholder
-- noise, the hover animation still works on its own.

local UISoundConfig = {
	hoverSoundId = "rbxassetid://133216848606395", -- e.g. "rbxassetid://123456789"
	hoverVolume = 0.5,

	clickSoundId = "rbxassetid://126965103485114", -- optional: set this too if you want a click sound
	clickVolume = 0.6,
}

return UISoundConfig
