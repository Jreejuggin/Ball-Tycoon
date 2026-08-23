local module = {}

export type PlaylistInfo = {
	playlistName: string,
	musicTable: {MusicInfo.MusicInfo}
}

function module.new(playlistName: string, musicTable: {MusicInfo.MusicInfo}): PlaylistInfo
	local self: PlaylistInfo = setmetatable({}, {__index = module})

	self.playlistName = playlistName
	self.musicTable = musicTable

	return self
end 

return module