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
	-- The cash banner and the slate row buttons under it share this vertical
	-- gradient, and the lattice texture over it, so the two read as one HUD.
	hudFillTop = Color3.fromRGB(84, 94, 108),
	hudFillBottom = Color3.fromRGB(52, 60, 72),
	-- Near-black outline and 3D lip around the row buttons.
	hudOutline = Color3.fromRGB(14, 17, 22),
	closeRed = Color3.fromRGB(217, 77, 77),

	cashGreen = Color3.fromRGB(107, 242, 140),
	accentGreen = Color3.fromRGB(71, 199, 107),

	-- Gems are violet. Green still means "buy / add" on every plus button,
	-- including the gem one, so these are never used for those.
	gemLight = Color3.fromHex("#C9A4FF"),
	gemDeep = Color3.fromHex("#8B4FE8"),
	gemOutline = Color3.fromHex("#3D1A6B"),
	gold = Color3.fromRGB(255, 205, 60),
	mutedGrey = Color3.fromRGB(89, 92, 102),
}

Theme.font = {
	heading = Enum.Font.GothamBlack,
	body = Enum.Font.GothamBold,
	-- Not bold. Montserrat by name: this Studio build ships no Gotham files at
	-- all, only Montserrat in Gotham's four weights, so the Gotham enums are
	-- almost certainly drawn with it and this names the face actually shown.
	regular = Enum.Font.Montserrat,
	-- Not bold either, but rounded at every stroke end, so it reads playful
	-- where Gotham reads plain.
	rounded = Enum.Font.Nunito,
}

Theme.asset = {
	teleportIcon = "rbxassetid://79152891526373",
	inventoryIcon = "rbxassetid://71866888766572",
	shopIcon = "rbxassetid://125276496385783",
	petsIcon = "rbxassetid://82132351525305",
	settingsIcon = "rbxassetid://86564279252401",
	-- 256x256 tileable diamond lattice. White RGB with the pattern in the
	-- alpha channel, so ImageColor3 tints it and ImageTransparency sets its
	-- strength.
	latticeTile = "rbxassetid://110211627238517",
	-- 256x256 tileable diagonal stripes. White RGB with the pattern in the
	-- alpha channel, so ImageColor3 decides what colour the stripes come out.
	stripePattern = "rbxassetid://84907664693950",
	-- The gem icon beside the HUD's gem amount.
	gemIcon = "rbxassetid://139394514878907",
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
	-- Room for each row's UIStroke, which draws outside the row. 2 covers the
	-- thickest row stroke in use. paddingRight is larger because it also has to
	-- clear the scrollbar.
	paddingLeft = 2,
	paddingTop = 2,
	paddingBottom = 2,
	goldScrollBar = Color3.fromRGB(210, 165, 60),
	greenScrollBar = Color3.fromRGB(80, 210, 100),
}

--=============================================================== HUD surface

-- The slate panel look shared by the cash panel and the richest banner, so
-- the two read as cut from the same sheet and cannot drift apart. Applied by
-- MainHUDBuilder's slateSurface; nothing else should restate these values.
Theme.hudSurface = {
	-- White underneath, because UIGradient multiplies against BackgroundColor3;
	-- the gradient alone sets the colour.
	gradientRotation = 90,
	gradient = ColorSequence.new(Theme.color.hudFillTop, Theme.color.hudFillBottom),
	strokeColor = Color3.fromRGB(176, 190, 208),
	strokeThickness = 2,
	strokeTransparency = 0,
	-- The lattice over the gradient, black at 30% strength.
	tileSize = UDim2.fromOffset(86, 86),
	tileColor = Color3.fromRGB(0, 0, 0),
	tileTransparency = 0.7,
	-- The outline on text set over the surface. GothamBlack is already
	-- Gotham's heaviest weight, so this UIStroke is where the extra heft comes
	-- from; it replaces the 1px legacy TextStroke. The slab buttons' near-black.
	textOutlineThickness = 2,
	textOutlineColor = Theme.color.hudOutline,
}

--=============================================================== cash HUD

-- The currency bar (CashPanel) holds two rows stacked by a UIListLayout: gems
-- on top, cash below. The cash row keeps the bar's original 36px content
-- height. The gem row, its text and its plus button are GEM_ROW_SCALE of the
-- cash row's, so cash stays the dominant row. The bar's height is derived from
-- the rows; the button row and the group follow it.
local CASH_PANEL_PADDING = 8
local CASH_ROW_HEIGHT = 36
local GEM_ROW_SCALE = 0.78
local GEM_ROW_HEIGHT = math.round(CASH_ROW_HEIGHT * GEM_ROW_SCALE)
-- Wide enough that the cash plus's hover lift doesn't reach the gem plus.
local CURRENCY_ROW_GAP = 6
local CASH_PANEL_Y = 56
local CASH_PANEL_HEIGHT = 2 * CASH_PANEL_PADDING + GEM_ROW_HEIGHT + CURRENCY_ROW_GAP + CASH_ROW_HEIGHT
local BUTTON_ROW_GAP = 8
local BUTTON_ROW_HEIGHT = 44
local BUTTON_ROW_Y = CASH_PANEL_Y + CASH_PANEL_HEIGHT + BUTTON_ROW_GAP

local CASH_LABEL_TEXT_SIZE = 24
local PLUS_SIZE = 32
-- The cash plus sits this far in from the bar's right edge.
local PLUS_RIGHT_INSET = 8
local GEM_ICON_SIZE = 24
local GEM_ICON_X = 4
local GEM_LABEL_GAP = 4
local GEM_LABEL_X = GEM_ICON_X + GEM_ICON_SIZE + GEM_LABEL_GAP

Theme.cashHud = {
	-- MainHUDBuilder anchors the group at its bottom-left corner, so a taller
	-- bar grows the group upward and the button row keeps its place on screen.
	-- Y is where the group's bottom edge has always been (-148 + 160).
	groupSize = UDim2.new(0, 190, 0, BUTTON_ROW_Y + BUTTON_ROW_HEIGHT),
	groupPosition = UDim2.new(-0.013, 20, 0.513, 12),

	cashPanelSize = UDim2.new(0, 190, 0, CASH_PANEL_HEIGHT),
	cashPanelPosition = UDim2.new(0, 0, 0, CASH_PANEL_Y),
	-- Gradient, outline and texture come from Theme.hudSurface.
	cashPanelCorner = 16,
	cashPanelPadding = CASH_PANEL_PADDING,

	currencyRowGap = CURRENCY_ROW_GAP,
	cashRowHeight = CASH_ROW_HEIGHT,
	gemRowHeight = GEM_ROW_HEIGHT,

	-- Positions in the cash row are unchanged from when the row was the whole
	-- bar: the row is exactly the old padded content area. The label reaches
	-- to 4px short of the plus button (it starts ~4px in), and MainHUDBuilder
	-- caps its text at cashLabelTextSize and shrinks it only if a value would
	-- otherwise run under the button.
	cashLabelSize = UDim2.new(0, 126, 0, CASH_ROW_HEIGHT),
	cashLabelPosition = UDim2.new(-0.2744101583957672, 52, 0.5, 0),
	cashLabelColor = Theme.color.cashGreen,
	cashLabelFont = Theme.font.heading,
	-- Outlined with Theme.hudSurface's text outline.
	cashLabelTextSize = CASH_LABEL_TEXT_SIZE,

	-- The gem row: icon, amount, then its own green plus. The amount gets the
	-- cash number's font and outline in gem violet.
	gemRowScale = GEM_ROW_SCALE,
	gemIconSize = UDim2.fromOffset(GEM_ICON_SIZE, GEM_ICON_SIZE),
	gemIconPosition = UDim2.new(0, GEM_ICON_X, 0.5, 0),
	gemLabelPosition = UDim2.new(0, GEM_LABEL_X, 0.5, 0),
	gemLabelColor = Theme.color.gemLight,
	gemLabelFont = Theme.font.heading,
	gemLabelTextSize = math.round(CASH_LABEL_TEXT_SIZE * GEM_ROW_SCALE),

	-- The gem plus follows the gem number: it sits this far after the digits
	-- and moves as the number gets longer, so it hugs the amount. The cash plus
	-- stays put at the bar's right edge, so the two buttons are staggered on
	-- purpose, not aligned. The gem plus never goes past the cash plus.
	gemPlusGap = 6,

	-- The plus button is extruded: a lit face over a darker base of the same
	-- size, plusDepth px lower, both inside a PlusWrapper tall enough to hold
	-- the two. plusPosition places the wrapper, so face and base together are
	-- centred in the row rather than the face alone. The gem plus is the same
	-- button scaled by gemRowScale.
	plusSize = UDim2.new(0, PLUS_SIZE, 0, PLUS_SIZE),
	plusPosition = UDim2.new(1, -PLUS_RIGHT_INSET, 0.5, 0),
	plusDepth = 6,
	plusCorner = 8,
	plusFaceGradient = ColorSequence.new(Color3.fromRGB(126, 232, 136), Color3.fromRGB(58, 178, 78)),
	plusBaseGradient = ColorSequence.new(Color3.fromRGB(34, 118, 54), Color3.fromRGB(28, 98, 46)),
	plusGradientRotation = 90,
	plusStrokeColor = Color3.fromRGB(206, 248, 206),
	plusStrokeThickness = 2,
	-- Smaller than the panel's 86 so the pattern does not read as one huge
	-- cell on a 32px button.
	plusTileSize = UDim2.fromOffset(48, 48),
	plusTileTransparency = 0.74,
	plusFont = Theme.font.heading,
	plusTextColor = Theme.color.white,
	-- Heavier for the same reason as the cash number, and in the same outline.
	plusTextOutlineThickness = 2,
	plusTextOutlineColor = Theme.color.hudOutline,

	-- The house button is built from the same slab as the row below, at the
	-- same rowButtonSize, so only its placement, face and ring live here. Its
	-- vestigial text properties went when it took the shared look: Text has
	-- been "" since the icon landed, so none of them drew anything.
	--
	-- Y as a pixel offset rather than the original scale (0.01875 of the
	-- 160px group, i.e. 3px), so the house button stays put if the group's
	-- height ever changes.
	teleportPosition = UDim2.new(0.15263158082962036, 0, 0, 3),
	-- The one button that fires an action rather than opening a panel, so it
	-- keeps the green face it has always worn while the row below stays slate.
	-- Both stops are the original gradient, unchanged.
	teleportGradientRotation = 90,
	teleportGradient = ColorSequence.new(Color3.fromRGB(121, 226, 127), Color3.fromRGB(50, 132, 65)),
	-- The face's own highlight green -- lighter than even its top stop
	-- (121, 226, 127), so it reads as a lit rim over the whole gradient, and
	-- the same hue, so it frames the green instead of cutting across it. This
	-- is the stroke colour the button wore before the slab, restored.
	teleportRingColor = Color3.fromRGB(181, 255, 144),

	-- ButtonRow: the four panel-opening buttons in one row under the cash
	-- panel, 44px squares (the house button's size) 4px apart -- 4 * 44 + 3 * 4
	-- = 188, centred under the 190px panel. The row itself draws nothing.
	-- Its Y follows the bar's height, so the row stays BUTTON_ROW_GAP below it.
	rowSize = UDim2.new(0, 188, 0, BUTTON_ROW_HEIGHT),
	rowPosition = UDim2.new(0, 1, 0, BUTTON_ROW_Y),

	rowButtonSize = UDim2.new(0, 44, 0, 44),
	-- One button plus one gap.
	rowButtonStep = 48,
	-- 12 on the earlier 56px buttons; 9 keeps the same rounded-square shape.
	rowButtonCorner = 9,
	-- Each button is a slab of the outline colour with a lighter face on top.
	-- The face is inset by rowButtonOutline on the top and sides but by
	-- rowButtonDepth along the bottom, so the slab shows as a thin dark
	-- outline with a heavier lip underneath -- the same extruded "3D" look
	-- as the shop headers and Buy buttons, at button scale.
	rowButtonOutlineColor = Theme.color.hudOutline,
	rowButtonOutline = 2,
	rowButtonDepth = 5,
	-- Every slate face shares the cash banner's gradient and lattice; only the
	-- rings tell them apart. The plus button's 48px tile rather than the
	-- panel's 86, for the same reason: these faces are about as small.
	rowButtonGradientRotation = 90,
	rowButtonGradient = ColorSequence.new(Theme.color.hudFillTop, Theme.color.hudFillBottom),
	rowButtonTileSize = UDim2.fromOffset(48, 48),
	rowButtonTileTransparency = 0.7,
	-- 2, matching the outline under it and the cash banner's and plus button's
	-- rims, so every edge in the HUD carries the same weight.
	rowButtonRingThickness = 2,
	-- Shop's ring is white because its rainbow gradient multiplies against it.
	shopRingColor = Theme.color.white,
	-- Cyan against the orange paw.
	petsRingColor = Color3.fromRGB(0, 147, 198),
	-- Gold, after the bag's brass clasp.
	inventoryRingColor = Color3.fromRGB(214, 170, 36),
	-- The cash panel's own outline grey. Quiet by design: it is the only ring
	-- that does not name a colour of its icon, and the gear is the one button
	-- here that is not a place to spend money.
	settingsRingColor = Theme.color.strokeGrey,

	-- The bag art fills less of its 512 canvas than the others (356x307), so
	-- at 1:1 it reads visibly smaller beside the shop, paw and gear. At 1.15
	-- it lands near 35x30 in a 44px button, in line with them.
	inventoryIconScale = 1.15,

	-- ShopButton's spinning rainbow outline. Rotation is tweened 0 -> 360 once
	-- per period, on a loop.
	shopRainbow = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 200, 0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 220, 255)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 100, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(220, 60, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
	}),
	shopRainbowPeriod = 3,

	-- "SALE!" tilted over ShopButton's top-left corner. Centred 10px in and 2px
	-- down from that corner, so it overhangs the button by about 10px left and
	-- 7px up, and stops short of the storefront's door.
	saleBadgeSize = UDim2.new(0, 40, 0, 18),
	saleBadgePosition = UDim2.new(0, 10, 0, 2),
	saleBadgeRotation = -12,
	saleBadgeColor = Color3.fromRGB(255, 80, 60),
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

-- The banner wears Theme.hudSurface, the cash panel's slate, so the two match
-- in colour -- but see-through, where the cash panel is solid.
-- Width is set in code to fit the text (see MainHUDBuilder), so size holds
-- only the height.
local RICHEST_BANNER_HEIGHT = 30
Theme.richestBanner = {
	size = UDim2.new(0, 0, 0, RICHEST_BANNER_HEIGHT),
	position = UDim2.new(0.5, 0, -0.08698859065771103, 12),
	-- The cash panel's corner scaled to this height (16 at 52px -> 9 at
	-- 30px), so the two share a shape. 52 is a single row (cash row plus
	-- padding), not the whole bar: the bar grew taller when the gem row was
	-- added, and that must not change the banner.
	cornerRadius = math.round(
		Theme.cashHud.cashPanelCorner * RICHEST_BANNER_HEIGHT
			/ (Theme.cashHud.cashRowHeight + 2 * Theme.cashHud.cashPanelPadding)
	),
	paddingX = 14,
	-- Past this fraction of the screen's width the banner stops growing and
	-- the text shrinks (wrapping onto two lines if that reads larger), so a
	-- long name and a 9-figure value still fit a phone held upright.
	maxWidthScale = 0.9,
	-- Measured off the reference screenshot, whose banner shows the sky at
	-- roughly 60%. The outline and texture fade by the same amount, so the
	-- banner thins out as a whole rather than leaving them floating solid.
	surfaceTransparency = 0.6,

	labelColor = Theme.color.white,
	-- Theme.font.rounded (Nunito) for something more playful.
	labelFont = Theme.font.regular,
	-- The classic thin edge, not the cash number's 2px: that outline exists to
	-- add weight, and this text is meant to read light.
	labelOutlineThickness = 1,
	-- The size the text is drawn at whenever the banner has room for it. 18 in
	-- a 30px bar fills it more than 20 did in 40, closer to the reference.
	labelTextSize = 18,
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

-- The header shared by all four shop panels (Shop, Ball, Creature, Gear). One
-- table, referenced from each panel below, so they cannot drift apart. Its key
-- names match the ones Theme.cashPackPanel uses, because MainHUDBuilder's
-- texturedTitleBar reads the same shape from both.
--
-- Settings and Pets deliberately have no header config, so they keep the flat
-- transparent bar from Theme.titleBar.
Theme.shopHeader = {
	-- Taller than Theme.titleBar's 36, so the radius-20 corners -- which have to
	-- match the panel's own to sit flush against them -- do not dominate a short
	-- bar. The cash panel's 44 exactly: with the same bleed below, both banners
	-- now come out 58px tall, and the X's hover pop (1.08 scale, 4px lift) has
	-- the bleed to rise into. Each panel's listTopOffset moves with this value.
	titleBarHeight = 44,
	-- Matches the panels' padding below, exactly as the cash panel's does: the
	-- banner escapes the padding to reach the panel's own edges, while its
	-- contents keep that inset and so line up with the rows underneath.
	titleBarBleed = 14,

	-- Grey for now, pending a colour decision. Everything but the two gradient
	-- stops and depthColor is the cash banner's recipe unchanged. A dark slate
	-- rather than the light grey this started as: light grey sat too close to
	-- the white outline and the two fought each other.
	titleBarSurface = {
		image = Theme.asset.stripePattern,
		cornerRadius = Theme.panel.cornerRadius,
		gradientRotation = 90,
		gradientTop = Color3.fromRGB(86, 92, 104),
		gradientBottom = Color3.fromRGB(54, 60, 70),
		strokeColor = Color3.fromRGB(232, 240, 236),
		strokeThickness = 2,
		tileSize = UDim2.fromOffset(72, 72),
		patternColor = Color3.fromRGB(0, 0, 0),
		patternTransparency = 0.8,
		depth = 6,
		depthColor = Color3.fromRGB(31, 34, 41),
		-- Not clipped, for the same reason the cash banner is not: the X grows
		-- past the bar on hover and clipping would shave the pop.
		clipsDescendants = false,
	},

	titleSize = UDim2.new(1, -48, 1, 0),
	titlePosition = UDim2.new(0, 0, 0, 0),
	titleColor = Theme.color.white,
	titleFont = Theme.font.heading,
	titleTextSize = 22,
	titleStrokeTransparency = 0,

	closeSize = UDim2.new(0, 32, 0, 32),
	closePosition = UDim2.new(1, 0, 0.5, 0),
	closeColor = Theme.color.closeRed,
	closeCorner = 9,
	closeFont = Theme.font.heading,
	closeTextSize = 18,
	closeTextColor = Theme.color.white,
	closeStrokeTransparency = 0,

	-- The cash panel's X exactly, with the radius and tile dropped to suit a
	-- 32px button rather than its 40px one.
	closeSurface = {
		image = Theme.asset.stripePattern,
		cornerRadius = 9,
		gradientRotation = 90,
		gradientTop = Color3.fromRGB(240, 105, 105),
		gradientBottom = Color3.fromRGB(183, 45, 45),
		strokeColor = Color3.fromRGB(232, 240, 236),
		strokeThickness = 2,
		tileSize = UDim2.fromOffset(32, 32),
		patternColor = Color3.fromRGB(0, 0, 0),
		patternTransparency = 0.8,
		depth = 4,
		depthColor = Color3.fromRGB(118, 26, 26),
		clipsDescendants = true,
		captionText = "X",
	},
}

Theme.shopPanel = {
	size = UDim2.new(0, 380, 0, 420),
	position = UDim2.new(0.5, 0, 0.5, 0),
	-- Was 0. Insets the rows from the panel edge the way the cash panel's does,
	-- and gives Theme.shopHeader's bleed the gap it cancels at the top.
	padding = 14,
	closeCorner = 8,

	-- The cash panel's outline, so the white edges inside have a matching one
	-- around the panel. Overrides Theme.panel's grey for this panel only.
	strokeColor = Color3.fromRGB(232, 240, 236),
	strokeThickness = 2,
	strokeTransparency = 0,
	-- 54 rather than 46: titleBarHeight 44 plus the same 10px gap the flat 36px
	-- bar left behind it. The cash panel's offset exactly.
	listTopOffset = 54,
	scrollBarColor = Theme.itemList.goldScrollBar,
	header = Theme.shopHeader,
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

-- The purchase panel: two tabs (Cash, Gems) above one body. The panel Frame
-- itself is a transparent container -- it keeps the size and position, and is
-- what PanelManager shows and hides -- holding the body, the tabs and the X.
--
-- The body is neutral slate in both tabs; only the active tab and the cards
-- carry a currency colour. The active tab sits above the body, clipped at the
-- body's top edge, so it joins the body with square bottom corners and covers
-- the body's outline where they meet. The inactive tab is shorter, darker and
-- drawn behind the body, so the body's edge runs in front of it.
local TAB_STRIP_HEIGHT = 44
local TAB_CORNER_RADIUS = 12

Theme.cashPackPanel = {
	size = UDim2.new(0, 380, 0, 420),
	position = UDim2.new(0.5, 0, 0.5, 0),
	background = Theme.color.panelDark,
	cornerRadius = 20,
	strokeThickness = 2,
	strokeTransparency = 0,
	strokeColor = Color3.fromRGB(232, 240, 236),
	padding = 14,

	-- Room above the body for the tabs and the X. The body takes the rest.
	tabStripHeight = TAB_STRIP_HEIGHT,
	-- The first tab starts where the body's rounded top-left corner ends.
	tabStartX = 20,
	tabWidth = 110,
	tabGap = 6,
	-- Visible heights above the body. The inactive tab is shorter, so it sits
	-- lower and reads as recessed.
	tabActiveHeight = 40,
	tabInactiveHeight = 32,
	tabCornerRadius = TAB_CORNER_RADIUS,
	tabFont = Theme.font.heading,
	tabTextSize = 20,
	tabTextColor = Theme.color.white,
	tabInactiveTextColor = Color3.fromRGB(140, 146, 158),
	tabTextStrokeTransparency = 0,

	-- Active-tab surfaces. Flat (no depth): an extruded lip would draw a dark
	-- line right along the edge the tab shares with the body. The cash one is
	-- the old title bar's green stripes.
	cashTabSurface = {
		image = Theme.asset.stripePattern,
		cornerRadius = TAB_CORNER_RADIUS,
		gradientRotation = 90,
		gradientTop = Color3.fromRGB(142, 238, 110),
		gradientBottom = Color3.fromRGB(58, 183, 62),
		strokeColor = Color3.fromRGB(232, 240, 236),
		strokeThickness = 2,
		tileSize = UDim2.fromOffset(72, 72),
		patternColor = Color3.fromRGB(0, 0, 0),
		patternTransparency = 0.8,
	},
	gemTabSurface = {
		image = Theme.asset.stripePattern,
		cornerRadius = TAB_CORNER_RADIUS,
		gradientRotation = 90,
		gradientTop = Theme.color.gemLight,
		gradientBottom = Theme.color.gemDeep,
		strokeColor = Color3.fromRGB(232, 240, 236),
		strokeThickness = 2,
		tileSize = UDim2.fromOffset(72, 72),
		patternColor = Color3.fromRGB(0, 0, 0),
		patternTransparency = 0.8,
	},
	-- Either tab while inactive: darker than the body, with the quieter grey
	-- outline, and no currency colour.
	inactiveTabSurface = {
		image = Theme.asset.stripePattern,
		cornerRadius = TAB_CORNER_RADIUS,
		gradientRotation = 90,
		gradientTop = Color3.fromRGB(24, 27, 32),
		gradientBottom = Color3.fromRGB(15, 17, 21),
		strokeColor = Theme.color.panelStroke,
		strokeThickness = 2,
		tileSize = UDim2.fromOffset(72, 72),
		patternColor = Color3.fromRGB(0, 0, 0),
		patternTransparency = 0.9,
	},

	closeSize = UDim2.new(0, 40, 0, 40),
	-- Right end of the tab strip, centred on its top 40px so it stays 4px
	-- clear of the body.
	closePosition = UDim2.new(1, 0, 0, 20),
	closeColor = Color3.fromRGB(220, 60, 60),
	closeCorner = 10,
	closeFont = Theme.font.heading,
	closeTextSize = 20,
	closeTextColor = Theme.color.white,
	closeStrokeTransparency = 0,

	-- The X button's stripes. No gradient was specified for it, so these two
	-- reds are DERIVED from the existing closeColor (220,60,60) -- a lighter
	-- top and darker bottom mirroring how the green gradients are built. Tune
	-- freely; nothing else depends on them. tileSize is likewise scaled down
	-- for a 40x40 button rather than copied from the 90x40 Buy button.
	--
	-- Clipping is safe here: this button's only children are the pattern and
	-- caption, both fromScale(1,1), so they grow with it during the hover
	-- tween and never overflow.
	closeSurface = {
		image = Theme.asset.stripePattern,
		cornerRadius = 10,
		gradientRotation = 90,
		gradientTop = Color3.fromRGB(240, 105, 105),
		gradientBottom = Color3.fromRGB(183, 45, 45),
		strokeColor = Color3.fromRGB(232, 240, 236),
		strokeThickness = 2,
		tileSize = UDim2.fromOffset(40, 40),
		patternColor = Color3.fromRGB(0, 0, 0),
		patternTransparency = 0.8,

		-- A shallow extruded lip, derived from gradientBottom (183,45,45) the
		-- same way the green surfaces derive theirs.
		depth = 4,
		depthColor = Color3.fromRGB(118, 26, 26),

		clipsDescendants = true,
		captionText = "X",
	},

	scrollBarColor = Theme.itemList.greenScrollBar,
	gemScrollBarColor = Theme.color.gemDeep,
}

--=============================================================== middle shops

Theme.middleShopPanel = {
	size = UDim2.new(0, 380, 0, 420),
	position = UDim2.new(0.5, 0, 0.5, 0),
	background = Color3.fromRGB(28, 30, 34),
	closeCorner = 10,
	-- Both match shopPanel's; see the notes there.
	padding = 14,
	strokeColor = Color3.fromRGB(232, 240, 236),
	strokeThickness = 2,
	strokeTransparency = 0,
	-- Moves with shopPanel's; see the note there.
	listTopOffset = 54,
	scrollBarColor = Theme.itemList.goldScrollBar,
	header = Theme.shopHeader,
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

	-- As with the cash panel's buySurface: present only in this theme, so the
	-- production rows keep their plain gradient, their own "BUY" text and no
	-- pattern layer. The two gradient stops are buyGradient's below, copied
	-- unchanged -- the texture and the extruded lip are the only additions, the
	-- green is exactly the green these buttons already had.
	buySurface = {
		image = Theme.asset.stripePattern,
		cornerRadius = 10,
		gradientRotation = 90,
		gradientTop = Color3.fromRGB(140, 230, 130),
		gradientBottom = Color3.fromRGB(50, 160, 60),
		strokeColor = Color3.fromRGB(232, 240, 236),
		strokeThickness = 2,
		tileSize = UDim2.fromOffset(56, 56),
		patternColor = Color3.fromRGB(0, 0, 0),
		patternTransparency = 0.8,
		depth = 4,
		depthColor = Color3.fromRGB(26, 96, 32),
		clipsDescendants = true,
		-- Uppercase, matching the text these buttons render today.
		captionText = "BUY",
	},

	buyPosition = UDim2.new(1, -10, 0.5, 0),
	buySize = UDim2.new(0, 80, 0, 40),
	buyColor = Color3.fromRGB(70, 190, 80),
	buyCorner = 10,
	buyFont = Theme.font.heading,
	buyTextSize = 18,
	-- A pale mint rather than flat white, so the word reads as one more shade
	-- of the button's own green. Pitched above gradientTop (140,230,130) in
	-- brightness, which together with the black buyStrokeColor is what keeps it
	-- legible over the dark end of the gradient. One value to tune.
	buyTextColor = Color3.fromRGB(210, 255, 190),
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
	strokeColor = Color3.fromRGB(96, 105, 118),
	strokeThickness = 2,
	-- Transparency was not specified for the new stroke; keeping the existing
	-- 0.2 is what makes it read as subtle rather than a hard outline.
	strokeTransparency = 0.2,

	-- As with titleBarSurface: present only here, so production's Buy buttons
	-- keep their plain gradient, their own "BUY" text and no pattern layer.
	buySurface = {
		image = Theme.asset.stripePattern,
		cornerRadius = 11,
		gradientRotation = 90,
		gradientTop = Color3.fromRGB(158, 243, 120),
		gradientBottom = Color3.fromRGB(70, 196, 68),
		strokeColor = Color3.fromRGB(232, 240, 236),
		strokeThickness = 2,
		tileSize = UDim2.fromOffset(56, 56),
		patternColor = Color3.fromRGB(0, 0, 0),
		patternTransparency = 0.8,

		-- Same extrusion as the banner and the X, derived from this surface's
		-- own gradientBottom (70,196,68). 4px rather than the banner's 6: these
		-- are 40px tall, so a deeper lip would crowd the caption.
		depth = 4,
		depthColor = Color3.fromRGB(36, 116, 36),

		-- No downside here: the face and the caption are both full-width scale,
		-- so they grow with the button during the hover tween and never
		-- overflow.
		clipsDescendants = true,
		-- The pattern is a child, and children always render above their
		-- parent, so it would cover the button's own Text. The caption goes in
		-- a sibling TextLabel with a higher ZIndex instead.
		captionText = "Buy",
	},

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

	-- The promo line above the Buy button. A card style without discountText
	-- shows none.
	discountText = "50% OFF!",
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

-- Gem cards: the cash card's layout, with gem violet in place of the green
-- accents. The Buy button stays green on purpose (green means "buy"), and so
-- is shared with the cash card. Bundles have no per-item colour, so the
-- fallback badge takes iconBackground. No promo line.
Theme.gemPackRow = table.clone(Theme.cashPackRow)
Theme.gemPackRow.background = Color3.fromRGB(24, 18, 34)
Theme.gemPackRow.strokeColor = Theme.color.gemOutline
Theme.gemPackRow.strokeTransparency = 0
Theme.gemPackRow.nameColor = Theme.color.gemLight
Theme.gemPackRow.iconBackground = Theme.color.gemDeep
Theme.gemPackRow.discountText = nil

Theme.hover = {
	buyButton = { scale = 1.1, lift = 3 },
}

return Theme
