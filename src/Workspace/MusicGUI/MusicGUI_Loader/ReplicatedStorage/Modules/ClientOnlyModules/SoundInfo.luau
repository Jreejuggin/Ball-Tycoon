local module = {}

export type SoundInfo = {
	soundID: number,
	soundName: string
}

function module.new(soundID: number, soundName: string): SoundInfo
	local self: SoundInfo = setmetatable({}, {__index = module})
	
	self.soundID = soundID
	self.soundName = soundName
	
	return self
end 

return module
