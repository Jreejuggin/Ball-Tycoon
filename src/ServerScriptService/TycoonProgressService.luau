-- TycoonProgressService
-- Centralizes plot-state serialization so new machines automatically save when
-- they follow the existing Activated / UpgradeLevel conventions.
local TycoonProgressService = {}

local loadedProgressByUserId = {}
local departureProgressByUserId = {}

local function isWorkerActivation(value)
	return value:IsA("BoolValue")
		and value.Parent ~= nil
		and value.Parent.Name == "WorkerActivations"
end

local function isTrackedValue(value)
	return (value:IsA("BoolValue") and value.Name == "Activated")
		or isWorkerActivation(value)
		or (value:IsA("IntValue") and value.Name == "UpgradeLevel")
end

local function getRelativePath(plot, instance)
	local segments = {}
	local current = instance
	while current and current ~= plot do
		table.insert(segments, 1, current.Name)
		current = current.Parent
	end
	return table.concat(segments, "/")
end

local function findByRelativePath(plot, path)
	-- StructureSlots moved under Centre02_Home. Redirect pre-refactor v2
	-- save paths so in-development progress still restores into the new layout.
	if string.sub(path, 1, 15) == "StructureSlots/" then
		path = "CentreSlots/Centre02_Home/" .. path
	end

	local current = plot
	for segment in string.gmatch(path, "[^/]+") do
		current = current and current:FindFirstChild(segment)
		if not current then
			return nil
		end
	end
	return current
end

function TycoonProgressService.SetLoadedProgress(player, progress)
	loadedProgressByUserId[player.UserId] = type(progress) == "table" and progress or {}
end

function TycoonProgressService.GetLoadedProgress(player)
	return loadedProgressByUserId[player.UserId] or {}
end

function TycoonProgressService.SetDepartureProgress(player, progress)
	departureProgressByUserId[player.UserId] = progress
end

function TycoonProgressService.GetDepartureProgress(player)
	return departureProgressByUserId[player.UserId]
end

function TycoonProgressService.ForgetPlayer(player)
	loadedProgressByUserId[player.UserId] = nil
	departureProgressByUserId[player.UserId] = nil
end

function TycoonProgressService.CapturePlot(plot)
	local values = {}
	if not plot then
		return values
	end

	for _, descendant in ipairs(plot:GetDescendants()) do
		if isTrackedValue(descendant) then
			local shouldSave = false
			if descendant:IsA("BoolValue") then
				shouldSave = descendant.Value
			elseif descendant:IsA("IntValue") then
				shouldSave = descendant.Value > 1
			end

			-- Store only non-default values. This keeps saves compact while the
			-- restore pass explicitly resets every tracked value first.
			if shouldSave then
				values[getRelativePath(plot, descendant)] = descendant.Value
			end
		end
	end

	return {
		SchemaVersion = 2,
		Values = values,
	}
end

function TycoonProgressService.ResetPlot(plot)
	if not plot then
		return
	end

	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("BoolValue") and (descendant.Name == "Activated" or isWorkerActivation(descendant)) then
			descendant.Value = false
		elseif descendant:IsA("IntValue") and descendant.Name == "UpgradeLevel" then
			descendant.Value = 1
		end
	end

	-- Workers are runtime clones. Remove any left by a prior owner before this
	-- plot is assigned again; the worker controller recreates saved workers.
	for _, child in ipairs(plot:GetChildren()) do
		if child:GetAttribute("ActivationName") ~= nil then
			child:Destroy()
		end
	end
end

function TycoonProgressService.ApplyPlot(plot, progress)
	if not plot or type(progress) ~= "table" then
		return
	end

	local values = progress.Values
	if type(values) ~= "table" then
		return
	end

	for path, savedValue in pairs(values) do
		if type(path) == "string" then
			local target = findByRelativePath(plot, path)

			-- Worker stages are created by their controller at runtime. Recreate a
			-- missing saved BoolValue only inside the known activation folder.
			if not target and savedValue == true then
				local parentPath, valueName = string.match(path, "^(.*)/([^/]+)$")
				local parent = parentPath and findByRelativePath(plot, parentPath)
				if parent and parent.Name == "WorkerActivations" then
					target = Instance.new("BoolValue")
					target.Name = valueName
					target.Parent = parent
				end
			end

			if target and isTrackedValue(target) then
				if target:IsA("BoolValue") and type(savedValue) == "boolean" then
					target.Value = savedValue
				elseif target:IsA("IntValue") and type(savedValue) == "number" then
					target.Value = math.max(1, math.floor(savedValue))
				end
			end
		end
	end
end

return TycoonProgressService