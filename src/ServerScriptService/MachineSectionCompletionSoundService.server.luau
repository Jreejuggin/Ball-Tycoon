-- MachineSectionCompletionSoundService
-- Plays the New_Area2 / area-unlock sound when a plot owner completes every
-- machine slot inside a machine section folder, such as DropperSlots,
-- DropperSlots2, ConveyorSlots, or ConveyorBeltBig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local PLOT_NAME_PATTERN = "^P%d+$"
local watchedSections = {}
local sectionWasComplete = {}
local sectionConnections = {}
local lastPlayedAt = {}

local function isPlot(instance)
	return instance and instance.Parent == workspace and instance.Name:match(PLOT_NAME_PATTERN) ~= nil
end

local function getOwnerPlayer(plot)
	local ownerId = plot and plot:GetAttribute("Owner")
	if not ownerId then
		return nil
	end

	return Players:GetPlayerByUserId(ownerId)
end

local function getActivatedValue(slot)
	local activated = slot and slot:FindFirstChild("Activated")
	if activated and activated:IsA("BoolValue") then
		return activated
	end

	return nil
end

local function getMachineSlots(section)
	local slots = {}
	for _, child in ipairs(section:GetChildren()) do
		if child:IsA("Model") and getActivatedValue(child) then
			table.insert(slots, child)
		end
	end

	table.sort(slots, function(a, b)
		return a.Name < b.Name
	end)

	return slots
end

local function isMachineSection(section)
	return #getMachineSlots(section) > 0
end

local function isSectionComplete(section)
	local slots = getMachineSlots(section)
	if #slots == 0 then
		return false
	end

	for _, slot in ipairs(slots) do
		local activated = getActivatedValue(slot)
		if not (activated and activated.Value) then
			return false
		end
	end

	return true
end

local function getSoundTarget(section)
	for _, slot in ipairs(getMachineSlots(section)) do
		local machine = slot:FindFirstChild("Dropper") or slot:FindFirstChild("Conveyor")
		if machine then
			return machine
		end

		local buyPad = slot:FindFirstChild("BuyPad")
		if buyPad then
			return buyPad
		end
	end

	return section
end

local function disconnectSection(section)
	local connections = sectionConnections[section]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	sectionConnections[section] = nil
	watchedSections[section] = nil
	sectionWasComplete[section] = nil
	lastPlayedAt[section] = nil
end

local function evaluateSection(section, allowSound)
	if not section:IsDescendantOf(workspace) then
		disconnectSection(section)
		return
	end

	local complete = isSectionComplete(section)
	local wasComplete = sectionWasComplete[section]
	sectionWasComplete[section] = complete
	section:SetAttribute("MachineSectionComplete", complete)

	if not allowSound then
		return
	end
	if not complete or wasComplete then
		return
	end

	local plot = section.Parent
	if not isPlot(plot) then
		return
	end

	local ownerPlayer = getOwnerPlayer(plot)
	if not ownerPlayer then
		return
	end

	local now = os.clock()
	if lastPlayedAt[section] and now - lastPlayedAt[section] < 1.0 then
		return
	end
	lastPlayedAt[section] = now

	PurchaseSoundModule.PlayAreaUnlocked(ownerPlayer, getSoundTarget(section))
	section:SetAttribute("LastMachineSectionCompleteSoundAt", now)
	section:SetAttribute("LastMachineSectionCompletePlayerId", ownerPlayer.UserId)
end

local function connectActivated(section, activated)
	local connections = sectionConnections[section]
	if not connections then
		connections = {}
		sectionConnections[section] = connections
	end

	table.insert(connections, activated.Changed:Connect(function()
		evaluateSection(section, true)
	end))
end

local function watchSection(section)
	if watchedSections[section] or not isMachineSection(section) then
		return
	end

	watchedSections[section] = true
	sectionConnections[section] = {}

	for _, slot in ipairs(getMachineSlots(section)) do
		connectActivated(section, getActivatedValue(slot))
	end

	table.insert(sectionConnections[section], section.ChildAdded:Connect(function(child)
		task.defer(function()
			if child.Parent ~= section then
				return
			end
			local activated = getActivatedValue(child)
			if activated then
				connectActivated(section, activated)
				evaluateSection(section, false)
			end
		end)
	end))

	table.insert(sectionConnections[section], section.AncestryChanged:Connect(function(_, parent)
		if not parent then
			disconnectSection(section)
		end
	end))

	evaluateSection(section, false)
end

local function scanPlot(plot)
	for _, child in ipairs(plot:GetChildren()) do
		if child:IsA("Folder") or child:IsA("Model") then
			watchSection(child)
		end
	end
end

for _, child in ipairs(workspace:GetChildren()) do
	if isPlot(child) then
		scanPlot(child)
		child.ChildAdded:Connect(function(newChild)
			task.defer(function()
				if newChild.Parent == child and (newChild:IsA("Folder") or newChild:IsA("Model")) then
					watchSection(newChild)
				end
			end)
		end)
	end
end

workspace.ChildAdded:Connect(function(child)
	task.defer(function()
		if isPlot(child) then
			scanPlot(child)
			child.ChildAdded:Connect(function(newChild)
				task.defer(function()
					if newChild.Parent == child and (newChild:IsA("Folder") or newChild:IsA("Model")) then
						watchSection(newChild)
					end
				end)
			end)
		end
	end)
end)
