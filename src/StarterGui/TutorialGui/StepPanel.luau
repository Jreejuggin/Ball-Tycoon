-- StepPanel
-- Small, non-modal banner shown while a tutorial step is active: just the
-- step's title and dialog text, updated in place as the player moves
-- through TutorialConfig. Unlike WelcomePanel this does NOT register with
-- PanelManager -- it isn't a modal dialog fighting Settings/Shop/Pets for
-- the screen, it's a persistent hint that should stay up even if the
-- player opens one of those while working through a step.
--
-- This module only builds the UI -- it does not decide which step is
-- active or when to show/hide itself (that's TutorialController's job).
--
-- Usage:
--   StepPanel.Show({ title = "...", dialog = "..." })
--   StepPanel.Hide()

local screenGui = script.Parent

local BANNER_SIZE = UDim2.fromOffset(420, 96)
local BACKGROUND_COLOR = Color3.fromRGB(28, 30, 38)
local STROKE_COLOR = Color3.fromRGB(60, 64, 78)
local TITLE_COLOR = Color3.fromRGB(255, 221, 64) -- matches ArrowTrail's chevron color
local DIALOG_COLOR = Color3.fromRGB(215, 218, 228)

local StepPanel = {}

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

local banner = Instance.new("Frame")
banner.Name = "StepPanel"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 110)
banner.Size = BANNER_SIZE
banner.BackgroundColor3 = BACKGROUND_COLOR
banner.BackgroundTransparency = 0.08
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = screenGui
corner(14, banner)
stroke(banner, STROKE_COLOR, 2)

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 14)
padding.PaddingBottom = UDim.new(0, 14)
padding.PaddingLeft = UDim.new(0, 18)
padding.PaddingRight = UDim.new(0, 18)
padding.Parent = banner

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = banner

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 22)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = TITLE_COLOR
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = ""
title.LayoutOrder = 1
title.Parent = banner

local dialog = Instance.new("TextLabel")
dialog.Name = "Dialog"
dialog.BackgroundTransparency = 1
dialog.Size = UDim2.new(1, 0, 0, 52)
dialog.Font = Enum.Font.Gotham
dialog.TextSize = 15
dialog.TextColor3 = DIALOG_COLOR
dialog.TextWrapped = true
dialog.TextXAlignment = Enum.TextXAlignment.Left
dialog.TextYAlignment = Enum.TextYAlignment.Top
dialog.Text = ""
dialog.LayoutOrder = 2
dialog.Parent = banner

function StepPanel.Show(stepConfig)
	title.Text = stepConfig.title or ""
	dialog.Text = stepConfig.dialog or ""
	banner.Visible = true
end

function StepPanel.Hide()
	banner.Visible = false
end

return StepPanel
