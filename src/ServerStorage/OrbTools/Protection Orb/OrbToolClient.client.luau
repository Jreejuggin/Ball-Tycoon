-- Input only: the server verifies this exact equipped stack and commits the bite.
local ContextActionService = game:GetService("ContextActionService")
local tool = script.Parent
local consume = game:GetService("ReplicatedStorage"):WaitForChild("OrbRemotes"):WaitForChild("Consume")
local action = "ConsumeOrb_" .. tool:GetAttribute("OrbType")
local lastRequest = -math.huge
local function request()
    if not tool.Enabled or os.clock() - lastRequest < 0.25 then return end
    lastRequest = os.clock()
    consume:FireServer(tool:GetAttribute("OrbType"))
end
tool.Activated:Connect(request)
tool.Equipped:Connect(function()
    ContextActionService:BindAction(action, function(_, state)
        if state == Enum.UserInputState.Begin then request() end
        return Enum.ContextActionResult.Sink
    end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)
    ContextActionService:SetTitle(action, "Eat")
    ContextActionService:SetPosition(action, UDim2.new(1, -100, 1, -220))
end)
local function cleanup() ContextActionService:UnbindAction(action) end
tool.Unequipped:Connect(cleanup)
script.Destroying:Connect(cleanup)
