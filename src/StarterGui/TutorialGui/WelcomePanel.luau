-- WelcomePanel
-- The first-time tutorial's welcome dialog. Entirely code-generated
-- (Instance.new) so it needs no hand-placed Studio instances and syncs
-- cleanly through Rojo -- see CONTRIBUTING.md's note on .rbxm files for why
-- nothing here lives in one.
--
-- Registers itself with PanelManager exactly like every panel already inside
-- MainHUD (Settings/Shop/Pets/...), so opening this closes any of those if
-- one happened to be open, and vice versa.
--
-- This module only builds the UI and reports intent -- it does not decide
-- WHEN to show itself (that's the tutorial controller's job: wait for
-- DataLoaded, check the TutorialEligible attribute, then call Show()) and it
-- does not talk to the server (the controller reacts to StartRequested /
-- SkipRequested and writes progress there). Keeps this module reusable and
-- easy to reason about on its own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))
local ButtonHoverEffect = require(ReplicatedStorage:WaitForChild("ButtonHoverEffect"))

local WELCOME_TITLE = "Welcome to Ball Tycoon!"
local WELCOME_BODY = "Drop balls, collect cash, and grow your very own tycoon. "
	.. "We'll walk you through your first dropper, your first upgrade, and your "
	.. "first worker -- it only takes a minute."
local START_BUTTON_TEXT = "Let's Go!"
local SKIP_BUTTON_TEXT = "Skip Tutorial"

local CARD_SIZE = UDim2.fromOffset(460, 300)
local BACKGROUND_COLOR = Color3.fromRGB(28, 30, 38)
local STROKE_COLOR = Color3.fromRGB(60, 64, 78)
local TITLE_COLOR = Color3.fromRGB(255, 255, 255)
local BODY_COLOR = Color3.fromRGB(205, 208, 218)
local START_COLOR = Color3.fromRGB(235, 190, 50)
local START_TEXT_COLOR = Color3.fromRGB(40, 30, 0)
local SKIP_COLOR = Color3.fromRGB(52, 55, 66)
local SKIP_TEXT_COLOR = Color3.fromRGB(205, 208, 218)

local screenGui = script.Parent

local WelcomePanel = {}

-- Private signal instances. Only this module can Fire them -- everything
-- else (Phase 5's controller) only ever sees the read-only .Event below, so
-- nothing outside this file can fake a Start/Skip.
local startRequestedSignal = Instance.new("BindableEvent")
local skipRequestedSignal = Instance.new("BindableEvent")

WelcomePanel.StartRequested = startRequestedSignal.Event
WelcomePanel.SkipRequested = skipRequestedSignal.Event

local function corner(radius, parent)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
	return uiCorner
end

local function stroke(parent, color, thickness)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color
	uiStroke.Thickness = thickness or 1
	uiStroke.Parent = parent
	return uiStroke
end

local function makeButton(text, backgroundColor, textColor, layoutOrder)
	local button = Instance.new("TextButton")
	button.Name = (text:gsub("%s", ""))
	button.Size = UDim2.new(0, 190, 0, 44)
	button.BackgroundColor3 = backgroundColor
	button.Text = text
	button.TextColor3 = textColor
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.AutoButtonColor = false
	button.LayoutOrder = layoutOrder
	corner(10, button)
	return button
end

local card = Instance.new("Frame")
card.Name = "WelcomePanel"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = CARD_SIZE
card.BackgroundColor3 = BACKGROUND_COLOR
card.BorderSizePixel = 0
card.Visible = false
card.Parent = screenGui
corner(16, card)
stroke(card, STROKE_COLOR, 2)

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 28)
padding.PaddingBottom = UDim.new(0, 24)
padding.PaddingLeft = UDim.new(0, 28)
padding.PaddingRight = UDim.new(0, 28)
padding.Parent = card

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 18)
layout.Parent = card

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 36)
title.Font = Enum.Font.GothamBold
title.TextSize = 26
title.TextColor3 = TITLE_COLOR
title.Text = WELCOME_TITLE
title.LayoutOrder = 1
title.Parent = card

local body = Instance.new("TextLabel")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, 0, 0, 100)
body.Font = Enum.Font.Gotham
body.TextSize = 16
body.TextColor3 = BODY_COLOR
body.TextWrapped = true
body.TextYAlignment = Enum.TextYAlignment.Top
body.Text = WELCOME_BODY
body.LayoutOrder = 2
body.Parent = card

local buttonRow = Instance.new("Frame")
buttonRow.Name = "ButtonRow"
buttonRow.BackgroundTransparency = 1
buttonRow.Size = UDim2.new(1, 0, 0, 44)
buttonRow.LayoutOrder = 3
buttonRow.Parent = card

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Padding = UDim.new(0, 16)
buttonLayout.Parent = buttonRow

local startButton = makeButton(START_BUTTON_TEXT, START_COLOR, START_TEXT_COLOR, 1)
startButton.Parent = buttonRow
-- ButtonHoverEffect captures the button's resting Size/Position the moment
-- it's applied, so it has to run after the button has its real layout
-- position -- same ordering ShopRowBuilder uses for its Buy buttons.
ButtonHoverEffect.apply(startButton)

local skipButton = makeButton(SKIP_BUTTON_TEXT, SKIP_COLOR, SKIP_TEXT_COLOR, 2)
skipButton.Parent = buttonRow
ButtonHoverEffect.apply(skipButton)

PanelManager.registerPanel(card)

function WelcomePanel.Show()
	PanelManager.open(card)
end

function WelcomePanel.Hide()
	card.Visible = false
end

-- Activated covers mouse, touch, and gamepad select in one signal, unlike
-- ButtonHoverEffect's mouse-only hover wiring above -- this project supports
-- mobile (see ScreenOrientation in default.project.json), so the actual
-- purchase-equivalent action has to work without a mouse.
startButton.Activated:Connect(function()
	WelcomePanel.Hide()
	startRequestedSignal:Fire()
end)

skipButton.Activated:Connect(function()
	WelcomePanel.Hide()
	skipRequestedSignal:Fire()
end)

return WelcomePanel
