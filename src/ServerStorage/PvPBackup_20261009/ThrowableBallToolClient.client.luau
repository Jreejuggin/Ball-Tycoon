--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local tool = script.Parent :: Tool
local throwEvent = tool:WaitForChild("ThrowEvent") :: RemoteEvent
local mouse: Mouse? = nil
local lastThrowAt = -math.huge

local function getAimDirection(): Vector3?
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root or not root:IsA("BasePart") then
		return nil
	end
	local inputType = UserInputService:GetLastInputType()
	local usesPointer = inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.Keyboard
	local currentMouse = mouse
	if usesPointer and currentMouse then
		local offset = currentMouse.Hit.Position - (root.Position + Vector3.yAxis)
		if offset.Magnitude > 0.01 then
			return offset.Unit
		end
	end
	local viewport = camera.ViewportSize
	return camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5).Direction.Unit
end

tool.Equipped:Connect(function(equippedMouse: Mouse)
	mouse = equippedMouse
end)

tool.Unequipped:Connect(function()
	mouse = nil
end)

tool.Activated:Connect(function()
	if tool.Parent ~= player.Character then
		return
	end
	local cooldown = tonumber(tool:GetAttribute("ThrowCooldown")) or 1.2
	local now = os.clock()
	if now - lastThrowAt < cooldown then
		return
	end
	local direction = getAimDirection()
	if direction then
		lastThrowAt = now
		-- Only aim is sent; the server owns the origin, cooldown, collision and damage.
		throwEvent:FireServer(direction)
	end
end)
