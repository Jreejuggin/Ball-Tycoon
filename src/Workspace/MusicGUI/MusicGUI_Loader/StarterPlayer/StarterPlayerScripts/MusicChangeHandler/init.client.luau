--!strict
-----------------
--| Services |--
-----------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-----------------
--| Modules |--
-----------------

local ModulesFolder = ReplicatedStorage.Modules
local ClientOnlyModulesFolder = ModulesFolder.ClientOnlyModules

local DebugHelper = require(ClientOnlyModulesFolder.DebugHelper)
local LocalMusicHandler = require(ClientOnlyModulesFolder.LocalMusicHandler)
local Playlists = require(ClientOnlyModulesFolder.Playlists)
local PlaylistSettings = require(ClientOnlyModulesFolder.PlaylistSettings)
local PlaylistInfo = require(ClientOnlyModulesFolder.PlaylistInfo)

-----------------
--| Variables |--
-----------------

local LocalPlayer = Players.LocalPlayer
local EventsFolder = ReplicatedStorage.Events
local ClientOnlyEventsFolder = EventsFolder.ClientOnlyEvents

local OnMusicChangedEvent = ClientOnlyEventsFolder.OnMusicChanged
local OnMusicMuteChangedEvent = ClientOnlyEventsFolder.OnMusicMuteChanged
local CurrentMusicSound = script.Music

local currentMusicSoundEndedConnection: RBXScriptConnection? = nil
local changeMusicCalls = 0
local musicFadeOutTween = nil

local CONSTS = {
	MusicFadeOutTweenGoal = {Volume = 0}
}
table.freeze(CONSTS)

-----------------
--| Functions |--
-----------------

local function fadeOutMusic()
	if musicFadeOutTween == nil and changeMusicCalls == 1 then
		local fadeOutTweenInfo = TweenInfo.new(PlaylistSettings.MUSIC_FADE_OUT_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)

		musicFadeOutTween = TweenService:Create(CurrentMusicSound, fadeOutTweenInfo, CONSTS.MusicFadeOutTweenGoal)
		musicFadeOutTween:Play()
		musicFadeOutTween.Completed:Wait() -- Wait for the tween to fully complete. Don't due task.wait(CONSTS.MusicFadeoutTime) as it can lead to issues if the Tween is slight behind schedule...
		musicFadeOutTween = nil
		CurrentMusicSound:Stop()
	else
		task.wait(PlaylistSettings.MUSIC_FADE_OUT_TIME)
	end
end

local function onCurrentMusicSoundEnded()
	DebugHelper.PrintMessage("Current music sound ended!", DebugHelper.LogLevel.Debug)
	
	if LocalMusicHandler.IsCurrentPlayingSongLooping() then
		DebugHelper.PrintMessage("Looping is active, replaying same song.", DebugHelper.LogLevel.Debug)
		-- Loop the current song
		CurrentMusicSound.TimePosition = 0
		CurrentMusicSound:Play()
		return
	end
	
	-- Make sure to disconnect the current connection, as this prevents a weird bug that when the next song is played
	-- (and if it has been played ONCE before), it will be counted as "ended" by the current connection and will be skipped. Don't know why, but this stops that issue.
	if currentMusicSoundEndedConnection ~= nil then
		currentMusicSoundEndedConnection:Disconnect()
		currentMusicSoundEndedConnection = nil
	end
	
	-- If the current sound ended, go to the next song in the playlist.
	LocalMusicHandler.ChangeMusicToNextSongInPlaylist()
end

local function setCurrentMusicSoundToCurrentSongPlaying()
	local currentPlayingSongInfo = LocalMusicHandler.GetCurrentPlayingSongInfo()
	
	if currentPlayingSongInfo == nil then
		return
	end
	
	task.spawn(function()
		changeMusicCalls += 1
		
		if not LocalMusicHandler.IsCurrentPlayingSongMuted() then
			-- There is music currently playing, so fade it out.
			fadeOutMusic()
		end
		
		changeMusicCalls -= 1
		
		if changeMusicCalls > 0 then
			-- There was a new call to change the song! Ignore this old song change.
			return
		end
	
		CurrentMusicSound.SoundId = "rbxassetid://"..tostring(currentPlayingSongInfo.musicID)

		if currentMusicSoundEndedConnection ~= nil then
			currentMusicSoundEndedConnection:Disconnect()
			currentMusicSoundEndedConnection = nil
		end

		if not CurrentMusicSound.IsLoaded then
			CurrentMusicSound.Loaded:Wait()
		end
		
		CurrentMusicSound:Play()
		
		if not LocalMusicHandler.IsCurrentPlayingSongMuted() then
			CurrentMusicSound.Volume = currentPlayingSongInfo.musicVolume * PlaylistSettings.GLOBAL_MAX_MUSIC_VOLUME_PERCENTAGE
		end
		
		currentMusicSoundEndedConnection = CurrentMusicSound.Ended:Connect(onCurrentMusicSoundEnded)
	end)
end

local function updateCurrentMusicMute()
	if LocalMusicHandler.IsCurrentPlayingSongMuted() then
		CurrentMusicSound.Volume = 0
	else
		local currentPlayingSongInfo = LocalMusicHandler.GetCurrentPlayingSongInfo()

		if currentPlayingSongInfo == nil then
			return
		end

		CurrentMusicSound.Volume = currentPlayingSongInfo.musicVolume
	end
end

local function initialMusicPlay()
	
	local defaultMusicPlaylist: PlaylistInfo.PlaylistInfo = Playlists.PlaylistsDictionary[PlaylistSettings.DEFAULT_MUSIC_PLAYLIST]
	
	if defaultMusicPlaylist == nil then
		DebugHelper.PrintMessage("Playlist: " .. PlaylistSettings.DEFAULT_MUSIC_PLAYLIST .. " does not exist! Make sure you typed the name correctly!", DebugHelper.LogLevel.Warning)
		-- Fallback to the default music playlist.
		defaultMusicPlaylist = Playlists.PlaylistsDictionary["DefaultMusicPlaylist"]
	end
	
	DebugHelper.PrintMessage("Playing inital music playlist: "..defaultMusicPlaylist.playlistName, DebugHelper.LogLevel.Important)

	-- Play the default music playlist
	LocalMusicHandler.ChangeCurrentPlaylistInfo(defaultMusicPlaylist)
end

local function onMusicChangedEvent()

	setCurrentMusicSoundToCurrentSongPlaying()
end

local function onMusicMuteChangedEvent()
	updateCurrentMusicMute()
end

OnMusicChangedEvent.Event:Connect(onMusicChangedEvent)
OnMusicMuteChangedEvent.Event:Connect(onMusicMuteChangedEvent)
initialMusicPlay()