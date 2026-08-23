-----------------
--| Modules |--
-----------------

local MusicInfo = require(game:GetService("ReplicatedStorage").Modules.ClientOnlyModules.MusicInfo)

-----------------
--| Variables |--
-----------------

return {
	--[[
		-------------------------------------------- Add or change songs here! -----------------------------------------------------
		-- EXAMPLE:

		["SONG NAME HERE"] = MusicInfo.new(
			12345678, -- Sound ID here
			"SONG NAME HERE", -- Song name here (again)
			0.5 -- Volume to play the song at.
		),
		
	--]]
	SongsDictionary = {
		-- Song 1
		["Fashion Lobby"] = MusicInfo.new(
			9044539308, -- Sound ID here
			"Fashion Lobby", -- Song name here
			0.18 -- Volume to play the song at.
		),
		-- Song 2
		["Lobby Soirée"] = MusicInfo.new(
			1841998846,
			"Lobby Soirée",
			0.21
		),
		-- Song 3
		["Diamonds"] = MusicInfo.new(
			1846575559,
			"Diamonds",
			0.25
		),
		-- Song 4
		["Playground Of The Stars"] = MusicInfo.new(
			1840684208,
			"Playground Of The Stars",
			0.41
		),
		-- Song 5
		["Roselita"] = MusicInfo.new(
			1838857104,
			"Roselita",
			0.24
		),
		-- Song 6
		["No More"] = MusicInfo.new(
			1846458016,
			"No More",
			0.19
		),
		-- Song 7
		["Town Talk"] = MusicInfo.new(
			1845756489,
			"Town Talk",
			0.24
		),
		-- Song 8
		["Prima Bossa Nova"] = MusicInfo.new(
			1837070127,
			"Prima Bossa Nova",
			0.15
		),
		-- Song 9
		["Easy Mover"] = MusicInfo.new(
			1836759260,
			"Easy Mover",
			0.13
		),
		-- Song 10 (last song in here of the Roblox Copyright Replacement Music)
		["Smooth Nylons"] = MusicInfo.new(
			1845458027,
			"Smooth Nylons",
			0.22
		),
		-- Song 11 (made from same person who did No More)
		["Waltzing Flutes"] = MusicInfo.new(
			1846271108,
			"Waltzing Flutes",
			0.13
		),
		-- Song 12 (made from same person who did Prima Bossa Nova)
		["Follow That Doll"] = MusicInfo.new(
			1836783375,
			"Follow That Doll",
			0.2
		),
		-- Song 13 (made from same person who did Prima Bossa Nova)
		["Bright Young Thing"] = MusicInfo.new(
			1836783461,
			"Bright Young Thing",
			0.15
		),
		-- Song 14 (made from same person who did No More)
		["Bossa Nova Party"] = MusicInfo.new(
			1845764031,
			"Bossa Nova Party",
			0.19
		),
		-- Song 15
		["Time To Relax"] = MusicInfo.new(
			9044702906,
			"Time To Relax",
			0.17
		),
		-- Song 16
		["Sweet Shake"] = MusicInfo.new(
			1836783317,
			"Sweet Shake",
			0.16
		),
		-- Song 17 (made from same person who did Prima Bossa Nova)
		["Rainbow Magic"] = MusicInfo.new(
			1836783325,
			"Rainbow Magic",
			0.19
		),
		-- OG SONGS (These are some songs from the OG MusicGUI)
		["Stepping Up"] = MusicInfo.new(
			1837324424,
			"Stepping Up",
			0.175
		),
		["Arcade Weekend"] = MusicInfo.new(
			1842976958,
			"Arcade Weekend",
			0.175
		),
		["A Short Intermission"] = MusicInfo.new(
			1840684377,
			"A Short Intermission",
			0.175
		),
		--["My Cool Song"] = MusicInfo.new(
		--	1234567890, -- Replace with your Sound ID
		--	"My Cool Song", -- Song name
		--	0.25 -- Set volume to your preference
		--),
	}
}