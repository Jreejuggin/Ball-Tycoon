-- MainHUDBuilder
-- Constructs the MainHUD instance tree in code, replacing the hand-placed
-- copy that previously lived inside src/StarterGui/MainHUD.rbxm. Values are
-- reproduced from that binary exactly; see Milestone notes where the written
-- spec and the binary disagreed.
--
-- Call build(gui) before any controller logic reads these instances --
-- MainHUDController dot-indexes several of them, so they must exist first.

local MainHUDBuilder = {}

local function new(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(radius, parent)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(thickness, transparency, color, parent, name)
	return new("UIStroke", {
		Name = name or "UIStroke",
		Thickness = thickness,
		Transparency = transparency,
		Color = color,
	}, parent)
end

local function padding(top, bottom, left, right, parent)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right),
	}, parent)
end

local function listLayout(paddingPx, parent)
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, paddingPx),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
end

local STROKE_GREY = Color3.fromRGB(84, 89, 102)
local PANEL_STROKE = Color3.fromRGB(92, 97, 107)
local PANEL_DARK = Color3.fromRGB(28, 31, 36)
local BUTTON_DARK = Color3.fromRGB(41, 43, 48)
local CLOSE_RED = Color3.fromRGB(217, 77, 77)
local WHITE = Color3.fromRGB(255, 255, 255)

-- The standard panel header: a transparent bar holding a left-aligned title
-- and a square close button. The MainHUD panels and the MiddleShops panels
-- were built at different times and differ in closeRadius, the bar's
-- LayoutOrder and the title's BorderSizePixel, so those are per-caller.
local function titleBar(parent, titleText, closeRadius, barLayoutOrder, titleBorderSizePixel)
	local bar = new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = barLayoutOrder,
	}, parent)

	new("TextLabel", {
		Name = "TitleLabel",
		Size = UDim2.new(1, -36, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = titleBorderSizePixel,
		Text = titleText,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0,
	}, bar)

	local close = new("TextButton", {
		Name = "CloseButton",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -32, 0, 2),
		BackgroundColor3 = CLOSE_RED,
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextStrokeTransparency = 0,
	}, bar)
	corner(closeRadius, close)

	return bar
end

-- Scrolling row container. Left empty here: ShopPanelController, the
-- MiddleShops panels and CashPackPanelController each populate their own.
local function itemList(parent, topOffset, scrollBarColor)
	local list = new("ScrollingFrame", {
		Name = "ItemList",
		Size = UDim2.new(1, 0, 1, -topOffset),
		Position = UDim2.new(0, 0, 0, topOffset),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		ClipsDescendants = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = scrollBarColor,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	listLayout(10, list)
	padding(0, 0, 0, 10, list)
	return list
end

local function buildCashHUDGroup(gui)
	local group = new("Frame", {
		Name = "CashHUDGroup",
		Size = UDim2.new(0, 190, 0, 160),
		Position = UDim2.new(-0.013, 20, 0.513, -148),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, gui)

	local cashPanel = new("Frame", {
		Name = "CashPanel",
		Size = UDim2.new(0, 190, 0, 52),
		Position = UDim2.new(0, 0, 0, 56),
		BackgroundColor3 = PANEL_DARK,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, group)
	corner(16, cashPanel)
	stroke(2, 0.25, STROKE_GREY, cashPanel)
	padding(8, 8, 8, 8, cashPanel)

	new("TextLabel", {
		Name = "CashLabel",
		Size = UDim2.new(0, 92, 0, 36),
		Position = UDim2.new(-0.2744101583957672, 52, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Text = "$0",
		TextColor3 = Color3.fromRGB(107, 242, 140),
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0,
	}, cashPanel)

	local plusButton = new("TextButton", {
		Name = "PlusButton",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(71, 199, 107),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Text = "+",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextStrokeTransparency = 0,
	}, cashPanel)
	corner(8, plusButton)

	-- TextSize/TextStroke/RichText below have no visible effect while Text is
	-- empty, but are reproduced so the instance matches the binary exactly.
	local teleportButton = new("TextButton", {
		Name = "TeleportToTycoonButton",
		Size = UDim2.new(0, 44, 0, 44),
		Position = UDim2.new(0.15263158082962036, 0, 0.01875000074505806, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(76, 155, 86),
		BorderSizePixel = 0,
		ZIndex = 3,
		Text = "",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextStrokeTransparency = 0.44999998807907104,
		TextWrapped = true,
		RichText = true,
	}, group)
	corner(8, teleportButton)
	stroke(2, 0, Color3.fromRGB(181, 255, 144), teleportButton, "AccentStroke")

	-- Spec described this as "0.475 -> 1 (blue -> green-ish)" with six
	-- transparency keypoints. The binary has two green keypoints and a fully
	-- opaque transparency sequence; 0.475 was the first colour's red channel.
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(121, 226, 127), Color3.fromRGB(50, 132, 65)),
	}, teleportButton)

	new("ImageLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = "rbxassetid://79152891526373",
		ScaleType = Enum.ScaleType.Fit,
	}, teleportButton)

	local settingsButton = new("TextButton", {
		Name = "SettingsButton",
		Size = UDim2.new(0, 58, 0, 44),
		Position = UDim2.new(0, 0, 0, 116),
		BackgroundColor3 = BUTTON_DARK,
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "⚙",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextStrokeTransparency = 0,
		TextWrapped = true,
	}, group)
	corner(12, settingsButton)
	stroke(2, 0.25, STROKE_GREY, settingsButton)
	-- Second UICorner is a leftover from an earlier fix; kept so the tree
	-- matches the binary. Roblox applies only one, so it has no visual effect.
	corner(8, settingsButton)

	new("ImageLabel", {
		Size = UDim2.new(0, 58, 0, 44),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "rbxassetid://86564279252401",
		ScaleType = Enum.ScaleType.Stretch,
	}, settingsButton)

	local function quickActionButton(name, xOffset, text)
		local button = new("TextButton", {
			Name = name,
			Size = UDim2.new(0, 58, 0, 44),
			Position = UDim2.new(0, xOffset, 0, 116),
			BackgroundColor3 = BUTTON_DARK,
			BorderSizePixel = 0,
			ZIndex = 2,
			Text = text,
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBlack,
			TextSize = 8,
			TextScaled = true,
			TextStrokeTransparency = 0,
			TextWrapped = true,
		}, group)
		corner(8, button)
		stroke(2, 0.25, STROKE_GREY, button)
		padding(0, 0, 0, 0, button)
		return button
	end

	quickActionButton("ShopButton", 66, "Shop")
	quickActionButton("PetsButton", 132, "Pets")

	return group
end

local function buildSettingsPanel(gui)
	local panel = new("Frame", {
		Name = "SettingsPanel",
		Size = UDim2.new(0, 300, 0, 210),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PANEL_DARK,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(20, panel)
	stroke(2, 0.15000000596046448, PANEL_STROKE, panel)
	padding(14, 14, 14, 14, panel)
	listLayout(10, panel)

	titleBar(panel, "Settings", 10, 1, 0)

	-- MusicRow keeps BorderSizePixel at its default of 1 while SFXRow sets 0.
	-- Invisible either way (the rows are transparent), but reproduced as-is.
	--
	-- ToggleButton is the switch's pill-shaped track (already fully rounded --
	-- corner radius 15 on a 30px-tall track); Knob is the circular thumb that
	-- MainHUDController slides between the two ends. Both start in the "on"
	-- position/color since Music and SFX default to unmuted.
	local function toggleRow(name, labelText, layoutOrder, borderSizePixel)
		local row = new("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = borderSizePixel,
			LayoutOrder = layoutOrder,
		}, panel)

		new("TextLabel", {
			Name = "Label",
			Size = UDim2.new(0, 150, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = labelText,
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeTransparency = 0.4000000059604645,
		}, row)

		local toggle = new("TextButton", {
			Name = "ToggleButton",
			Size = UDim2.new(0, 60, 0, 30),
			Position = UDim2.new(1, -60, 0.5, -15),
			BackgroundColor3 = Color3.fromRGB(71, 199, 107),
			BorderSizePixel = 0,
			Text = "",
		}, row)
		corner(15, toggle)

		local knob = new("Frame", {
			Name = "Knob",
			Size = UDim2.new(0, 24, 0, 24),
			Position = UDim2.new(1, -27, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, toggle)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, knob)

		return row
	end

	toggleRow("MusicRow", "Music", 2, 1)
	toggleRow("SFXRow", "SFX", 3, 0)

	return panel
end

local function buildRichestBanner(gui)
	local banner = new("Frame", {
		Name = "RichestBanner",
		Size = UDim2.new(0, 0, 0, 40),
		Position = UDim2.new(0.5, 0, -0.08698859065771103, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(28, 30, 34),
		BorderSizePixel = 0,
		ZIndex = 5,
		AutomaticSize = Enum.AutomaticSize.X,
	}, gui)
	corner(20, banner)
	stroke(2, 0.10000000149011612, Color3.fromRGB(255, 200, 60), banner)
	padding(0, 0, 18, 18, banner)

	new("TextLabel", {
		Name = "RichestLabel",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "★ Richest: --- ($0)",
		TextColor3 = Color3.fromRGB(255, 205, 70),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextStrokeTransparency = 0,
	}, banner)

	return banner
end

local function buildHealthBar(gui)
	local bar = new("Frame", {
		Name = "HealthBar",
		Size = UDim2.new(0, 220, 0, 36),
		Position = UDim2.new(0, 2, 1, -2),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, gui)
	corner(18, bar)
	stroke(3, 0, Color3.fromRGB(10, 10, 10), bar)

	local fill = new("Frame", {
		Name = "FillBar",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(90, 200, 90),
		BorderSizePixel = 0,
	}, bar)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(140, 230, 120), Color3.fromRGB(60, 170, 70)),
	}, fill)
	corner(18, fill)

	new("TextLabel", {
		Name = "HealthLabel",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Text = "100/100",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextStrokeTransparency = 0,
	}, bar)

	return bar
end

local function buildShopPanel(gui)
	local panel = new("Frame", {
		Name = "ShopPanel",
		Size = UDim2.new(0, 380, 0, 420),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PANEL_DARK,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(20, panel)
	stroke(2, 0.15000000596046448, PANEL_STROKE, panel)
	padding(0, 0, 0, 0, panel)

	-- Spec said this CloseButton matches SettingsPanel's (radius 10). It is
	-- actually 8, as is PetsPanel's; the MiddleShops panels do use 10.
	titleBar(panel, "Shop", 8, 1, 0)
	itemList(panel, 46, Color3.fromRGB(210, 165, 60))

	return panel
end

local function buildPetsPanel(gui)
	local panel = new("Frame", {
		Name = "PetsPanel",
		Size = UDim2.new(0, 320, 0, 260),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PANEL_DARK,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(20, panel)
	stroke(2, 0.15000000596046448, PANEL_STROKE, panel)
	padding(0, 0, 0, 0, panel)
	listLayout(0, panel)

	-- See buildShopPanel: radius 8, not the 10 the spec described.
	titleBar(panel, "Pets", 8, 1, 0)

	local function placeholderRow(name, labelText, layoutOrder)
		local row = new("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = layoutOrder,
		}, panel)

		new("TextLabel", {
			Name = "Label",
			Size = UDim2.new(0, 150, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = labelText,
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeTransparency = 0.4000000059604645,
		}, row)

		-- Spec recorded the pill background as unset/default; it is actually
		-- this grey on all three rows.
		local pill = new("TextLabel", {
			Name = "SoonPill",
			Size = UDim2.new(0, 70, 0, 28),
			Position = UDim2.new(1, -70, 0.5, -14),
			BackgroundColor3 = Color3.fromRGB(89, 92, 102),
			BorderSizePixel = 0,
			Text = "Soon",
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextStrokeTransparency = 0,
		}, row)
		corner(8, pill)

		return row
	end

	placeholderRow("EquippedRow", "Equipped", 2)
	placeholderRow("OwnedRow", "Owned", 3)
	placeholderRow("InventoryRow", "Inventory", 4)

	return panel
end

local function buildCashPackPanel(gui)
	local panel = new("Frame", {
		Name = "CashPackPanel",
		Size = UDim2.new(0, 380, 0, 420),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(20, panel)
	stroke(3, 0, Color3.fromRGB(70, 200, 90), panel)
	padding(14, 14, 14, 14, panel)

	-- Taller header than the shared titleBar, with a circular "$" badge, so
	-- this one is built out rather than reusing that helper.
	local bar = new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, panel)

	local badge = new("Frame", {
		Name = "TitleBadge",
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, bar)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, badge)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "$",
		TextColor3 = Color3.fromRGB(20, 20, 20),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
	}, badge)

	new("TextLabel", {
		Name = "TitleLabel",
		Size = UDim2.new(1, -94, 1, 0),
		Position = UDim2.new(0, 50, 0, 0),
		BackgroundTransparency = 1,
		Text = "Cash",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0,
	}, bar)

	local close = new("TextButton", {
		Name = "CloseButton",
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(220, 60, 60),
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextStrokeTransparency = 0,
	}, bar)
	corner(10, close)

	itemList(panel, 54, Color3.fromRGB(80, 210, 100))

	return panel
end

-- Shared chrome for the NPC shop panels. Despite the spec describing these as
-- mirroring ShopPanel, they differ: a slightly different background, no
-- UIPadding, and a radius-10 close button where ShopPanel's is 8.
local function buildMiddleShopPanel(gui, name, titleText)
	local panel = new("Frame", {
		Name = name,
		Size = UDim2.new(0, 380, 0, 420),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(28, 30, 34),
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(20, panel)
	stroke(2, 0.15000000596046448, PANEL_STROKE, panel)

	titleBar(panel, titleText, 10, 0, 1)
	itemList(panel, 46, Color3.fromRGB(210, 165, 60))

	return panel
end

-- One shared label reused for every hover tooltip, positioned and filled in at
-- runtime by ReplicatedStorage.Tooltip. Text is left at the TextLabel default.
local function buildTooltip(gui)
	local tooltip = new("TextLabel", {
		Name = "Tooltip",
		Size = UDim2.new(0, 0, 0, 28),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(20, 20, 22),
		BorderSizePixel = 0,
		ZIndex = 100,
		Visible = false,
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, gui)
	padding(0, 0, 10, 10, tooltip)
	corner(6, tooltip)
	stroke(1, 0.30000001192092896, Color3.fromRGB(90, 92, 98), tooltip)

	return tooltip
end

-- Built in the same order as the children of the hand-placed MainHUD, so the
-- two trees can be compared child-by-child.
function MainHUDBuilder.build(gui)
	buildSettingsPanel(gui)
	buildRichestBanner(gui)
	buildHealthBar(gui)
	buildShopPanel(gui)
	buildPetsPanel(gui)
	buildCashPackPanel(gui)
	buildCashHUDGroup(gui)

	-- Only the shops that still exist in Workspace.MiddleShops. The former
	-- Trading Post, Vault and Upgrade Shop panels are deliberately not built.
	buildMiddleShopPanel(gui, "CreatureShopPanel", "Creature Shop")
	buildMiddleShopPanel(gui, "BallShopPanel", "Ball Shop")
	buildMiddleShopPanel(gui, "GearShopPanel", "Gear Shop")

	buildTooltip(gui)
end

return MainHUDBuilder
