--[[
	BankFeedbackClient
	Purely visual. Shows a countdown while the server is banking this player's
	gems, and a short message when a deposit completes. The server decides
	everything; this script never sends anything back.
	The UI is built in code, so no StarterGui edits are needed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local BankDepositEvent = ReplicatedStorage:WaitForChild("BankDepositEvent")

local TOAST_SECONDS = 3

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BankFeedbackGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name, yScale, textColor)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, yScale, 0)
	label.Size = UDim2.new(0, 380, 0, 44)
	label.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = textColor
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.Visible = false
	label.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	return label
end

local toastLabel = makeLabel("DepositToast", 0.10, Color3.fromRGB(110, 235, 255))
local countdownLabel = makeLabel("Countdown", 0.17, Color3.fromRGB(255, 255, 255))

-- Countdown: driven by an attribute the server updates while a deposit is pending.
local function refreshCountdown()
	local secondsLeft = player:GetAttribute("BankDepositSecondsLeft")
	if secondsLeft then
		countdownLabel.Text = ("Banking gems... stay put for %ds"):format(secondsLeft)
		countdownLabel.Visible = true
	else
		countdownLabel.Visible = false
	end
end

player:GetAttributeChangedSignal("BankDepositSecondsLeft"):Connect(refreshCountdown)
refreshCountdown()

-- Deposit message: fired by the server once gems are actually banked.
local toastToken = 0

BankDepositEvent.OnClientEvent:Connect(function(amountDeposited, totalBanked)
	toastToken += 1
	local myToken = toastToken

	toastLabel.Text = ("+%d Gems deposited! Bank total: %d"):format(amountDeposited, totalBanked)
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.25
	toastLabel.Visible = true

	task.delay(TOAST_SECONDS, function()
		if myToken ~= toastToken then
			return -- a newer message took over
		end
		local fade = TweenService:Create(toastLabel, TweenInfo.new(0.4), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		fade:Play()
		fade.Completed:Wait()
		if myToken == toastToken then
			toastLabel.Visible = false
		end
	end)
end)