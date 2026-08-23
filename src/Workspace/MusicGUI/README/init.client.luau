--[[

	*---------------------*
	CURRENT VERSION: v1.2.4
	*---------------------*
	
	This asset was made by L_Moments
	
	*---------------------*
	   GET STARTED GUIDE:
	*---------------------*
		
		
***** ADD/CHANGE YOUR OWN SONGS:
	
	To add your own songs, go to 
		MusicGUI -> MusicGUI_Loader -> ReplicatedStorage -> Modules -> ClientOnlyModules -> Songs

	Under 'SongsDictionary' either:
		- Modify an existing MusicInfo.new() entry 
			OR
		- Add a new MusicInfo.new() entry at the bottom of the table.
		
		
***** MODIFY OTHER SETTINGS:

	To modify other settings, go to
	
		MusicGUI -> MusicGUI_Loader -> ReplicatedStorage -> Modules -> ClientOnlyModules -> PlaylistSettings

	You can modify the following settings:
		- Default music playlist
		- Shuffling
		- Music fade out time
		- Global music volume
		- ... and more!
		
	What each setting does will be documented in the module.
	
	REMEMBER: If you want to add your own songs, this will be located in the 'Songs' module, and not the 'PlaylistSettings' module.


***** OTHER
	
	Don't want the whole GUI?
		--* Delete it! However, the songs will just play automatically.
	
	Don't want the settings GUI?
		* Delete the following:
			- MusicPlaylistGUI.SettingsGUIScript
			- MusicPlaylistGUI.MainContainer.SettingsBackground
			- MusicPlaylistGUI.MainContainer.MainBackground.SettingsMenuButtonBackground
	
	Modify the GUI?
		* Do as your heart desires! Just make sure to not delete the 'MusicPlaylistGUIScript'
			- Instead, make sure to set the ObjectValues under the script to your own TextButtons and TextLabels.
	
	Don't want the MusicGUI_Loader?
		* Move every single folder to their respective Roblox service.
			- ReplicatedStorage folder -> ReplicatedStorage
			- StarterGUI folder -> StarterGui
			- StarterPlayerScripts folder -> StarterPlayer.StarterPlayerScripts
		* Then, ungroup these root folders (Ctrl + U or right click then click ungroup)
		* Now, you can safely delete the MusicGUI_Loader and have everything still work (if you put everything in their right spot!)

]]

--[[
	CHANGELOG:  v[RELEASE].[PATCH].[MINOR]
	
	v1.2.4v2 - ICON UPDATE: 03/07/2025
		- The previous mute icon was archived by the uploader, so it has been updated with a new one.
		- This is such a minimal update that it will be referred to as a v2 of 1.2.4 and not be advertised on the asset page.
	
	v1.2.4 - LOOP UPDATE: 12/24/2025
		- New loop button inside the settings menu
		- Mute button icon has been updated
		- Fixed a weird bug that would skip songs that were played before if you hit the "previous" button to get past them.
		- Small debugging changes
		- Merry Christmas!
		
	v1.2.3 - UI UPDATE: 11/22/2025
		- Added a settings menu
		- New mute button inside the settings menu
		- GUI positioning now ignores CoreUI (but still is insets from device safe zone), so it should be properly in the top right corner now. 
	
	v1.2.2 - SHUFFLE UPDATE: 11/20/2025
		- Added 2 new settings to PlaylistSettings (thanks to MxSp for suggesting this):
			- 'SHUFFLE_SONGS' (default: false)
			- 'SHUFFLE_ONLY_ON_INITIAL_LOAD' (default: false)
		- What they do is written in comments under the PlaylistSettings module.
		- Other changes:
			- Fixed an issue with changing playlists incorrectly changing songs.
			- New 'ExampleUI' folder under this script. Has a new GUI to show how easy changing playlists could be, and is a great showcase for the shuffle feature.
			- New debug stuff, not super important, but cool!
	
	v1.2.1_2 - VERY MINOR CHANGE: 07/06/2025
		- "ExampleScript_ChangingPlaylist" is set to disabled by default (this is what it should've been originally, oops!)
	
	v1.2.1 - PLAYLIST UPDATE: 06/26/2025
		- Made changing the current playing playlist easier and VERY simple. To see how simple it is, go to the 'ExampleScripts' folder under this README and look at 'ExampleScript_ChangingPlaylist'
		- Added more documentation about getting rid of the MusicGUI_Loader.
		- Added a new ExampleScripts folder under this README to put example scripts of anything that I would want to showcase in the future.
		- I am currently planning on making a tutorial video going over every feature of this GUI. Look out for that coming soon!
		
	v1.2.0 - CUSTOMIZABILITY UPDATE : 05/30/2025
		- Added a new 'Songs' module to decouple the 'Playlists' module from handling both playlists and the songs.
			- Now, you put all songs you want to use in the 'Songs' module.
			- This allows you to make custom playlists and reuse multiple songs from the Songs.SongsDictionary (CURRENTLY SWITCHING PLAYLISTS NEEDS TO BE WORKED OUT IN THE NEXT UPDATE)
		- Added way more settings to PlaylistSettings. What they do is documented in that module.
		- Made the MusicPlaylistGUI more customizable by allowing the contents to be changed without the script breaking (this is done by using ObjectValues instead of hardcoding the labels/buttons paths in the script)
		- Added new DebugHelper to go along with the new VERBOSE_LOGGING_LEVEL (I know this seems very unecessary for an asset like this, but let me overengineer in peace, okay?)
		- Updated "Get Started Guide" of this README to have more in depth information.
	
	v1.1.0 - COMPATIBILITY UPDATE : 05/20/2025
		- I noticed that the asset had some dislikes, which most likely means it didn't work for some people. I was able to find out that the issue was that if you had any folder in ReplicatedStorage named 'Events' (a pretty common folder to have!), 
		the MusicGUI_Loader would still create another directory with the same name, resulting in 2 folders with the same name! This obviously will create errors for this, and for any of your code. Therefore, I updated the loader
		to now put the files if there is any folder with the same name in ReplicatedStorage.
		- I also added a 'Get Started Guide' and some more documentation to help you guys out.
		- I also added 3 OG songs from the original MusicGUI that I resurfaced to the default playlist.
		- If you have any future issues, please contact me!
	
	v1.0.0 - RELEASE : 01/27/2025
]]