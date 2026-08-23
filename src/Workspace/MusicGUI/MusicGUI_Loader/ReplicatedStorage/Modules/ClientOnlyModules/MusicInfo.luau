local module = {}

export type MusicInfo = {
	musicID: number;
	musicName: string;
	musicVolume: number;
}

function module.new(musicID: number, musicName: string, musicVolume: number): MusicInfo
	local self: MusicInfo = setmetatable({}, {__index = module})

	self.musicID = musicID
	self.musicName = musicName
	self.musicVolume = musicVolume
	
	return self
end 

return module