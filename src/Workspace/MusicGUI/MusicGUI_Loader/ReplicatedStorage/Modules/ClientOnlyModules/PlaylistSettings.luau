return {
	
--[[
~~~~~ REGULAR SETTINGS ~~~~~
--]]
	
	--[[
		The name of the default playlist that will be played automatically.
		* The default playlist must exist in the 'Playlists' module!!!
		* THIS IS CASE SENSITIVE, TYPE IT CORRECTLY!!!
	--]]
	DEFAULT_MUSIC_PLAYLIST = "DefaultMusicPlaylist"; -- "DefaultMusicPlaylist" always exists.
	
	--[[
		Whether or not songs should shuffle when a playlist is loaded.
	--]]
	SHUFFLE_SONGS = false;
	
	--[[
		Whether or not the shulffing should occur only when the playlist is loaded for the first time. This is for 2 options:
		1. Set to true if you want playlists to be randomized initially, but anytime the playlist is changed to again, it will not be shuffled again. This keeps the songs random, but linear and predictable.
		2. Leave as false if you want the playlist to be shuffled every time the playlist is changed.
		
		* Requires 'SHUFFLE_SONGS' to be set to true! *
	--]]
	SHUFFLE_ONLY_ON_INITIAL_LOAD = false;
	
	--[[
		The time (in seconds) it takes for the current song playing to fadeout when the song is changed.
	--]]
	MUSIC_FADE_OUT_TIME = 1.5;
	
	--[[
		Allows you to quickly make all music quieter or louder (without having to modify every single song's individual volume in 'Songs' module)
		* Make all music quieter: Change this number to a lower number. (example: 50% volume = 0.50)
		* Make all music louder: Change this number to a higher number. (example: 150% volume = 1.50)
	--]] 
	GLOBAL_MAX_MUSIC_VOLUME_PERCENTAGE = 1.00; 
	
	
--[[
~~~~~ DEBUGGING SETTINGS ~~~~~
--]]
	
	--[[
		Set the level of logging that will be logged to the studio ouput.
		0 = Only errors
		1 = Only warnings
		2 = Warnings + important information -- RECOMMENDED
		3 = All information will be logged.
		4 = All information (including big debug info) will be logged. Only recommended for debugging!
	--]]
	VERBOSE_LOGGING_LEVEL = 2;
	
	--[[
		Whether or not the logs should include the traceback.
		SET TO TRUE WHEN SUBMITTING A BUG REPORT/DEBUGGING.
	--]]
	LOG_TRACEBACK = false;
}
