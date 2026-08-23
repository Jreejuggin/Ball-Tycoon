--[[ 
	This is an example script of how to change the current playlist being played.
		- Changing the current playlist has tons of possibilities. Have multiple worlds in your game? Once a player enters a certain world, change their playlist to match the mood of that world! Do anything you can think of!

	PUT ME IN StarterPlayer.StarterPlayerScripts and set to "Enabled" TO TEST.
--]]
local Playlists = require(game:GetService("ReplicatedStorage").Modules.ClientOnlyModules.Playlists)
local LocalMusicHandler = require(game:GetService("ReplicatedStorage").Modules.ClientOnlyModules.LocalMusicHandler)

task.wait(10)

print("Changing current playlist.")
LocalMusicHandler.ChangeCurrentPlaylistInfo(Playlists.PlaylistsDictionary.MyMusicPlaylist)