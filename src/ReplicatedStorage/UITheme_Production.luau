-- UITheme
-- Every visual constant for the MainHUD, in one place. Pure values: no logic,
-- no instances, no requires. Swap this module's values (or point consumers at a
-- copy of it) to restyle the whole HUD without touching a single controller.
--
-- Consumers: MainHUDBuilder, ShopRowBuilder, CashPackPanelController,
-- MainHUDController (toggle visuals only).
--
-- WHAT LIVES HERE: colours, gradients, fonts, text sizes, text-stroke
-- transparency, corner radii, stroke thickness/transparency, padding, list
-- spacing, component sizes and positions, icon asset ids, scrollbar thickness.
--
-- WHAT DELIBERATELY DOES NOT: instance names, hierarchy, ZIndex, LayoutOrder,
-- AnchorPoint, BorderSizePixel, Visible, text content, text alignment, and the
-- AutomaticSize/Scrolling/Wrapped flags. Those are structure, not style --
-- the controllers find elements by name and path, so changing them is a
-- Milestone 4 concern, not a restyle.
--
-- Several fractional values below look oddly precise (e.g. -0.2744101583957672).
-- They are faithful artifacts of the hand-placed MainHUD.rbxm this UI was
-- migrated from; they are not rounded here so the look stays byte-identical.

local Theme = {}

--=============================================================== palette

Theme.color = {
	white = Color3.fromRGB(255, 255, 255),
	textStroke = Color3.new(0, 0, 0),

	panelDark = Color3.fromRGB(28, 31, 36),
	panelStroke = Color3.fromRGB(92, 97, 107),
	strokeGrey = Color3.fromRGB(84, 89, 102),
	buttonDark = Color3.fromRGB(41, 43, 48),
	closeRed = Color3.fromRGB(217, 77, 77),

	cashGreen = Color3.fromRGB(107, 242, 140),
	accentGreen = Color3.fromRGB(71, 199, 107),
	gold = Color3.fromRGB(255, 205, 60),
	mutedGrey = Color3.fromRGB(89, 92, 102),
}

Theme.font = {
	heading = Enum.Font.GothamBlack,
	body = Enum.Font.GothamBold,
}

Theme.asset = {
	teleportIcon = "rbxassetid://79152891526373",
	inventoryIcon = "rbxassetid://71866888766572",
	settingsIcon = "rbxassetid://86564279252401",
}

--=============================================================== shared chrome

-- The look every MainHUD panel shares. Individual panels override where the
-- original binary differed.
Theme.panel = {
	cornerRadius = 20,
	background = Theme.color.panelDark,
	strokeColor = Theme.color.panelStroke,
	strokeThickness = 2,
	strokeTransparency = 0.15000000596046448,
}

Theme.titleBar = {
	height = 36,
	titleSize = UDim2.new(1, -36, 1, 0),
	titleFont = Theme.font.heading,
	titleTextSize = 22,
	titleColor = Theme.color.white,
	titleStrokeTransparency = 0,

	closeSize = UDim2.new(0, 32, 0, 32),
	closePosition = UDim2.new(1, -32, 0, 2),
	closeColor = Theme.color.closeRed,
	closeFont = Theme.font.heading,
	closeTextSize = 18,
	closeTextColor = Theme.color.white,
	closeStrokeTransparency = 0,
}

Theme.itemList = {
	scrollBarThickness = 6,
	rowSpacing = 10,
	paddingRight = 10,
	goldScrollBar = Color3.fromRGB(210, 165, 60),
	greenScrollBar = Color3.fromRGB(80, 210, 100),
}

--=============================================================== cash HUD

Theme.cashHud = {
	groupSize = UDim2.new(0, 190, 0, 160),
	groupPosition = UDim2.new(-0.013, 20, 0.513, -148),

	cashPanelSize = UDim2.new(0, 190, 0, 52),
	cashPanelPosition = UDim2.new(0, 0, 0, 56),
	cashPanelBackground = Theme.color.panelDark,
	cashPanelCorner = 16,
	cashPanelStrokeThickness = 2,
	cashPanelStrokeTransparency = 0.25,
	cashPanelStrokeColor = Theme.color.strokeGrey,
	cashPanelPadding = 8,

	cashLabelSize = UDim2.new(0, 92, 0, 36),
	cashLabelPosition = UDim2.new(-0.2744101583957672, 52, 0.5, 0),
	cashLabelColor = Theme.color.cashGreen,
	cashLabelFont = Theme.font.heading,
	cashLabelTextSize = 24,
	cashLabelStrokeTransparency = 0,

	plusSize = UDim2.new(0, 32, 0, 32),
	plusPosition = UDim2.new(1, -8, 0.5, 0),
	plusColor = Theme.color.accentGreen,
	plusCorner = 8,
	plusFont = Theme.font.heading,
	plusTextSize = 22,
	plusTextColor = Theme.color.white,
	plusStrokeTransparency = 0,

	teleportSize = UDim2.new(0, 44, 0, 44),
	teleportPosition = UDim2.new(0.15263158082962036, 0, 0.01875000074505806, 0),
	teleportColor = Color3.fromRGB(76, 155, 86),
	teleportCorner = 8,
	teleportStrokeThickness = 2,
	teleportStrokeTransparency = 0,
	teleportStrokeColor = Color3.fromRGB(181, 255, 144),
	teleportTextColor = Theme.color.white,
	teleportFont = Theme.font.heading,
	teleportTextSize = 17,
	teleportStrokeTextTransparency = 0.44999998807907104,
	teleportGradientRotation = 90,
	teleportGradient = ColorSequence.new(Color3.fromRGB(121, 226, 127), Color3.fromRGB(50, 132, 65)),

	-- InventoryButton: the house button's twin, one gap to its right. Its size,
	-- corner, stroke weight and gradient angle are read from the teleport keys
	-- above so the two cannot drift apart; only the colours and icon are its own.
	inventoryGap = 8,
	-- White, unlike the house button's green: UIGradient multiplies against
	-- BackgroundColor3, so a white base lets the gradient alone set the colour.
	-- The house button's green-on-green renders darker than either value.
	inventoryColor = Color3.fromRGB(255, 255, 255),
	inventoryStrokeColor = Color3.fromRGB(222, 178, 128),
	inventoryGradient = ColorSequence.new(Color3.fromRGB(186, 134, 82), Color3.fromRGB(110, 70, 38)),
	-- The bag art fills less of its 512 canvas than the house does (356x307
	-- against 383x379), so at 1:1 it reads visibly smaller beside it. 1.15 is
	-- the square root of the two bounding-box areas' ratio, which matches
	-- their apparent size; the art still lands inside the 44px button.
	inventoryIconScale = 1.15,

	settingsSize = UDim2.new(0, 58, 0, 44),
	settingsPosition = UDim2.new(0, 0, 0, 116),
	settingsColor = Theme.color.buttonDark,
	settingsCorner = 12,
	-- A second UICorner is applied after this one; see MainHUDBuilder.
	settingsCornerDuplicate = 8,
	settingsStrokeThickness = 2,
	settingsStrokeTransparency = 0.25,
	settingsStrokeColor = Theme.color.strokeGrey,
	settingsFont = Theme.font.heading,
	settingsTextSize = 30,
	settingsTextColor = Theme.color.white,
	settingsStrokeTextTransparency = 0,
	settingsIconSize = UDim2.new(0, 58, 0, 44),

	quickSize = UDim2.new(0, 58, 0, 44),
	quickY = 116,
	quickShopX = 66,
	quickPetsX = 132,
	quickColor = Theme.color.buttonDark,
	quickCorner = 8,
	quickStrokeThickness = 2,
	quickStrokeTransparency = 0.25,
	quickStrokeColor = Theme.color.strokeGrey,
	quickFont = Theme.font.heading,
	quickTextSize = 8,
	quickTextColor = Theme.color.white,
	quickStrokeTextTransparency = 0,
}

--=============================================================== settings panel

Theme.settings = {
	size = UDim2.new(0, 300, 0, 210),
	position = UDim2.new(0.5, 0, 0.5, 0),
	padding = 14,
	rowSpacing = 10,
	closeCorner = 10,

	rowHeight = 44,
	labelSize = UDim2.new(0, 150, 1, 0),
	labelFont = Theme.font.body,
	labelTextSize = 18,
	labelColor = Theme.color.white,
	labelStrokeTransparency = 0.4000000059604645,
}

-- The track/knob geometry is shared between MainHUDBuilder (which creates them
-- in the "on" state) and MainHUDController (which slides and recolours them).
--
-- NOTE: trackOnColor is (71,199,107) but MainHUDController's original
-- TOGGLE_ON_COLOR was (72,199,107) -- a one-step red difference, so the switch
-- shifted imperceptibly the first time it was toggled. Both values are kept
-- separate here to stay byte-identical with the current build; see
-- knobOnColorLegacy below. Collapse them when you are ready for the look to
-- change by 1/255.
Theme.toggle = {
	trackSize = UDim2.new(0, 60, 0, 30),
	trackPosition = UDim2.new(1, -60, 0.5, -15),
	trackCorner = 15,
	trackOnColor = Theme.color.accentGreen,
	trackOffColor = Color3.fromRGB(90, 92, 98),
	trackOnColorLegacy = Color3.fromRGB(72, 199, 107),

	knobSize = UDim2.new(0, 24, 0, 24),
	knobCorner = UDim.new(0.5, 0),
	knobColor = Theme.color.white,
	knobOnPosition = UDim2.new(1, -27, 0.5, 0),
	knobOffPosition = UDim2.new(0, 3, 0.5, 0),
}

--=============================================================== richest banner

Theme.richestBanner = {
	size = UDim2.new(0, 0, 0, 40),
	position = UDim2.new(0.5, 0, -0.08698859065771103, 12),
	background = Color3.fromRGB(28, 30, 34),
	cornerRadius = 20,
	strokeThickness = 2,
	strokeTransparency = 0.10000000149011612,
	strokeColor = Color3.fromRGB(255, 200, 60),
	paddingX = 18,

	labelColor = Color3.fromRGB(255, 205, 70),
	labelFont = Theme.font.heading,
	labelTextSize = 20,
	labelStrokeTransparency = 0,
}

--=============================================================== health bar

Theme.healthBar = {
	size = UDim2.new(0, 220, 0, 36),
	position = UDim2.new(0, 2, 1, -2),
	background = Color3.fromRGB(15, 15, 15),
	cornerRadius = 18,
	strokeThickness = 3,
	strokeTransparency = 0,
	strokeColor = Color3.fromRGB(10, 10, 10),

	fillColor = Color3.fromRGB(90, 200, 90),
	fillCorner = 18,
	fillGradientRotation = 90,
	fillGradient = ColorSequence.new(Color3.fromRGB(140, 230, 120), Color3.fromRGB(60, 170, 70)),

	labelFont = Theme.font.body,
	labelTextSize = 20,
	labelColor = Theme.color.white,
	labelStrokeTransparency = 0,
}

--=============================================================== shop / pets

Theme.shopPanel = {
	size = UDim2.new(0, 380, 0, 420),
	position = UDim2.new(0.5, 0, 0.5, 0),
	padding = 0,
	closeCorner = 8,
	listTopOffset = 46,
	scrollBarColor = Theme.itemList.goldScrollBar,
}

Theme.petsPanel = {
	size = UDim2.new(0, 320, 0, 260),
	position = UDim2.new(0.5, 0, 0.5, 0),
	padding = 0,
	rowSpacing = 0,
	closeCorner = 8,

	rowHeight = 44,
	labelSize = UDim2.new(0, 150, 1, 0),
	labelFont = Theme.font.body,
	labelTextSize = 18,
	labelColor = Theme.color.white,
	labelStrokeTransparency = 0.4000000059604645,

	pillSize = UDim2.new(0, 70, 0, 28),
	pillPosition = UDim2.new(1, -70, 0.5, -14),
	pillBackground = Theme.color.mutedGrey,
	pillCorner = 8,
	pillFont = Theme.font.body,
	pillTextSize = 14,
	pillTextColor = Theme.color.white,
	pillStrokeTransparency = 0,
}

-- Placeholder panel with the same chrome as PetsPanel: centred, flat title
-- bar, empty content area for a later pass to fill.
Theme.inventoryPanel = {
	size = UDim2.new(0, 320, 0, 260),
	position = UDim2.new(0.5, 0, 0.5, 0),
	padding = 0,
	rowSpacing = 0,
	closeCorner = 8,
}

--=============================================================== cash pack panel

Theme.cashPackPanel = {
	size = UDim2.new(0, 380, 0, 420),
	position = UDim2.new(0.5, 0, 0.5, 0),
	background = Color3.fromRGB(10, 10, 10),
	cornerRadius = 20,
	strokeThickness = 3,
	strokeTransparency = 0,
	strokeColor = Color3.fromRGB(70, 200, 90),
	padding = 14,

	titleBarHeight = 44,
	badgeSize = UDim2.new(0, 40, 0, 40),
	badgePosition = UDim2.new(0, 0, 0.5, 0),
	badgeBackground = Theme.color.white,
	badgeCorner = UDim.new(0.5, 0),
	badgeTextColor = Color3.fromRGB(20, 20, 20),
	badgeFont = Theme.font.heading,
	badgeTextSize = 22,

	titleSize = UDim2.new(1, -94, 1, 0),
	titlePosition = UDim2.new(0, 50, 0, 0),
	titleColor = Theme.color.white,
	titleFont = Theme.font.heading,
	titleTextSize = 26,
	titleStrokeTransparency = 0,

	closeSize = UDim2.new(0, 40, 0, 40),
	closePosition = UDim2.new(1, 0, 0.5, 0),
	closeColor = Color3.fromRGB(220, 60, 60),
	closeCorner = 10,
	closeFont = Theme.font.heading,
	closeTextSize = 20,
	closeTextColor = Theme.color.white,
	closeStrokeTransparency = 0,

	listTopOffset = 54,
	scrollBarColor = Theme.itemList.greenScrollBar,
}

--=============================================================== middle shops

Theme.middleShopPanel = {
	size = UDim2.new(0, 380, 0, 420),
	position = UDim2.new(0.5, 0, 0.5, 0),
	background = Color3.fromRGB(28, 30, 34),
	closeCorner = 10,
	listTopOffset = 46,
	scrollBarColor = Theme.itemList.goldScrollBar,
}

--=============================================================== tooltip

Theme.tooltip = {
	size = UDim2.new(0, 0, 0, 28),
	background = Color3.fromRGB(20, 20, 22),
	cornerRadius = 6,
	strokeThickness = 1,
	strokeTransparency = 0.30000001192092896,
	strokeColor = Color3.fromRGB(90, 92, 98),
	paddingX = 10,
	font = Theme.font.body,
	textSize = 14,
	textColor = Theme.color.white,
}

--=============================================================== shop rows

-- Used by ShopRowBuilder for the main Shop and every MiddleShops panel.
Theme.row = {
	height = 84,
	background = Color3.fromRGB(24, 22, 18),
	cornerRadius = 14,
	strokeColor = Color3.fromRGB(200, 160, 60),
	strokeThickness = 1.5,
	strokeTransparency = 0.3,

	iconPosition = UDim2.new(0, 10, 0.5, 0),
	iconSize = UDim2.new(0, 60, 0, 60),
	iconCorner = UDim.new(0.5, 0),
	iconFont = Theme.font.heading,
	iconTextSize = 16,
	iconTextColor = Theme.color.white,
	iconStrokeColor = Theme.color.textStroke,
	iconStrokeTransparency = 0,

	namePosition = UDim2.new(0, 84, 0, 10),
	nameSize = UDim2.new(0, 150, 0, 24),
	nameFont = Theme.font.heading,
	nameTextSize = 18,
	nameColor = Theme.color.gold,
	nameStrokeColor = Theme.color.textStroke,
	nameStrokeTransparency = 0,

	pricePosition = UDim2.new(0, 84, 0, 38),
	priceSize = UDim2.new(0, 150, 0, 22),
	priceFont = Theme.font.body,
	priceTextSize = 16,
	priceColor = Theme.color.white,
	priceStrokeTransparency = 0.4,

	buyPosition = UDim2.new(1, -10, 0.5, 0),
	buySize = UDim2.new(0, 80, 0, 40),
	buyColor = Color3.fromRGB(70, 190, 80),
	buyCorner = 10,
	buyFont = Theme.font.heading,
	buyTextSize = 18,
	buyTextColor = Theme.color.white,
	buyStrokeColor = Theme.color.textStroke,
	buyStrokeTransparency = 0,
	buyGradientRotation = 90,
	buyGradient = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 230, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 160, 60)),
	}),
}

-- Cash-pack rows: same geometry as Theme.row, green palette, plus a discount
-- badge and a bottom-anchored Buy button.
Theme.cashPackRow = {
	height = 84,
	background = Color3.fromRGB(18, 22, 18),
	cornerRadius = 14,
	strokeColor = Color3.fromRGB(70, 200, 90),
	strokeThickness = 1.5,
	strokeTransparency = 0.2,

	-- Centred in the iconImageSize slot below, so the fallback badge sits where
	-- the art would have been.
	iconPosition = UDim2.new(0, 22, 0.5, 0),
	iconSize = UDim2.new(0, 60, 0, 60),

	-- Cash-pile art, used instead of the badge when a pack has iconAssetId.
	-- One slot and one zoom for every tier: the art itself grows from 5K to
	-- 5M, so a per-tier scale here would double the progression.
	iconImagePosition = UDim2.new(0, 4, 0.5, 0),
	iconImageSize = UDim2.new(0, 96, 0, 72),
	-- Fraction of the source image the slot shows. The piles are drawn small
	-- and centred inside a lot of transparent padding; at Fit the whole square
	-- would letterbox into the slot and leave even the 5M pile under 40px
	-- wide. The controller clips to this window instead, which zooms every
	-- tier by the same factor. Measured from the art: the widest pile spans
	-- 330/512 across and the tallest 242/512 down, both centred, so this
	-- window holds all eight with a couple of pixels to spare.
	iconImageCrop = Vector2.new(336 / 512, 252 / 512),

	iconCorner = UDim.new(0.5, 0),
	iconFont = Theme.font.heading,
	iconTextSize = 16,
	iconTextColor = Theme.color.white,
	iconStrokeColor = Theme.color.textStroke,
	iconStrokeTransparency = 0,

	namePosition = UDim2.new(0, 106, 0, 10),
	nameSize = UDim2.new(0, 128, 0, 24),
	nameFont = Theme.font.heading,
	nameTextSize = 18,
	nameColor = Color3.fromRGB(90, 220, 110),
	nameStrokeColor = Theme.color.textStroke,
	nameStrokeTransparency = 0,

	pricePosition = UDim2.new(0, 106, 0, 38),
	priceSize = UDim2.new(0, 128, 0, 22),
	priceFont = Theme.font.body,
	priceTextSize = 16,
	priceColor = Theme.color.white,
	priceStrokeTransparency = 0.4,

	discountPosition = UDim2.new(1, -10, 0, 8),
	discountSize = UDim2.new(0, 90, 0, 16),
	discountFont = Theme.font.heading,
	discountTextSize = 13,
	discountColor = Color3.fromRGB(255, 170, 40),
	discountStrokeColor = Theme.color.textStroke,
	discountStrokeTransparency = 0.3,

	buyPosition = UDim2.new(1, -10, 1, -12),
	buySize = UDim2.new(0, 90, 0, 40),
	buyColor = Color3.fromRGB(70, 190, 80),
	buyCorner = 10,
	buyFont = Theme.font.heading,
	buyTextSize = 18,
	buyTextColor = Theme.color.white,
	buyStrokeColor = Theme.color.textStroke,
	buyStrokeTransparency = 0,
	buyGradientRotation = 90,
	buyGradient = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 230, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 160, 60)),
	}),
}

Theme.hover = {
	buyButton = { scale = 1.1, lift = 3 },
}

return Theme
