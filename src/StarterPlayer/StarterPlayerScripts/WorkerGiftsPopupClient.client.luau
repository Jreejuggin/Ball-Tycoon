--!strict
-- Temporary Worker Gifts interaction popup.
-- Replace this presentation when the final Worker Gifts UI is ready; the
-- server-side prompt, ownership validation, and RemoteEvent can stay in place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local interactionEvent = ReplicatedStorage:WaitForChild("WorkerGiftsInteractionEvent") :: RemoteEvent

local existingGui = playerGui:FindFirstChild("WorkerGiftsPopupGui")
if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WorkerGiftsPopupGui"
screenGui.DisplayOrder = 60
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local popup = Instance.new("CanvasGroup")
popup.Name = "Popup"
popup.AnchorPoint = Vector2.new(0.5, 0)
popup.Position = UDim2.new(0.5, 0, -0.2, 0)
popup.Size = UDim2.fromOffset(430, 112)
popup.BackgroundColor3 = Color3.fromRGB(20, 27, 40)
popup.BackgroundTransparency = 0.05
popup.GroupTransparency = 1
popup.Visible = false
popup.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = popup

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 225, 255)
stroke.Thickness = 3
stroke.Transparency = 0.05
stroke.Parent = popup

local giftIcon = Instance.new("TextLabel")
giftIcon.Name = "GiftIcon"
giftIcon.BackgroundTransparency = 1
giftIcon.Position = UDim2.fromOffset(14, 14)
giftIcon.Size = UDim2.fromOffset(78, 78)
giftIcon.Font = Enum.Font.GothamBold
giftIcon.Text = "🎁"
giftIcon.TextColor3 = Color3.new(1, 1, 1)
giftIcon.TextScaled = true
giftIcon.Parent = popup

local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.BackgroundTransparency = 1
titleText.Position = UDim2.fromOffset(96, 12)
titleText.Size = UDim2.new(1, -112, 0, 36)
titleText.Font = Enum.Font.GothamBold
titleText.Text = "Daily Worker Gifts"
titleText.TextColor3 = Color3.fromRGB(0, 225, 255)
titleText.TextSize = 25
titleText.TextStrokeColor3 = Color3.new(0, 0, 0)
titleText.TextStrokeTransparency = 0.35
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = popup

local messageText = Instance.new("TextLabel")
messageText.Name = "MessageText"
messageText.BackgroundTransparency = 1
messageText.Position = UDim2.fromOffset(96, 48)
messageText.Size = UDim2.new(1, -112, 0, 48)
messageText.Font = Enum.Font.GothamBold
messageText.Text = ""
messageText.TextColor3 = Color3.fromRGB(255, 235, 90)
messageText.TextSize = 18
messageText.TextWrapped = true
messageText.TextXAlignment = Enum.TextXAlignment.Left
messageText.TextYAlignment = Enum.TextYAlignment.Top
messageText.Parent = popup

local popupSequence = 0
local activeTween: Tween? = nil

local function showPopup(payload: any)
	popupSequence += 1
	local sequence = popupSequence

	if activeTween then
		activeTween:Cancel()
	end

	if typeof(payload) == "table" then
		titleText.Text = tostring(payload.title or "Daily Worker Gifts")
		messageText.Text = tostring(payload.message or "The station was opened.")
	else
		titleText.Text = "Daily Worker Gifts"
		messageText.Text = "The station was opened."
	end

	popup.Visible = true
	popup.Position = UDim2.new(0.5, 0, -0.2, 0)
	popup.GroupTransparency = 1

	activeTween = TweenService:Create(
		popup,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0.5, 0, 0, 92),
			GroupTransparency = 0,
		}
	)
	activeTween:Play()

	task.delay(3.25, function()
		if sequence ~= popupSequence then
			return
		end

		activeTween = TweenService:Create(
			popup,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.new(0.5, 0, -0.2, 0),
				GroupTransparency = 1,
			}
		)
		activeTween:Play()
		activeTween.Completed:Once(function()
			if sequence == popupSequence then
				popup.Visible = false
			end
		end)
	end)
end

interactionEvent.OnClientEvent:Connect(showPopup)
