local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TycoonProgressService = require(game.ServerScriptService.TycoonProgressService)

local DOOR_OFFSET = 5 -- studs into the plot from the inner edge
local SPAWN_HEIGHT_OFFSET = 2
local TELEPORT_COOLDOWN = 1
local DATA_LOAD_TIMEOUT_SECONDS = 10
local RESTORING_PROGRESS_ATTR = "RestoringProgress"
local RESTORE_EFFECT_SUPPRESSION_SECONDS = 1

local teleportEvent = ReplicatedStorage:FindFirstChild("TeleportToTycoonEvent")
if not teleportEvent then
	teleportEvent = Instance.new("RemoteEvent")
	teleportEvent.Name = "TeleportToTycoonEvent"
	teleportEvent.Parent = ReplicatedStorage
end

local lastTeleportAt = {}

local function getAvailablePlot()
	-- Studio-only test hook. In Edit mode, set the Workspace attribute
	-- StudioForcedPlotName to "P2", "P3", etc. Published servers ignore it.
	if RunService:IsStudio() then
		local forcedPlotName = workspace:GetAttribute("StudioForcedPlotName")
		if type(forcedPlotName) == "string" and string.match(forcedPlotName, "^P%d+$") then
			local forcedPlot = workspace:FindFirstChild(forcedPlotName)
			if forcedPlot and forcedPlot:GetAttribute("Owner") == nil then
				return forcedPlot
			end
			warn("StudioForcedPlotName points to a missing or occupied plot: " .. forcedPlotName)
		end
	end

	for index = 1, 10 do
		local plot = workspace:FindFirstChild("P" .. index)
		if plot and plot:GetAttribute("Owner") == nil then
			return plot
		end
	end
	return nil
end

local function teleportToPlot(character, plot)
	local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then
		return false
	end

	local floor = plot.PrimaryPart or plot:FindFirstChild("Floor")
	if not floor then
		warn("No floor found for plot: " .. plot.Name)
		return false
	end

	local innerEdge = floor.Position + (floor.CFrame.LookVector * (floor.Size.Z / 2))
	local doorPosition = innerEdge - (floor.CFrame.LookVector * DOOR_OFFSET)
	local spawnPosition = doorPosition + Vector3.new(0, floor.Size.Y + SPAWN_HEIGHT_OFFSET, 0)
	local lookAtPosition = spawnPosition + floor.CFrame.LookVector

	hrp.CFrame = CFrame.new(spawnPosition, lookAtPosition)
	return true
end

local function getOwnedPlot(player)
	local assignedPlotName = player:GetAttribute("AssignedPlotName")
	if type(assignedPlotName) == "string" then
		local assignedPlot = workspace:FindFirstChild(assignedPlotName)
		if assignedPlot and assignedPlot:GetAttribute("Owner") == player.UserId then
			return assignedPlot
		end
	end

	for index = 1, 10 do
		local plot = workspace:FindFirstChild("P" .. index)
		if plot and plot:GetAttribute("Owner") == player.UserId then
			return plot
		end
	end
	return nil
end

local function waitForData(player)
	local waited = 0
	while player.Parent and not player:GetAttribute("DataLoaded") and waited < DATA_LOAD_TIMEOUT_SECONDS do
		task.wait(0.1)
		waited += 0.1
	end
	return player.Parent ~= nil and player:GetAttribute("DataLoaded") == true
end

teleportEvent.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastTeleportAt[player] and now - lastTeleportAt[player] < TELEPORT_COOLDOWN then
		return
	end
	lastTeleportAt[player] = now

	local plot = getOwnedPlot(player)
	local character = player.Character
	if plot and character then
		teleportToPlot(character, plot)
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		if not waitForData(player) then
			warn(player.Name .. " could not be assigned a plot because their data did not finish loading.")
			return
		end

		local plot = getAvailablePlot()
		if not plot then
			warn(player.Name .. " joined but no plots are available!")
			return
		end

		-- Clear progress left by a previous owner, then apply this player's
		-- server-loaded save before exposing the plot for interaction.
		-- Worker controllers use this short restore phase to distinguish saved
		-- hires from brand-new purchases and avoid replaying purchase effects.
		plot:SetAttribute(RESTORING_PROGRESS_ATTR, true)
		TycoonProgressService.ResetPlot(plot)
		local loadedProgress = TycoonProgressService.GetLoadedProgress(player)
		local restoredProgressValueCount = 0
		for _ in pairs(type(loadedProgress.Values) == "table" and loadedProgress.Values or {}) do
			restoredProgressValueCount += 1
		end
		TycoonProgressService.ApplyPlot(plot, loadedProgress)
		player:SetAttribute("RestoredProgressValueCount", restoredProgressValueCount)
		plot:SetAttribute("UpgradeLevel", player:GetAttribute("SavedUpgradeLevel") or 1)

		player:SetAttribute("AssignedPlotName", plot.Name)
		plot:SetAttribute("Owner", player.UserId)
		plot:SetAttribute("OwnerName", player.Name)

		task.delay(RESTORE_EFFECT_SUPPRESSION_SECONDS, function()
			if plot.Parent and plot:GetAttribute("Owner") == player.UserId then
				plot:SetAttribute(RESTORING_PROGRESS_ATTR, nil)
			end
		end)

		player.CharacterAdded:Connect(function(character)
			teleportToPlot(character, plot)
		end)

		if player.Character then
			teleportToPlot(player.Character, plot)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastTeleportAt[player] = nil

	-- AssignedPlotName intentionally remains on the departing Player until it is
	-- destroyed. DataSaveScript uses it to capture progress even if this handler
	-- happens to clear plot ownership first.
	for index = 1, 10 do
		local plot = workspace:FindFirstChild("P" .. index)
		if plot and plot:GetAttribute("Owner") == player.UserId then
			-- Capture before Owner changes. CentreZoneService intentionally resets
			-- centre BoolValues on that signal, so capturing afterward can lose them.
			TycoonProgressService.SetDepartureProgress(player, TycoonProgressService.CapturePlot(plot))
			plot:SetAttribute(RESTORING_PROGRESS_ATTR, nil)
			plot:SetAttribute("Owner", nil)
			plot:SetAttribute("OwnerName", nil)
		end
	end
end)