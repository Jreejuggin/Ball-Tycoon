-- MachineUpgradeFeedbackService
-- Handles upgrade feedback from a trusted server script. The sound is played
-- for the buyer, and the buyer's client renders the exact shared purchase
-- sparkle effect locally so particles are never lost to replication timing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local sparkleEvent = ReplicatedStorage:FindFirstChild("MachineUpgradeSparkleEvent")
if not sparkleEvent then
	sparkleEvent = Instance.new("RemoteEvent")
	sparkleEvent.Name = "MachineUpgradeSparkleEvent"
	sparkleEvent.Parent = ReplicatedStorage
end

local PLOT_NAME_PATTERN = "^P%d+$"
local watchedSlots = {}
local lastRequests = {}

local function findPlot(instance)
	local current = instance
	while current and current.Parent ~= workspace do
		current = current.Parent
	end

	if current and current.Name:match(PLOT_NAME_PATTERN) then
		return current
	end

	return nil
end

local function getOwnerPlayer(plot)
	local ownerId = plot and plot:GetAttribute("Owner")
	if not ownerId then
		return nil
	end

	return Players:GetPlayerByUserId(ownerId)
end

local function getMachine(slot)
	return slot and (slot:FindFirstChild("Dropper") or slot:FindFirstChild("Conveyor")) or nil
end

local function getSoundTarget(slot)
	return getMachine(slot) or slot:FindFirstChild("UpgradeBuyPad") or slot
end

local function countPurchaseSparkleParts(slot)
	local count = 0
	local machine = getMachine(slot)
	if not machine then
		return count
	end

	for _, descendant in ipairs(machine:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if machine.Name == "Dropper" then
				if descendant.Name ~= "Collector" then
					count += 1
				end
			elseif machine.Name == "Conveyor" then
				if descendant.Name ~= "Spawner" and descendant.Name ~= "EndZone" then
					count += 1
				end
			else
				count += 1
			end
		end
	end

	return count
end

local function getUpgradeLevel(slot)
	local levelValue = slot and slot:FindFirstChild("UpgradeLevel")
	if levelValue and levelValue:IsA("IntValue") then
		return levelValue.Value
	end

	return nil
end

local function handleFeedbackRequest(slot)
	local request = tonumber(slot:GetAttribute("UpgradeFeedbackRequest")) or 0
	local previousRequest = lastRequests[slot] or 0
	if request <= previousRequest then
		return
	end
	lastRequests[slot] = request

	local buyerId = slot:GetAttribute("LastUpgradeBuyerUserId")
	if not buyerId then
		return
	end

	local plot = findPlot(slot)
	local ownerPlayer = getOwnerPlayer(plot)
	if not ownerPlayer or ownerPlayer.UserId ~= buyerId then
		return
	end

	sparkleEvent:FireClient(ownerPlayer, slot)
	local upgradeSoundTarget = getSoundTarget(slot)
	PurchaseSoundModule.PlayPurchaseForTarget(ownerPlayer, upgradeSoundTarget)
	task.delay(0.08, function()
		PurchaseSoundModule.PlayMachineUpgrade(ownerPlayer, upgradeSoundTarget)
	end)

	local level = getUpgradeLevel(slot)
	slot:SetAttribute("LastUpgradeSparklePartCount", countPurchaseSparkleParts(slot))
	slot:SetAttribute("LastUpgradeSparkleUsedExactPurchaseModule", true)
	slot:SetAttribute("LastUpgradeSparkleModuleCall", "Client PurchaseEffectModule.PlayAcrossParts")
	slot:SetAttribute("LastUpgradeSparkleAt", os.clock())
	slot:SetAttribute("LastUpgradeFeedbackLevel", level)
	slot:SetAttribute("LastUpgradeFeedbackAt", os.clock())
	slot:SetAttribute("LastUpgradeFeedbackPlayerId", ownerPlayer.UserId)
	slot:SetAttribute("LastUpgradeBuyerUserId", nil)
end

local function watchSlot(slot)
	if watchedSlots[slot] then
		return
	end

	local levelValue = slot:FindFirstChild("UpgradeLevel")
	local upgradePad = slot:FindFirstChild("UpgradeBuyPad")
	if not (levelValue and levelValue:IsA("IntValue") and upgradePad) then
		return
	end

	watchedSlots[slot] = true
	lastRequests[slot] = tonumber(slot:GetAttribute("UpgradeFeedbackRequest")) or 0
	slot:GetAttributeChangedSignal("UpgradeFeedbackRequest"):Connect(function()
		handleFeedbackRequest(slot)
	end)
end

local function scan(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("IntValue") and descendant.Name == "UpgradeLevel" and descendant.Parent then
			watchSlot(descendant.Parent)
		end
	end
end

scan(workspace)
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("IntValue") and descendant.Name == "UpgradeLevel" and descendant.Parent then
		task.defer(watchSlot, descendant.Parent)
	elseif descendant.Name == "UpgradeBuyPad" and descendant.Parent then
		task.defer(watchSlot, descendant.Parent)
	end
end)
