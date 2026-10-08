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

Theme.cashHud = {
	groupSize = UDim2.new(0, 190, 0, 160),
	groupPosition = UDim2.new(-0.013, 20, 0.513, -148),

	cashPanelSize = UDim2.new(0, 190, 0, 52),
	cashPanelPosition = UDim2.new(0, 0, 0, 56),
	-- Gradient, outline and texture come from Theme.hudSurface.
	cashPanelCorner = 16,
	cashPanelPadding = 8,

	cashLabelSize = UDim2.new(0, 92, 0, 36),
	cashLabelPosition = UDim2.new(-0.2744101583957672, 52, 0.5, 0),
	cashLabelColor = Theme.color.cashGreen,
	cashLabelFont = Theme.font.heading,
	-- Outlined with Theme.hudSurface's text outline.
	cashLabelTextSize = 24,

	-- The plus button is extruded: a lit face over a darker base of the same
	-- size, plusDepth px lower, both inside a PlusWrapper tall enough to hold
	-- the two. plusPosition places the wrapper, so face and base together are
	-- centred in the panel rather than the face alone.
	plusSize = UDim2.new(0, 32, 0, 32),
	plusPosition = UDim2.new(1, -8, 0.5, 0),
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
	rowSize = UDim2.new(0, 188, 0, 44),
	rowPosition = UDim2.new(0, 1, 0, 116),

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
	-- 30px), so the two share a shape. Derived rather than copied, so it
	-- follows if either changes.
	cornerRadius = math.round(
		Theme.cashHud.cashPanelCorner * RICHEST_BANNER_HEIGHT / Theme.cashHud.cashPanelSize.Y.Offset
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

Theme.cashPackPanel = {
	size = UDim2.new(0, 380, 0, 420),
	position = UDim2.new(0.5, 0, 0.5, 0),
	background = Color3.fromRGB(10, 10, 10),
	cornerRadius = 20,
	strokeThickness = 2,
	strokeTransparency = 0,
	strokeColor = Color3.fromRGB(232, 240, 236),
	padding = 14,

	-- Present only in this theme, so the production theme's TitleBar stays
	-- flat and transparent. MainHUDBuilder applies a surface only when the key
	-- exists, which is what keeps the two themes swappable despite differing.
	titleBarSurface = {
		image = Theme.asset.stripePattern,
		-- Matches the panel's own cornerRadius rather than the 14 it had while
		-- the bar sat inside the padding: the bleed puts the bar's top corners
		-- exactly on the panel's, so a smaller radius left a dark sliver there.
		cornerRadius = 20,
		gradientRotation = 90,
		gradientTop = Color3.fromRGB(142, 238, 110),
		gradientBottom = Color3.fromRGB(58, 183, 62),
		strokeColor = Color3.fromRGB(232, 240, 236),
		strokeThickness = 2,
		tileSize = UDim2.fromOffset(72, 72),
		patternColor = Color3.fromRGB(0, 0, 0),
		patternTransparency = 0.8,

		-- The extruded "3D" lip along the bottom. depthColor is DERIVED from
		-- gradientBottom (58,183,62) dropped to roughly half brightness, which
		-- is how the reference screenshot's banner reads: one shadow shade of
		-- the same green, not a neutral grey. Tune the pair together -- a depth
		-- past ~8 starts eating the banner's visible face.
		depth = 6,
		depthColor = Color3.fromRGB(30, 108, 36),

		-- Deliberately NOT clipped: the CloseButton grows to 43.2px and lifts
		-- 4px inside the bar, so clipping here shaved 3.6px off its hover pop.
		-- The bar's tiles are masked by the PatternLayer's own UICorner
		-- instead, and the CloseButton clips its own tiles via closeSurface.
		clipsDescendants = false,
	},

	titleBarHeight = 44,

	-- How far the TitleBar escapes the panel's UIPadding on the left, right and
	-- top, so the banner spans the full panel width and fills the gap above it.
	-- Keep in step with `padding` above; anything else leaves an uneven border.
	-- The banner ends up titleBarHeight + titleBarBleed tall, and because it
	-- only grows upward the item list below it does not move.
	titleBarBleed = 14,

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

	-- The X button's stripes. No gradient was specified for it, so these two
	-- reds are DERIVED from the existing closeColor (220,60,60) -- a lighter
	-- top and darker bottom mirroring how the green gradients are built. Tune
	-- freely; nothing else depends on them. tileSize is likewise scaled down
	-- for a 40x40 button rather than copied from the 90x40 Buy button.
	--
	-- Clipping is safe here (unlike on the TitleBar): this button's only
	-- children are the pattern and caption, both fromScale(1,1), so they grow
	-- with it during the hover tween and never overflow.
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

		-- Same extrusion as the banner, shallower because the button is 40px
		-- tall rather than 58. Derived from gradientBottom (183,45,45) the same
		-- way the green one is derived from its own.
		depth = 4,
		depthColor = Color3.fromRGB(118, 26, 26),

		clipsDescendants = true,
		captionText = "X",
	},

	listTopOffset = 54,
	scrollBarColor = Theme.itemList.greenScrollBar,
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
