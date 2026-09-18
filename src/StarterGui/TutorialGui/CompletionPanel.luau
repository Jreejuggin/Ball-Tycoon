-- CompletionPanel
-- Shown once, right when the tutorial finishes the LAST step naturally (the
-- player hired their first worker) -- a small congratulations card that
-- hands the player back to the normal game. Entirely code-generated
-- (Instance.new), same reasoning as WelcomePanel: no hand-placed Studio
-- instances, syncs cleanly through Rojo.
--
-- Deliberately NOT shown when the tutorial ends via Skip -- congratulating
-- someone for skipping doesn't make sense, and TutorialController only
-- calls Show() on the wasSkipped == false path of finish().
--
-- Registers with PanelManager like every other panel here, but unlike
-- WelcomePanel it does not need a DismissedExternally escape hatch: by the
-- time this is shown, the tutorial has ALREADY finished (finish() already
-- fired TutorialCompleteEvent and cleaned up markers/state) -- nothing is
-- waiting on this panel's outcome, so PanelManager silently closing it for
-- another panel is harmless, not a deadlock.
--
-- This module only builds the UI -- it does not decide WHEN to show itself
-- (that's TutorialController's job, from finish()).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))
local ButtonHoverEffect = require(ReplicatedStorage:WaitForChild("ButtonHoverEffect"))

local TITLE_TEXT = "You're All Set!"
local BODY_TEXT = "You bought your first row of droppers, upgraded one, and hired "
	.. "your first worker -- that's the whole loop. Everything else on your "
	.. "tycoon is ready to explore: new sections to unlock, more workers to "
	.. "hire, and upgrades to chase. Have fun!"
local CONTINUE_BUTTON_TEXT = "Let's Go!"

local CARD_SIZE = UDim2.fromOffset(460, 260)
local BACKGROUND_COLOR = Color3.fromRGB(28, 30, 38)
local STROKE_COLOR = Color3.fromRGB(60, 64, 78)
local TITLE_COLOR = Color3.fromRGB(255, 255, 255)
local BODY_COLOR = Color3.fromRGB(205, 208, 218)
local CONTINUE_COLOR = Color3.fromRGB(235, 190, 50)
local CONTINUE_TEXT_COLOR = Color3.fromRGB(40, 30, 0)

local screenGui = script.Parent

local CompletionPanel = {}

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

local card = Instance.new("Frame")
card.Name = "CompletionPanel"
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
title.Text = TITLE_TEXT
title.LayoutOrder = 1
title.Parent = card

local body = Instance.new("TextLabel")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, 0, 0, 110)
body.Font = Enum.Font.Gotham
body.TextSize = 16
body.TextColor3 = BODY_COLOR
body.TextWrapped = true
body.TextYAlignment = Enum.TextYAlignment.Top
body.Text = BODY_TEXT
body.LayoutOrder = 2
body.Parent = card

local continueButton = Instance.new("TextButton")
continueButton.Name = "Continue"
continueButton.Size = UDim2.new(0, 190, 0, 44)
continueButton.BackgroundColor3 = CONTINUE_COLOR
continueButton.Text = CONTINUE_BUTTON_TEXT
continueButton.TextColor3 = CONTINUE_TEXT_COLOR
continueButton.Font = Enum.Font.GothamBold
continueButton.TextSize = 18
continueButton.AutoButtonColor = false
continueButton.LayoutOrder = 3
continueButton.Parent = card
corner(10, continueButton)
-- ButtonHoverEffect captures the button's resting Size/Position the moment
-- it's applied, so it has to run after the button has its real layout
-- position -- same ordering WelcomePanel/ShopRowBuilder use for their buttons.
ButtonHoverEffect.apply(continueButton)

PanelManager.registerPanel(card)

function CompletionPanel.Show()
	PanelManager.open(card)
end

function CompletionPanel.Hide()
	card.Visible = false
end

-- Activated covers mouse, touch, and gamepad select in one signal -- this
-- project supports mobile (see ScreenOrientation in default.project.json).
continueButton.Activated:Connect(function()
	CompletionPanel.Hide()
end)

return CompletionPanel
