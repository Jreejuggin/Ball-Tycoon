-- One shared catalog for worker speech and microphone previews.
-- Add approved worker audio here; the menu updates automatically.
local entries = {
	{ id = "worker_voice_01", name = "Worker voiceline 1", soundId = "rbxassetid://111426373017081" },
	{ id = "worker_voice_02", name = "Worker voiceline 2", soundId = "rbxassetid://73964096479702" },
	{ id = "worker_voice_03", name = "Worker voiceline 3", soundId = "rbxassetid://78005173847052" },
}

for _, entry in ipairs(entries) do
	table.freeze(entry)
end
return table.freeze(entries)
