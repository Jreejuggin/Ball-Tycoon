--!strict
local module = {}

-----------------
--| Services |--
-----------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------
--| Modules |--
-----------------

local ModulesFolder = ReplicatedStorage.Modules
local ClientOnlyModulesFolder = ModulesFolder.ClientOnlyModules

local DebugHelper = require(ClientOnlyModulesFolder.DebugHelper)
local PlaylistInfo = require(ClientOnlyModulesFolder.PlaylistInfo)
local MusicInfo = require(ClientOnlyModulesFolder.MusicInfo)
local Songs = require(ClientOnlyModulesFolder.Songs)

-----------------
--| Variables |--
-----------------

module.PlaylistsDictionary = {
	["DefaultMusicPlaylist"] = PlaylistInfo.new(
		"Music Playlist",
		{} -- Songs will be filled automatically to the default playlist. (However, they will not be filled in top-down order due to how dictionaries work)
	), 
	
	-- Example playlist
	["MyMusicPlaylist"] = PlaylistInfo.new(
		"My Custom Playlist",
		{
			Songs.SongsDictionary["No More"], -- Make sure these are typed correctly when you change them!
			Songs.SongsDictionary["Diamonds"],
			Songs.SongsDictionary["Sweet Shake"],
		}
	),	
}

-----------------
--| Functions |--
-----------------

local function createDefaultMusicPlaylist()
	for key, song: MusicInfo.MusicInfo in pairs(Songs.SongsDictionary) do
		DebugHelper.PrintMessage("Inserting song '"..song.musicName.."' to DefaultMusicPlaylist", DebugHelper.LogLevel.Log)
		table.insert(module.PlaylistsDictionary["DefaultMusicPlaylist"].musicTable, song)
	end
end

local function freezeTables()
	table.freeze(module.PlaylistsDictionary)
end

createDefaultMusicPlaylist()
freezeTables()

return module