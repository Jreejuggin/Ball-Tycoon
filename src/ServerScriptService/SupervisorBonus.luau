--[[
	SupervisorBonus
	The one place that answers "how much faster does this floor-2 section work?"

	A section's multiplier is x1 until its supervisor is hired in the Manager
	Center. After that it is the current Productivity Training level's
	multiplier (SecondFloorConfig.ProductivityTrainingLevels). Everything is read
	from the plot's own saved values, so each player's plot is independent.

	Used by CubicleWorkstationService (income) and ManagerCenterService (signs
	and name tags). Server-only.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ServerScriptService:WaitForChild("SecondFloorConfig"))

local SupervisorBonus = {}

local stageBySection = {}
for _, stage in ipairs(Config.SupervisorStages) do
	stageBySection[stage.section] = stage
end

local function getManagerCenter(plot)
	local secondFloor = plot and plot:FindFirstChild("SecondFloor")
	local centres = secondFloor and secondFloor:FindFirstChild("CentreSlots")
	return centres and centres:FindFirstChild("Centre01_Worker")
end

function SupervisorBonus.GetStageForSection(sectionKey)
	return stageBySection[sectionKey]
end

-- Productivity Training level, clamped to the configured range.
function SupervisorBonus.GetTrainingLevel(plot)
	local centre = getManagerCenter(plot)
	local upgrades = centre and centre:FindFirstChild("Upgrades")
	local training = upgrades and upgrades:FindFirstChild("ProductivityTraining")
	local level = training and training:FindFirstChild("UpgradeLevel")
	local value = level and level.Value or 1
	return math.clamp(value, 1, #Config.ProductivityTrainingLevels)
end

function SupervisorBonus.GetTrainingMultiplier(plot)
	return Config.ProductivityTrainingLevels[SupervisorBonus.GetTrainingLevel(plot)].multiplier
end

function SupervisorBonus.IsHired(plot, stageKey)
	local centre = getManagerCenter(plot)
	local activations = centre and centre:FindFirstChild("WorkerActivations")
	local value = activations and activations:FindFirstChild(stageKey)
	return value ~= nil and value:IsA("BoolValue") and value.Value
end

-- Cash-per-minute multiplier for one section's employees.
function SupervisorBonus.GetMultiplier(plot, sectionKey)
	local stage = stageBySection[sectionKey]
	if not stage or not SupervisorBonus.IsHired(plot, stage.key) then
		return 1
	end
	return SupervisorBonus.GetTrainingMultiplier(plot)
end

return SupervisorBonus
