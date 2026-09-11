--!strict
-- Owner-only local preview for Speed Upgrade Treadmills on P1-P10.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TreadmillTheme = require(ReplicatedStorage:WaitForChild("TreadmillTheme"))

local player = Players.LocalPlayer
local GHOST_VISIBLE_TO = "Owner" -- "Owner" | "Everyone"
local REFRESH_SECONDS = 0.5
local GHOST_TEMPLATE = ReplicatedStorage:WaitForChild("Ghosts")
	:WaitForChild("SpeedUpgrade_Treadmill_Ghost")

local ghost: Model? = nil
local ghostSlot: Instance? = nil

local function placeModel(model: Model, targetCFrame: CFrame, referencePart: BasePart)
	local origin = referencePart.CFrame
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CFrame = targetCFrame * origin:ToObjectSpace(descendant.CFrame)
		end
	end
end

local function findVisibleSlot()
	for plotIndex = 1, 10 do
		local plot = workspace:FindFirstChild("P" .. plotIndex)
		local ownerId = plot and tonumber(plot:GetAttribute("Owner"))
		local centreSlots = plot and plot:FindFirstChild("CentreSlots")
		local avatarCentre = centreSlots and centreSlots:FindFirstChild("Centre03_Avatar")
		local upgrades = avatarCentre and avatarCentre:FindFirstChild("Upgrades")
		local slot = upgrades and upgrades:FindFirstChild("SpeedUpgradeTreadmill")
		local activated = slot and slot:FindFirstChild("Activated")

		if plot
			and slot
			and activated
			and activated:IsA("BoolValue")
			and not activated.Value
			and ownerId
			and (GHOST_VISIBLE_TO == "Everyone" or ownerId == player.UserId)
		then
			return slot
		end
	end
	return nil
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
		ghostSlot = nil
	end
end

local function showGhost(slot: Instance)
	if ghost and ghost.Parent and ghostSlot == slot then
		return
	end
	clearGhost()

	local anchor = slot:FindFirstChild("Anchor")
	if not anchor or not anchor:IsA("BasePart") then
		return
	end

	local clone = GHOST_TEMPLATE:Clone()
	clone.Name = "GhostPreview"
	local base = clone:FindFirstChild("Base_Main")
	if not base or not base:IsA("BasePart") then
		clone:Destroy()
		return
	end

	TreadmillTheme.ApplyLocked(clone)
	clone:SetAttribute("ClientOwnedPreview", true)
	clone.Parent = slot
	placeModel(clone, anchor.CFrame, base)
	ghost = clone
	ghostSlot = slot
end

while true do
	local slot = findVisibleSlot()
	if slot then
		showGhost(slot)
	else
		clearGhost()
	end
	task.wait(REFRESH_SECONDS)
end
