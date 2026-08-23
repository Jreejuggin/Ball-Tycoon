--!strict
local module = {}

local PlaylistSettings = require(script.Parent.PlaylistSettings)

local CURRENT_LOG_LEVEL = PlaylistSettings.VERBOSE_LOGGING_LEVEL
local NEW_LINE = '\n'
local TAB = '\t'
local SEPARATOR = ';'

module.LogLevel = {
	Error = 0,
	Warning = 1,
	Important = 2,
	Log = 3,
	Debug = 4,
}

local function getTabStringBasedOnDepth(depth: number?): string
	if depth == nil then
		return ""
	end
	
	return string.rep(TAB, depth)
end

function module.PrintMessage(message: string, level: number)
	if level > CURRENT_LOG_LEVEL then
		-- Do not print this message.
		return
	end
	
	local formattedMessage = message
	
	-- Only provide the traceback if enabled in settings or if the log is an error.
	if PlaylistSettings.LOG_TRACEBACK or level == module.LogLevel.Error then
		formattedMessage = debug.traceback(message)
	end
	
	if level == module.LogLevel.Error then
		task.spawn(function() error(formattedMessage) end)
	elseif level == module.LogLevel.Warning then
		warn(formattedMessage)
	elseif level == module.LogLevel.Important or module.LogLevel.Log or module.LogLevel.Debug then
		print(formattedMessage)
	else
		-- Default to printing the message.
		print(formattedMessage)
	end
end

function module.GetPrintableTable(tableToConvert: {}, pretty: boolean?, depth: number?): string
	if depth == nil then
		depth = 0
	end
	
	local completeTableString = "{"
	
	if pretty then
		completeTableString = completeTableString..NEW_LINE
	end
	
	for key, value in pairs(tableToConvert) do
		
		local keyString = tostring(key)
		local keyValueString = ""
		
		if typeof(value) == "table" then
			local tableString = module.GetPrintableTable(value, pretty, depth :: number + 1)
			

			keyValueString = "[\""..keyString.."\"] = "..tableString..SEPARATOR
			
			-- For pretty, don't add tabs as they would be behind a '{' and infront of the '=', which is weird.
			if pretty then
				keyValueString = keyValueString..NEW_LINE
			end

		else
			local valueString = tostring(value)
			
			keyValueString = "[\""..keyString.."\"] = "..valueString..SEPARATOR
			
			if pretty then
				keyValueString = getTabStringBasedOnDepth(depth)..keyValueString..NEW_LINE
			end
		end
		
		completeTableString = completeTableString..keyValueString
	end
	
	completeTableString = completeTableString..getTabStringBasedOnDepth(depth).."}"

	return completeTableString
end

return module