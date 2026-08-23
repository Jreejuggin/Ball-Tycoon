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

local MusicInfo = require(ClientOnlyModulesFolder.MusicInfo)
local PlaylistInfo = require(ClientOnlyModulesFolder.PlaylistInfo)
local PlaylistSettings = require(ClientOnlyModulesFolder.PlaylistSettings)
local DebugHelper = require(ClientOnlyModulesFolder.DebugHelper)

-----------------
--| Variables |--
-----------------

local ClientOnlyEventsFolder = ReplicatedStorage.Events.ClientOnlyEvents
local OnMusicChangedEvent = ClientOnlyEventsFolder.OnMusicChanged

local currentPlaylistInfo: PlaylistInfo.PlaylistInfo? = nil
local currentPlayingSongInfo: MusicInfo.MusicInfo? = nil
local isCurrentPlayingSongMuted: boolean = false
local isCurrentPlayingSongLooping: boolean = false

-- Used to save the last played song index in a playlist.
-- So, when switching playlists, it won't always reset at the first song.
local playlistsLastMusicPlayedIndexDictionary: {[PlaylistInfo.PlaylistInfo]: number} = {}

-- Used to save the loaded song array for each playlist (so that shuffling will work).
local playlistsLoadedSongTableDictionary: {[PlaylistInfo.PlaylistInfo]: {MusicInfo.MusicInfo}} = {}

-----------------
--| Functions |--
-----------------

-- [[ LOCAL FUNCTIONS ]]

--[[
	Gets the playlist loaded song table from the 'playlistsLoadedSongTableDictionary' if it exists.
	* Meant to decouple functions from using 'playlistsLoadedSongTableDictionary' directly to get loaded song table.
]]
local function tryGetPlaylistLoadedSongTable(playlist: PlaylistInfo.PlaylistInfo): {MusicInfo.MusicInfo}
	
	return playlistsLoadedSongTableDictionary[playlist]
end

local function getMusicBasedOnLastPlayedSongInPlaylist(playlist: PlaylistInfo.PlaylistInfo): MusicInfo.MusicInfo?
	if playlist == nil then
		DebugHelper.PrintMessage("Given playlist is nil!", DebugHelper.LogLevel.Error)
		return nil
	end
	
	-- Default to first song in playlist.
	local lastPlayedSongIndex = 1
	
	for key, playlistLastMusicPlayedIndex in playlistsLastMusicPlayedIndexDictionary do
		if key == playlist then
			lastPlayedSongIndex = playlistLastMusicPlayedIndex
		end
	end
	
	local playlistLoadedSongTable = tryGetPlaylistLoadedSongTable(playlist)

	if playlistLoadedSongTable == nil then
		DebugHelper.PrintMessage("Could not find playlist: '"..playlist.playlistName.."' in playlistsLoadedSongTableDictionary!", DebugHelper.LogLevel.Error)
		return nil
	end
	
	return playlistLoadedSongTable[lastPlayedSongIndex]
end

local function tryGetIndexOfSongInMusicTable(songToFind: MusicInfo.MusicInfo?, musicTable: {MusicInfo.MusicInfo}): number?
	if songToFind == nil then
		return nil
	end
	
	for i, song in musicTable do
		if song == songToFind then
			return i
		end
	end
	
	return nil
end

local function savePlaylistLastMusicPlayedIndex(playlist: PlaylistInfo.PlaylistInfo)
	if playlist == nil then
		DebugHelper.PrintMessage("Given playlist is nil!", DebugHelper.LogLevel.Error)
		return
	end
	
	local playlistLoadedSongTable = tryGetPlaylistLoadedSongTable(playlist)
	
	if playlistLoadedSongTable == nil then
		DebugHelper.PrintMessage("playlistLoadedMusicTable of playlist: '"..playlist.playlistName.."' is nil", DebugHelper.LogLevel.Error)
		return
	end
	
	local currentSongIndex = tryGetIndexOfSongInMusicTable(currentPlayingSongInfo, playlistLoadedSongTable)
	
	if currentSongIndex == nil then
		DebugHelper.PrintMessage("currentSongIndex is nil", DebugHelper.LogLevel.Error)
		return
	end
	
	playlistsLastMusicPlayedIndexDictionary[playlist] = currentSongIndex
end

local function doesPlaylistHaveLastMusicPlayedIndexSave(playlist: PlaylistInfo.PlaylistInfo): boolean
	if playlist == nil then
		return false
	end

	for key, playlistLastMusicPlayedIndex in playlistsLastMusicPlayedIndexDictionary do
		if key == playlist then
			return true
		end
	end

	return false
end

local function setCurrentPlayingSongInfo(songInfo: MusicInfo.MusicInfo)
	DebugHelper.PrintMessage("Setting current playing song to: "..songInfo.musicName, DebugHelper.LogLevel.Debug)
	
	currentPlayingSongInfo = songInfo
	OnMusicChangedEvent:Fire()
end

local function shufflePlaylistMusicTable(musicTable: {MusicInfo.MusicInfo})
	DebugHelper.PrintMessage("MusicTable before shuffle: "..DebugHelper.GetPrintableTable(musicTable, true), DebugHelper.LogLevel.Debug)

	local musicTableSize = #musicTable
	
	for i, music in musicTable do
		local randomSwapIndex = math.random(i, musicTableSize)
		
		local musicAtRandomIndex = musicTable[randomSwapIndex]
		local musicAtCurrentIndex = musicTable[i]
		
		musicTable[randomSwapIndex] = musicAtCurrentIndex
		musicTable[i] = musicAtRandomIndex
	end
	
	DebugHelper.PrintMessage("MusicTable after shuffle: "..DebugHelper.GetPrintableTable(musicTable, true), DebugHelper.LogLevel.Debug)
end

local function tryLoadPlaylistSongsIfNotAlready(playlist: PlaylistInfo.PlaylistInfo): boolean
	
	local isPlaylistSongsLoadedAlready = tryGetPlaylistLoadedSongTable(playlist) ~= nil
	
	if isPlaylistSongsLoadedAlready then
		return false
	end
	
	local playlistMusicTable = table.clone(playlist.musicTable)
	
	-- Shuffle playlist if enabled. 
	-- No need to check for 'PlaylistSettings.SHUFFLE_ONLY_ON_INITIAL_LOAD,' as if that is set to true, 'PlaylistSettings.SHUFFLE_SONGS' needs to already be set to true as well.
	if PlaylistSettings.SHUFFLE_SONGS then
		DebugHelper.PrintMessage("Shuffling playlist ON INITIAL LOAD: "..playlist.playlistName, DebugHelper.LogLevel.Log)
		shufflePlaylistMusicTable(playlistMusicTable)
	end
	
	playlistsLoadedSongTableDictionary[playlist] = playlistMusicTable
	return true
end

local function tryShufflePlaylistSongTable(playlist: PlaylistInfo.PlaylistInfo): boolean
	
	-- Prevents shuffling of song table if not enabled, or if meant to only do on initial load.
	if not PlaylistSettings.SHUFFLE_SONGS or PlaylistSettings.SHUFFLE_ONLY_ON_INITIAL_LOAD then
		return false
	end
	
	local playlistLoadedSongsTable = tryGetPlaylistLoadedSongTable(playlist)
	
	if playlistLoadedSongsTable == nil then
		DebugHelper.PrintMessage("Could not find playlist: '"..playlist.playlistName.."' in playlistsLoadedSongTableDictionary!", DebugHelper.LogLevel.Error)
	end
	
	DebugHelper.PrintMessage("Shuffling playlist: "..playlist.playlistName, DebugHelper.LogLevel.Log)
	shufflePlaylistMusicTable(playlistLoadedSongsTable)
	return true
end

-- [[ MODULE FUNCTIONS ]]

function module.ChangeMusicToNextSongInPlaylist()
	if currentPlaylistInfo == nil then
		-- Possible to happen if called early before a playlist is loaded
		DebugHelper.PrintMessage("Current playlist info is nil!", DebugHelper.LogLevel.Warning)
		return
	end
	
	local currentPlaylistMusicTable = tryGetPlaylistLoadedSongTable(currentPlaylistInfo)
	
	if currentPlaylistMusicTable == nil then
		DebugHelper.PrintMessage("Could not find playlist: '"..currentPlaylistInfo.playlistName.."' in playlistsLoadedSongTableDictionary!", DebugHelper.LogLevel.Error)
		return
	end

	local currentSongIndex = tryGetIndexOfSongInMusicTable(currentPlayingSongInfo, currentPlaylistMusicTable)
	
	if currentSongIndex == nil then
		-- Default to first song in playlist
		DebugHelper.PrintMessage("currentSongIndex is nil", DebugHelper.LogLevel.Error)
		setCurrentPlayingSongInfo(currentPlaylistMusicTable[1])
		return
	end

	local nextSongIndex = currentSongIndex + 1

	if nextSongIndex > #currentPlaylistMusicTable then
		nextSongIndex = 1
	end
	
	DebugHelper.PrintMessage("Switching from song index #"..currentSongIndex.." to song index #"..nextSongIndex, DebugHelper.LogLevel.Debug)
	setCurrentPlayingSongInfo(currentPlaylistMusicTable[nextSongIndex])
end

function module.ChangeMusicToPreviousSongInPlaylist()
	if currentPlaylistInfo == nil then
		-- Possible to happen if called early before a playlist is loaded
		DebugHelper.PrintMessage("Current playlist info is nil!", DebugHelper.LogLevel.Warning)
		return
	end
	
	local currentPlaylistMusicTable = tryGetPlaylistLoadedSongTable(currentPlaylistInfo)

	if currentPlaylistMusicTable == nil then
		DebugHelper.PrintMessage("Could not find playlist: '"..currentPlaylistInfo.playlistName.."' in playlistsLoadedSongTableDictionary!", DebugHelper.LogLevel.Error)
		return
	end
	
	local currentSongIndex = tryGetIndexOfSongInMusicTable(currentPlayingSongInfo, currentPlaylistMusicTable)
	
	if currentSongIndex == nil then
		-- Default to first song in playlist
		warn("currentSongIndex is nil")
		setCurrentPlayingSongInfo(currentPlaylistMusicTable[1])
		return
	end

	local previousSongIndex = currentSongIndex - 1

	if previousSongIndex < 1 then
		previousSongIndex = #currentPlaylistMusicTable
	end
	
	DebugHelper.PrintMessage("Switching from song index #"..currentSongIndex.." to song index #"..previousSongIndex, DebugHelper.LogLevel.Debug)
	setCurrentPlayingSongInfo(currentPlaylistMusicTable[previousSongIndex])
end

function module.ChangeCurrentPlaylistInfo(newPlaylistInfo: PlaylistInfo.PlaylistInfo)
	-- Example: Music list = {A, B, C}. Player gets to B, but then playlist is changed. Once playlist is changed back, it will play song C (since it is after B, which was the last played song)

	if currentPlaylistInfo ~= nil then
		savePlaylistLastMusicPlayedIndex(currentPlaylistInfo)
	end
	
	local didLoadPlaylist = tryLoadPlaylistSongsIfNotAlready(newPlaylistInfo)
	
	-- Checks if the playlist was loaded this function call. If not, shuffle the playlist. If so, don't, as it would already be shuffled on playlist load.
	if not didLoadPlaylist then
		tryShufflePlaylistSongTable(newPlaylistInfo)
	end
	
	currentPlaylistInfo = newPlaylistInfo
	
	local doesNewPlaylistHaveLastMusicPlayedIndexSave = doesPlaylistHaveLastMusicPlayedIndexSave(newPlaylistInfo)
	local lastPlayedSong: MusicInfo.MusicInfo? = getMusicBasedOnLastPlayedSongInPlaylist(newPlaylistInfo)
	
	if lastPlayedSong == nil then
		DebugHelper.PrintMessage("lastPlayedSong is nil", DebugHelper.LogLevel.Warning)
		-- Default to first song in playlist
		setCurrentPlayingSongInfo(newPlaylistInfo.musicTable[1])
		return
	end
	
	setCurrentPlayingSongInfo(lastPlayedSong)
	
	-- If the current playlist had a last music played index saved, then set the song to the next song
	-- If not, you wouldn't want to set it to the next one as it would've already defaulted to the first song, and you don't want to skip the first song in the playlist for every new player.
	if doesNewPlaylistHaveLastMusicPlayedIndexSave then
		module.ChangeMusicToNextSongInPlaylist()
	end
end

function module.GetCurrentPlaylistInfo(): PlaylistInfo.PlaylistInfo?
	return currentPlaylistInfo
end

function module.GetCurrentPlayingSongInfo(): MusicInfo.MusicInfo?
	return currentPlayingSongInfo
end

function module.SetCurrentPlayingSongMute(isMuted: boolean)
	isCurrentPlayingSongMuted = isMuted
end

function module.IsCurrentPlayingSongMuted(): boolean
	return isCurrentPlayingSongMuted
end

function module.SetCurrentPlayingSongLooping(setLooping: boolean)
	isCurrentPlayingSongLooping = setLooping
end

function module.IsCurrentPlayingSongLooping(): boolean
	return isCurrentPlayingSongLooping
end

return module