-- MachineUpgradeSparkleClient
-- Renders upgrade sparkles locally for the player who bought the upgrade.
-- This uses the exact same PurchaseEffectModule as normal machine purchases,
-- but avoids server particle replication timing issues.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sparkleEvent = ReplicatedStorage:WaitForChild("MachineUpgradeSparkleEvent")
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))

local function getMachine(slot)
	return slot and (slot:FindFirstChild("Dropper") or slot:FindFirstChild("Conveyor")) or nil
end

local function collectPurchaseSparkleParts(slot)
	local parts = {}
	local machine = getMachine(slot)
	if not machine then
		return parts
	end

	for _, descendant in ipairs(machine:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if machine.Name == "Dropper" then
				if descendant.Name ~= "Collector" then
					table.insert(parts, descendant)
				end
			elseif machine.Name == "Conveyor" then
				if descendant.Name ~= "Spawner" and descendant.Name ~= "EndZone" then
					table.insert(parts, descendant)
				end
			else
				table.insert(parts, descendant)
			end
		end
	end

	return parts
end

local function getFallbackPosition(slot)
	local machine = getMachine(slot)
	if machine then
		if machine:IsA("Model") then
			local primaryPart = machine.PrimaryPart or machine:FindFirstChildWhichIsA("BasePart", true)
			if primaryPart then
				return primaryPart.Position
			end
		elseif machine:IsA("BasePart") then
			return machine.Position
		end
	end

	local pad = slot and slot:FindFirstChild("UpgradeBuyPad")
	if pad and pad:IsA("BasePart") then
		return pad.Position
	end

	local fallbackPart = slot and slot:FindFirstChildWhichIsA("BasePart", true)
	return fallbackPart and fallbackPart.Position or nil
end

local function playUpgradeSparkle(slot)
	if typeof(slot) ~= "Instance" or not slot:IsDescendantOf(workspace) then
		return
	end

	local parts = collectPurchaseSparkleParts(slot)
	if #parts > 0 then
		PurchaseEffectModule.PlayAcrossParts(parts)
	else
		local fallbackPosition = getFallbackPosition(slot)
		if fallbackPosition then
			PurchaseEffectModule.Play(fallbackPosition)
		end
	end
end

sparkleEvent.OnClientEvent:Connect(playUpgradeSparkle)
