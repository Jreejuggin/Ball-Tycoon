-- Central tuning for the plot-wide worker speed upgrade.
-- Level 1 is the default speed and has no purchase cost.
local WorkerSpeedConfig = {}

WorkerSpeedConfig.Levels = {
	[1] = {WalkSpeed = 16, Cost = 0},
	[2] = {WalkSpeed = 20, Cost = 2500},
	[3] = {WalkSpeed = 24, Cost = 10000},
	[4] = {WalkSpeed = 28, Cost = 35000},
	[5] = {WalkSpeed = 32, Cost = 100000},
}

WorkerSpeedConfig.MaxLevel = #WorkerSpeedConfig.Levels

function WorkerSpeedConfig.GetLevel(level)
	return WorkerSpeedConfig.Levels[math.clamp(math.floor(tonumber(level) or 1), 1, WorkerSpeedConfig.MaxLevel)]
end

function WorkerSpeedConfig.GetNextLevel(level)
	local nextLevel = math.floor(tonumber(level) or 1) + 1
	return nextLevel, WorkerSpeedConfig.Levels[nextLevel]
end

return WorkerSpeedConfig
