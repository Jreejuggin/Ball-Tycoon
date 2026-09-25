-- TEMPORARY -- delete once BankPanel UI exists.
-- Press 1 to deposit 50, press 2 to withdraw 50.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BankTransactionEvent = ReplicatedStorage:WaitForChild("BankTransactionEvent")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.One then
		print("Requesting deposit of 50...")
		BankTransactionEvent:FireServer("Deposit", 50)
	elseif input.KeyCode == Enum.KeyCode.Two then
		print("Requesting withdraw of 50...")
		BankTransactionEvent:FireServer("Withdraw", 50)
	end
end)

-- The server only fires back on FAILURE (success is silent -- the Value
-- objects update and replicate on their own). Print whatever comes back.
BankTransactionEvent.OnClientEvent:Connect(function(success, message)
	print("Bank response:", success, message)
end)