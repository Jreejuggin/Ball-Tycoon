-- SprintSystem
-- Left Shift uses the server-owned SprintSpeedMultiplier reward.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local NORMAL_SPEED = 16
local BASE_SPRINT_SPEED = 44
local SPRINT_MULTIPLIER_ATTRIBUTE = "SprintSpeedMultiplier"

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local isSprinting = false

local function getSprintSpeed()
	local multiplier = tonumber(player:GetAttribute(SPRINT_MULTIPLIER_ATTRIBUTE)) or 1
	return BASE_SPRINT_SPEED * math.clamp(multiplier, 1, 3)
end

local function setSprinting(enabled)
	isSprinting = enabled
	humanoid.WalkSpeed = enabled and getSprintSpeed() or NORMAL_SPEED
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- gameProcessed filters out typing-in-chat so Shift does not trigger while chatting.
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSprinting(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSprinting(false)
	end
end)

player:GetAttributeChangedSignal(SPRINT_MULTIPLIER_ATTRIBUTE):Connect(function()
	if isSprinting then
		humanoid.WalkSpeed = getSprintSpeed()
	end
end)

humanoid.Died:Connect(function()
	setSprinting(false)
end)