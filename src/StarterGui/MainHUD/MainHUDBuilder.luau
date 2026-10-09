-- MainHUDBuilder
-- Constructs the MainHUD instance tree in code, replacing the hand-placed
-- copy that previously lived inside src/StarterGui/MainHUD.rbxm. Values are
-- reproduced from that binary exactly; see Milestone notes where the written
-- spec and the binary disagreed.
--
-- Every colour, size, font and radius now comes from ReplicatedStorage.UITheme.
-- Instance names and hierarchy stay fixed here, because the controllers find
-- their elements by name and path.
--
-- Call build(gui) before any controller logic reads these instances --
-- MainHUDController dot-indexes several of them, so they must exist first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Theme = require(ReplicatedStorage:WaitForChild("UITheme"))
local UISurface = require(ReplicatedStorage:WaitForChild("UISurface"))

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

-- A stroke drawn around the object's edge. Border, not the default Contextual,
-- which on a TextButton outlines the TEXT -- and the row buttons have none,
-- so their strokes would never show. position picks whether the stroke sits
-- outside, across or inside that edge.
local function borderStroke(thickness, color, position, parent)
	local s = stroke(thickness, 0, color, parent)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.BorderStrokePosition = position
	return s
end

-- The lattice texture laid over a surface, as a TileLayer child. It reaches
-- past the parent's UIPadding to the real edges on its own -- padding shrinks
-- even scale sizes, so without this it would sit inset by the padding -- which
-- means any UIPadding must exist before this is called. inset then pulls it
-- in from every edge, to stop short of an Inner ring the layer would otherwise
-- draw over (children render above their parent's stroke). Its own UICorner
-- masks the square tiles to the rounded shape.
local function tileLayer(parent, tileSize, transparency, cornerRadius, inset)
	local pad = parent:FindFirstChildOfClass("UIPadding")
	local left = pad and pad.PaddingLeft.Offset or 0
	local right = pad and pad.PaddingRight.Offset or 0
	local top = pad and pad.PaddingTop.Offset or 0
	local bottom = pad and pad.PaddingBottom.Offset or 0

	local layer = new("ImageLabel", {
		Name = "TileLayer",
		Image = Theme.asset.latticeTile,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = tileSize,
		ImageColor3 = Theme.hudSurface.tileColor,
		ImageTransparency = transparency,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, left + right - 2 * inset, 1, top + bottom - 2 * inset),
		Position = UDim2.fromOffset(inset - left, inset - top),
		ZIndex = 1,
	}, parent)
	corner(cornerRadius, layer)
	return layer
end

-- The HUD's slate panel look (Theme.hudSurface): the gradient over a white
-- base, the light outline, the rounded corner and the lattice texture. The
-- cash panel and the richest banner both call this, so the two are built by
-- one piece of code from one set of values. Anything set on top of it needs
-- ZIndex 2 or more to sit above the TileLayer.
--
-- transparency (optional, default 0) fades the whole surface at once: the
-- fill, and the outline and texture by the same factor, so a see-through
-- surface keeps its look instead of leaving those two floating at full
-- strength over whatever shows through.
local function slateSurface(obj, cornerRadius, transparency)
	local S = Theme.hudSurface
	local opacity = 1 - (transparency or 0)
	local function faded(ownTransparency)
		return 1 - (1 - ownTransparency) * opacity
	end

	obj.BackgroundColor3 = Theme.color.white
	obj.BackgroundTransparency = faded(0)
	corner(cornerRadius, obj)
	-- A Frame's stroke defaults to its border, drawn outside the edge, so the
	-- texture never reaches under it.
	stroke(S.strokeThickness, faded(S.strokeTransparency), S.strokeColor, obj)
	new("UIGradient", {
		Rotation = S.gradientRotation,
		Color = S.gradient,
	}, obj)
	return tileLayer(obj, S.tileSize, faded(S.tileTransparency), cornerRadius, 0)
end

-- The heavier outline around text set on the slate surface. Left on stroke()'s
-- default (Contextual) deliberately: on a text object that outlines the
-- glyphs, which is the point here. thickness is optional and defaults to the
-- surface's own, heavier outline.
local function outlineText(label, thickness)
	return stroke(
		thickness or Theme.hudSurface.textOutlineThickness,
		0,
		Theme.hudSurface.textOutlineColor,
		label
	)
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

-- Applies the shared panel look. Callers that differ from it (CashPackPanel,
-- and MiddleShops' background) set their own values instead.
local function panelStroke(parent)
	return stroke(Theme.panel.strokeThickness, Theme.panel.strokeTransparency, Theme.panel.strokeColor, parent)
end

-- A panel's own outline when its theme gives it one, the shared grey otherwise.
-- The prototype's shop panels take the cash panel's white outline this way, so
-- that the white edges on the header and the buttons inside have a matching
-- edge around the panel to sit against -- without it they read far heavier
-- than they are.
local function panelStrokeFrom(T, parent)
	if T.strokeColor then
		return stroke(T.strokeThickness, T.strokeTransparency, T.strokeColor, parent)
	end
	return panelStroke(parent)
end

-- The standard panel header: a transparent bar holding a left-aligned title
-- and a square close button. The MainHUD panels and the MiddleShops panels
-- were built at different times and differ in closeRadius, the bar's
-- LayoutOrder and the title's BorderSizePixel, so those are per-caller.
local function titleBar(parent, titleText, closeRadius, barLayoutOrder, titleBorderSizePixel)
	local bar = new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, Theme.titleBar.height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = barLayoutOrder,
	}, parent)

	new("TextLabel", {
		Name = "TitleLabel",
		Size = Theme.titleBar.titleSize,
		BackgroundTransparency = 1,
		BorderSizePixel = titleBorderSizePixel,
		Text = titleText,
		TextColor3 = Theme.titleBar.titleColor,
		Font = Theme.titleBar.titleFont,
		TextSize = Theme.titleBar.titleTextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = Theme.titleBar.titleStrokeTransparency,
	}, bar)

	local close = new("TextButton", {
		Name = "CloseButton",
		Size = Theme.titleBar.closeSize,
		Position = Theme.titleBar.closePosition,
		BackgroundColor3 = Theme.titleBar.closeColor,
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = Theme.titleBar.closeTextColor,
		Font = Theme.titleBar.closeFont,
		TextSize = Theme.titleBar.closeTextSize,
		TextStrokeTransparency = Theme.titleBar.closeStrokeTransparency,
	}, bar)
	corner(closeRadius, close)

	return bar, close
end

-- The textured panel header: a surfaced bar that bleeds out to the panel's own
-- edges, carrying an optional round badge, the title, and a surfaced close
-- button. This is the look the prototype theme gives the cash panel and the
-- four shop panels; `titleBar` above stays the flat, transparent header.
--
-- `H` is a header config -- Theme.cashPackPanel itself for the cash panel, the
-- shared Theme.shopHeader for the shop-style ones. A panel whose theme has no
-- header config keeps the flat bar, which is what leaves the production theme,
-- and Settings and Pets in both themes, exactly as they were.
local function texturedTitleBar(parent, titleText, H)
	-- titleBarBleed cancels the panel's UIPadding, letting the banner reach the
	-- panel's own left, right and top edges instead of stopping at the padded
	-- content box.
	local bleed = H.titleBarBleed or 0
	-- How far the header's own contents stay clear of those edges. Defaults to
	-- the bleed, since a padded panel has already chosen that inset; the shop
	-- panels have no padding to bleed out of and set this on its own instead.
	local inset = H.titleBarInset or bleed
	local depth = (H.titleBarSurface and H.titleBarSurface.depth) or 0

	local bar = new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, bleed * 2, 0, H.titleBarHeight + bleed),
		Position = UDim2.new(0, -bleed, 0, -bleed),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, parent)

	if H.titleBarSurface then
		UISurface.applyTexturedSurface(bar, H.titleBarSurface)
	end

	-- The bleed must not drag the badge and X out to the panel's edge with it,
	-- so the header's contents live in here and get the inset back. It stops
	-- short of the surface's extruded lip as well, so they centre on the lit
	-- face rather than on the whole slab -- otherwise everything sits half the
	-- lip's height too low. The PatternLayer and SurfaceFace are ZIndex 0, so
	-- this frame's default 1 keeps every label above them.
	local content = new("Frame", {
		Name = "TitleContent",
		Size = UDim2.new(1, -inset * 2, 1, -depth),
		Position = UDim2.new(0, inset, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, bar)

	-- Only the cash panel carries a badge; the shop headers leave it out.
	if H.badgeSize then
		local badge = new("Frame", {
			Name = "TitleBadge",
			Size = H.badgeSize,
			Position = H.badgePosition,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = H.badgeBackground,
			BorderSizePixel = 0,
		}, content)
		new("UICorner", { CornerRadius = H.badgeCorner }, badge)
		new("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = H.badgeText or "$",
			TextColor3 = H.badgeTextColor,
			Font = H.badgeFont,
			TextSize = H.badgeTextSize,
		}, badge)
	end

	new("TextLabel", {
		Name = "TitleLabel",
		Size = H.titleSize,
		Position = H.titlePosition,
		BackgroundTransparency = 1,
		Text = titleText,
		TextColor3 = H.titleColor,
		Font = H.titleFont,
		TextSize = H.titleTextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = H.titleStrokeTransparency,
	}, content)

	local close = new("TextButton", {
		Name = "CloseButton",
		Size = H.closeSize,
		Position = H.closePosition,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = H.closeColor,
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = H.closeTextColor,
		Font = H.closeFont,
		TextSize = H.closeTextSize,
		TextStrokeTransparency = H.closeStrokeTransparency,
	}, content)
	corner(H.closeCorner, close)

	-- The pattern is a child, and children always render above their parent, so
	-- it would cover the button's own Text. The caption moves into a sibling
	-- label with a higher ZIndex instead.
	if H.closeSurface then
		UISurface.applyTexturedSurface(close, H.closeSurface)
		close.Text = ""
		new("TextLabel", {
			Name = "Caption",
			-- Short by the lip, for the same reason TitleContent is.
			Size = UDim2.new(1, 0, 1, -(H.closeSurface.depth or 0)),
			BackgroundTransparency = 1,
			Text = H.closeSurface.captionText,
			TextColor3 = H.closeTextColor,
			Font = H.closeFont,
			TextSize = H.closeTextSize,
			TextStrokeTransparency = H.closeStrokeTransparency,
			ZIndex = 2,
		}, close)
	end

	return bar, close
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
		ScrollBarThickness = Theme.itemList.scrollBarThickness,
		ScrollBarImageColor3 = scrollBarColor,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	listLayout(Theme.itemList.rowSpacing, list)
	-- Rows draw their UIStroke outside their own bounds, and this frame clips.
	-- Without a little padding the left edge of every row's outline (and the
	-- top of the first row) gets shaved off. Themes that omit these keep the
	-- original flush-left behaviour.
	padding(
		Theme.itemList.paddingTop or 0,
		Theme.itemList.paddingBottom or 0,
		Theme.itemList.paddingLeft or 0,
		Theme.itemList.paddingRight,
		list
	)
	return list
end

local function buildCashHUDGroup(gui)
	local T = Theme.cashHud

	local group = new("Frame", {
		Name = "CashHUDGroup",
		Size = T.groupSize,
		Position = T.groupPosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, gui)

	-- White because UIGradient multiplies against BackgroundColor3; the
	-- gradient alone sets the colour.
	local cashPanel = new("Frame", {
		Name = "CashPanel",
		Size = T.cashPanelSize,
		Position = T.cashPanelPosition,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, group)
	-- Padding first: the surface's texture reads it to reach the real edges.
	padding(T.cashPanelPadding, T.cashPanelPadding, T.cashPanelPadding, T.cashPanelPadding, cashPanel)
	slateSurface(cashPanel, T.cashPanelCorner)

	-- ZIndex 2 keeps the number above the TileLayer it shares the panel with.
	local cashLabel = new("TextLabel", {
		Name = "CashLabel",
		Size = T.cashLabelSize,
		Position = T.cashLabelPosition,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = 2,
		Text = "$0",
		TextColor3 = T.cashLabelColor,
		Font = T.cashLabelFont,
		TextSize = T.cashLabelTextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, cashPanel)
	outlineText(cashLabel)

	-- The extruded plus button. PlusBase and PlusButton are SIBLINGS inside
	-- the wrapper: a child always draws above its parent, so a base parented
	-- to the face would cover it. The wrapper is plusDepth taller than the
	-- button and is what gets centred, so face and base together sit in the
	-- middle of the panel. ZIndex 2 keeps the whole button above the TileLayer.
	local plusWrapper = new("Frame", {
		Name = "PlusWrapper",
		Size = T.plusSize + UDim2.fromOffset(0, T.plusDepth),
		Position = T.plusPosition,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		ZIndex = 2,
	}, cashPanel)

	local plusBase = new("Frame", {
		Name = "PlusBase",
		Size = T.plusSize,
		Position = UDim2.fromOffset(0, T.plusDepth),
		BackgroundColor3 = Theme.color.white,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, plusWrapper)
	corner(T.plusCorner, plusBase)
	new("UIGradient", {
		Rotation = T.plusGradientRotation,
		Color = T.plusBaseGradient,
	}, plusBase)

	-- Anchored at its top centre, so ButtonHoverEffect's grow spreads evenly
	-- left and right over the base instead of only to the right. Text is
	-- empty because the TileLayer child would cover the button's own text;
	-- the "+" is the PlusLabel above the tiles instead.
	local plusButton = new("TextButton", {
		Name = "PlusButton",
		Size = T.plusSize,
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.color.white,
		BorderSizePixel = 0,
		ZIndex = 3,
		Text = "",
	}, plusWrapper)
	corner(T.plusCorner, plusButton)
	new("UIGradient", {
		Rotation = T.plusGradientRotation,
		Color = T.plusFaceGradient,
	}, plusButton)
	-- Inner, so the rim stays within the face's 32px and the base below shows
	-- at the same width; Outer would make the face 6px wider than its base.
	borderStroke(T.plusStrokeThickness, T.plusStrokeColor, Enum.BorderStrokePosition.Inner, plusButton)
	tileLayer(plusButton, T.plusTileSize, T.plusTileTransparency, T.plusCorner - T.plusStrokeThickness, T.plusStrokeThickness)

	local plusLabel = new("TextLabel", {
		Name = "PlusLabel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Text = "+",
		Font = T.plusFont,
		TextColor3 = T.plusTextColor,
		TextScaled = true,
	}, plusButton)
	-- Contextual, like the cash number's: outlines the glyph.
	stroke(T.plusTextOutlineThickness, 0, T.plusTextOutlineColor, plusLabel)

	local outline = T.rowButtonOutline
	local depth = T.rowButtonDepth

	-- The shared button look, used by the house button and by all four buttons
	-- in the row below it. The button itself is the dark slab: a thin outline
	-- on three sides and a heavier lip along the bottom, which is what reads as
	-- depth. The Face on top carries the fill, and the ring colour is all that
	-- tells one button from another.
	local function slabButton(config)
		local button = new("TextButton", {
			Name = config.name,
			Size = T.rowButtonSize,
			Position = config.position,
			AnchorPoint = config.anchorPoint or Vector2.new(0, 0),
			BackgroundColor3 = T.rowButtonOutlineColor,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = config.zIndex or 2,
			-- Icon-only; the tooltips name each button.
			Text = "",
		}, config.parent)
		corner(T.rowButtonCorner, button)

		-- Scale plus offset, so the face follows ButtonHoverEffect's Size tween
		-- while the outline and lip stay fixed pixel widths. ZIndex 0 keeps it
		-- under the icon and badge it shares the button with.
		-- White because UIGradient multiplies against BackgroundColor3; the
		-- gradient alone sets the colour. Faces default to the cash banner's
		-- slate gradient; the house button passes its own green.
		local faceCorner = T.rowButtonCorner - outline
		local face = new("Frame", {
			Name = "Face",
			Size = UDim2.new(1, -2 * outline, 1, -(outline + depth)),
			Position = UDim2.fromOffset(outline, outline),
			BackgroundColor3 = Theme.color.white,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, button)
		-- Inset by the outline so its curve runs parallel to the slab's.
		corner(faceCorner, face)
		new("UIGradient", {
			Rotation = config.fillGradientRotation or T.rowButtonGradientRotation,
			Color = config.fillGradient or T.rowButtonGradient,
		}, face)
		-- Inner, so the ring stays on the face and the outline stays visible
		-- around it.
		local ring = borderStroke(T.rowButtonRingThickness, config.ringColor, Enum.BorderStrokePosition.Inner, face)
		-- Inset by the ring, so the tiles stop at its inner edge rather than
		-- darkening it.
		if config.tiled then
			local ringWidth = T.rowButtonRingThickness
			tileLayer(face, T.rowButtonTileSize, T.rowButtonTileTransparency, faceCorner - ringWidth, ringWidth)
		end

		-- On the button rather than the face so it keeps its full 44px canvas,
		-- shifted up to centre on the face instead of the slab. A scale above 1
		-- grows the art evenly in every direction.
		new("ImageLabel", {
			Size = UDim2.fromScale(config.iconScale, config.iconScale),
			Position = UDim2.new(0.5, 0, 0.5, -(depth - outline) / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = config.icon,
			ScaleType = Enum.ScaleType.Fit,
		}, button)
		return button, ring
	end

	-- The house button. It fires an action instead of opening a panel, so it
	-- keeps its place above the cash panel and its green gradient face, where
	-- the row below shares one slate fill. Only the face and ring differ: the
	-- dark outline and the lip are the row's, which is what still reads as one
	-- set of buttons.
	local teleportButton = slabButton({
		name = "TeleportToTycoonButton",
		position = T.teleportPosition,
		anchorPoint = Vector2.new(0.5, 0),
		-- Above the cash panel, as it has always been.
		zIndex = 3,
		icon = Theme.asset.teleportIcon,
		iconScale = 1,
		fillGradient = T.teleportGradient,
		fillGradientRotation = T.teleportGradientRotation,
		ringColor = T.teleportRingColor,
		parent = group,
	})

	-- The four panel-opening buttons, in one row under the cash panel. Each is
	-- placed by an explicit Position -- no UIListLayout, which would silently
	-- override every child's Position. The row is an invisible holder;
	-- ClipsDescendants stays off so the SALE badge can overhang ShopButton.
	local row = new("Frame", {
		Name = "ButtonRow",
		Size = T.rowSize,
		Position = T.rowPosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 2,
	}, group)

	local function rowButton(name, index, icon, iconScale, ringColor)
		return slabButton({
			name = name,
			position = UDim2.fromOffset(index * T.rowButtonStep, 0),
			icon = icon,
			iconScale = iconScale,
			ringColor = ringColor,
			-- The cash banner's lattice, so the row and the banner match.
			tiled = true,
			parent = row,
		})
	end

	local shopButton, shopRing = rowButton("ShopButton", 0, Theme.asset.shopIcon, 1, T.shopRingColor)
	local petsButton = rowButton("PetsButton", 1, Theme.asset.petsIcon, 1, T.petsRingColor)
	local inventoryButton =
		rowButton("InventoryButton", 2, Theme.asset.inventoryIcon, T.inventoryIconScale, T.inventoryRingColor)
	local settingsButton = rowButton("SettingsButton", 3, Theme.asset.settingsIcon, 1, T.settingsRingColor)

	-- Colours Shop's ring itself, multiplying against its white Color.
	-- MainHUDController spins it.
	local shopRainbow = new("UIGradient", {
		Name = "RainbowGradient",
		Color = T.shopRainbow,
	}, shopRing)

	-- A child always draws above its parent, so this covers the button face;
	-- ZIndex 2 keeps it above the icon it shares the button with.
	new("TextLabel", {
		Name = "SaleBadge",
		Size = T.saleBadgeSize,
		Position = T.saleBadgePosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = T.saleBadgeRotation,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Text = "SALE!",
		Font = Theme.font.heading,
		TextScaled = true,
		TextColor3 = T.saleBadgeColor,
		TextStrokeColor3 = Theme.color.white,
		TextStrokeTransparency = 0,
	}, shopButton)

	return {
		group = group,
		cashPanel = cashPanel,
		cashLabel = cashLabel,
		plusButton = plusButton,
		teleportButton = teleportButton,
		buttonRow = row,
		inventoryButton = inventoryButton,
		settingsButton = settingsButton,
		shopButton = shopButton,
		shopRainbow = shopRainbow,
		petsButton = petsButton,
	}
end

local function buildSettingsPanel(gui)
	local T = Theme.settings

	local panel = new("Frame", {
		Name = "SettingsPanel",
		Size = T.size,
		Position = T.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.panel.background,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(Theme.panel.cornerRadius, panel)
	panelStroke(panel)
	padding(T.padding, T.padding, T.padding, T.padding, panel)
	listLayout(T.rowSpacing, panel)

	local _, closeButton = titleBar(panel, "Settings", T.closeCorner, 1, 0)

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
			Size = UDim2.new(1, 0, 0, T.rowHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = borderSizePixel,
			LayoutOrder = layoutOrder,
		}, panel)

		new("TextLabel", {
			Name = "Label",
			Size = T.labelSize,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = labelText,
			TextColor3 = T.labelColor,
			Font = T.labelFont,
			TextSize = T.labelTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeTransparency = T.labelStrokeTransparency,
		}, row)

		local toggle = new("TextButton", {
			Name = "ToggleButton",
			Size = Theme.toggle.trackSize,
			Position = Theme.toggle.trackPosition,
			BackgroundColor3 = Theme.toggle.trackOnColor,
			BorderSizePixel = 0,
			Text = "",
		}, row)
		corner(Theme.toggle.trackCorner, toggle)

		local knob = new("Frame", {
			Name = "Knob",
			Size = Theme.toggle.knobSize,
			Position = Theme.toggle.knobOnPosition,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.toggle.knobColor,
			BorderSizePixel = 0,
		}, toggle)
		new("UICorner", { CornerRadius = Theme.toggle.knobCorner }, knob)

		return { row = row, track = toggle, knob = knob }
	end

	local music = toggleRow("MusicRow", "Music", 2, 1)
	local sfx = toggleRow("SFXRow", "SFX", 3, 0)

	return {
		panel = panel,
		closeButton = closeButton,
		music = music,
		sfx = sfx,
	}
end

local function buildRichestBanner(gui)
	local T = Theme.richestBanner

	local banner = new("Frame", {
		Name = "RichestBanner",
		Size = T.size,
		Position = T.position,
		AnchorPoint = Vector2.new(0.5, 0),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, gui)
	-- Padding first: the surface's texture reads it to reach the real edges.
	padding(0, 0, T.paddingX, T.paddingX, banner)
	slateSurface(banner, T.cornerRadius, T.surfaceTransparency)

	-- TextScaled, capped at labelTextSize, so the text draws at full size
	-- whenever the banner has room and shrinks only when it does not. Wrapped,
	-- so a squeezed banner can go to two lines if that reads larger than one
	-- tiny line. ZIndex 2 keeps it above the TileLayer.
	local label = new("TextLabel", {
		Name = "RichestLabel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Text = "★ Richest: --- ($0)",
		TextColor3 = T.labelColor,
		Font = T.labelFont,
		TextScaled = true,
		TextWrapped = true,
	}, banner)
	new("UITextSizeConstraint", { MaxTextSize = T.labelTextSize }, label)
	outlineText(label, T.labelOutlineThickness)

	-- The banner hugs its text, as AutomaticSize used to make it do, but stops
	-- at maxWidthScale of the screen. AutomaticSize had no ceiling, so a long
	-- name and a 9-figure value ran the banner off the sides of a phone. The
	-- width allows for the text outline and a pixel of rounding either side,
	-- so the text is never squeezed below full size while it fits.
	local slack = 2 * T.labelOutlineThickness + 2
	local function fitToText()
		local textWidth = TextService:GetTextSize(
			label.Text,
			T.labelTextSize,
			T.labelFont,
			Vector2.new(math.huge, math.huge)
		).X
		local width = textWidth + 2 * T.paddingX + slack
		local maxWidth = gui.AbsoluteSize.X * T.maxWidthScale
		-- AbsoluteSize can read 0 before the GUI is laid out; fit the text
		-- uncapped until it reports a real width.
		if maxWidth > 0 then
			width = math.min(width, maxWidth)
		end
		banner.Size = UDim2.new(0, width, T.size.Y.Scale, T.size.Y.Offset)
	end
	label:GetPropertyChangedSignal("Text"):Connect(fitToText)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToText)
	fitToText()

	return { banner = banner, label = label }
end

local function buildHealthBar(gui)
	local T = Theme.healthBar

	local bar = new("Frame", {
		Name = "HealthBar",
		Size = T.size,
		Position = T.position,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = T.background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, gui)
	corner(T.cornerRadius, bar)
	stroke(T.strokeThickness, T.strokeTransparency, T.strokeColor, bar)

	local fill = new("Frame", {
		Name = "FillBar",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = T.fillColor,
		BorderSizePixel = 0,
	}, bar)
	new("UIGradient", {
		Rotation = T.fillGradientRotation,
		Color = T.fillGradient,
	}, fill)
	corner(T.fillCorner, fill)

	local label = new("TextLabel", {
		Name = "HealthLabel",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Text = "100/100",
		TextColor3 = T.labelColor,
		Font = T.labelFont,
		TextSize = T.labelTextSize,
		TextStrokeTransparency = T.labelStrokeTransparency,
	}, bar)

	return { bar = bar, fill = fill, label = label }
end

local function buildShopPanel(gui)
	local T = Theme.shopPanel

	local panel = new("Frame", {
		Name = "ShopPanel",
		Size = T.size,
		Position = T.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.panel.background,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(Theme.panel.cornerRadius, panel)
	panelStrokeFrom(T, panel)
	padding(T.padding, T.padding, T.padding, T.padding, panel)

	-- Spec said this CloseButton matches SettingsPanel's (radius 10). It is
	-- actually 8, as is PetsPanel's; the MiddleShops panels do use 10. Themes
	-- that define a header config replace the whole flat bar with the textured
	-- one instead, and set their own close radius there.
	-- Both branches return (bar, close); only the close button is wired up.
	local _, closeButton
	if T.header then
		_, closeButton = texturedTitleBar(panel, "Shop", T.header)
	else
		_, closeButton = titleBar(panel, "Shop", T.closeCorner, 1, 0)
	end

	local list = itemList(panel, T.listTopOffset, T.scrollBarColor)

	return { panel = panel, closeButton = closeButton, itemList = list }
end

local function buildPetsPanel(gui)
	local T = Theme.petsPanel

	local panel = new("Frame", {
		Name = "PetsPanel",
		Size = T.size,
		Position = T.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.panel.background,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(Theme.panel.cornerRadius, panel)
	panelStroke(panel)
	padding(T.padding, T.padding, T.padding, T.padding, panel)
	listLayout(T.rowSpacing, panel)

	-- See buildShopPanel: radius 8, not the 10 the spec described.
	local _, closeButton = titleBar(panel, "Pets", T.closeCorner, 1, 0)

	local function placeholderRow(name, labelText, layoutOrder)
		local row = new("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, T.rowHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = layoutOrder,
		}, panel)

		new("TextLabel", {
			Name = "Label",
			Size = T.labelSize,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = labelText,
			TextColor3 = T.labelColor,
			Font = T.labelFont,
			TextSize = T.labelTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeTransparency = T.labelStrokeTransparency,
		}, row)

		-- Spec recorded the pill background as unset/default; it is actually
		-- this grey on all three rows.
		local pill = new("TextLabel", {
			Name = "SoonPill",
			Size = T.pillSize,
			Position = T.pillPosition,
			BackgroundColor3 = T.pillBackground,
			BorderSizePixel = 0,
			Text = "Soon",
			TextColor3 = T.pillTextColor,
			Font = T.pillFont,
			TextSize = T.pillTextSize,
			TextStrokeTransparency = T.pillStrokeTransparency,
		}, row)
		corner(T.pillCorner, pill)

		return row
	end

	placeholderRow("EquippedRow", "Equipped", 2)
	placeholderRow("OwnedRow", "Owned", 3)
	placeholderRow("InventoryRow", "Inventory", 4)

	return { panel = panel, closeButton = closeButton }
end

-- Same chrome as PetsPanel, with an empty Content frame below the title bar
-- in place of its placeholder rows, for a later pass to fill.
local function buildInventoryPanel(gui)
	local T = Theme.inventoryPanel

	local panel = new("Frame", {
		Name = "InventoryPanel",
		Size = T.size,
		Position = T.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.panel.background,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(Theme.panel.cornerRadius, panel)
	panelStroke(panel)
	padding(T.padding, T.padding, T.padding, T.padding, panel)
	listLayout(T.rowSpacing, panel)

	local _, closeButton = titleBar(panel, "Inventory", T.closeCorner, 1, 0)

	local content = new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 1, -Theme.titleBar.height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, panel)

	return { panel = panel, closeButton = closeButton, content = content }
end

local function buildCashPackPanel(gui)
	local T = Theme.cashPackPanel

	local panel = new("Frame", {
		Name = "CashPackPanel",
		Size = T.size,
		Position = T.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.background,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(T.cornerRadius, panel)
	stroke(T.strokeThickness, T.strokeTransparency, T.strokeColor, panel)
	padding(T.padding, T.padding, T.padding, T.padding, panel)

	-- The whole header -- bleeding bar, "$" badge, title and X -- comes from
	-- the shared helper, which reads these keys straight off this theme table.
	local _, close = texturedTitleBar(panel, "Cash", T)

	local list = itemList(panel, T.listTopOffset, T.scrollBarColor)

	return { panel = panel, closeButton = close, itemList = list }
end

-- Shared chrome for the NPC shop panels. Despite the spec describing these as
-- mirroring ShopPanel, they differ: a slightly different background, no
-- UIPadding, and a radius-10 close button where ShopPanel's is 8.
local function buildMiddleShopPanel(gui, name, titleText)
	local T = Theme.middleShopPanel

	local panel = new("Frame", {
		Name = name,
		Size = T.size,
		Position = T.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.background,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, gui)
	corner(Theme.panel.cornerRadius, panel)
	panelStrokeFrom(T, panel)
	-- Themes that want their rows inset from the panel edge set a padding; the
	-- original build had none here, so it stays opt-in.
	if T.padding then
		padding(T.padding, T.padding, T.padding, T.padding, panel)
	end

	-- Shares shopPanel's header config, so all four shop panels stay identical.
	-- Both branches return (bar, close); only the close button is wired up.
	local _, closeButton
	if T.header then
		_, closeButton = texturedTitleBar(panel, titleText, T.header)
	else
		_, closeButton = titleBar(panel, titleText, T.closeCorner, 0, 1)
	end

	local list = itemList(panel, T.listTopOffset, T.scrollBarColor)

	return { panel = panel, closeButton = closeButton, itemList = list }
end

-- One shared label reused for every hover tooltip, positioned and filled in at
-- runtime by ReplicatedStorage.Tooltip. Text is left at the TextLabel default.
local function buildTooltip(gui)
	local T = Theme.tooltip

	local tooltip = new("TextLabel", {
		Name = "Tooltip",
		Size = T.size,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = T.background,
		BorderSizePixel = 0,
		ZIndex = 100,
		Visible = false,
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = T.textColor,
		Font = T.font,
		TextSize = T.textSize,
	}, gui)
	padding(0, 0, T.paddingX, T.paddingX, tooltip)
	corner(T.cornerRadius, tooltip)
	stroke(T.strokeThickness, T.strokeTransparency, T.strokeColor, tooltip)

	return tooltip
end

-- Only the shops that still exist in Workspace.MiddleShops. The former Trading
-- Post, Vault and Upgrade Shop panels are deliberately not built.
--
-- `key` is what MiddleShopsController asks for, deliberately not the instance
-- name: a redesign can rename or re-parent the panel and only this table
-- changes.
local MIDDLE_SHOPS = {
	{ key = "creature", instanceName = "CreatureShopPanel", title = "Creature Shop" },
	{ key = "ball", instanceName = "BallShopPanel", title = "Ball Shop" },
	{ key = "gear", instanceName = "GearShopPanel", title = "Gear Shop" },
}

local builtRefs = nil

-- Builds the tree and returns a table of named references to every element the
-- controllers drive. They read those references instead of walking paths, so
-- renaming, re-parenting or re-nesting anything in here cannot break them --
-- only this file knows the layout.
--
-- Idempotent and safe to call from more than one script: MainHUDController and
-- MiddleShopsController are sibling LocalScripts with no guaranteed start
-- order, so whichever runs first builds and the other gets the cached refs.
--
-- Children are built in the same order as the hand-placed MainHUD, so the two
-- trees can still be compared child-by-child.
function MainHUDBuilder.build(gui)
	if builtRefs then
		return builtRefs
	end

	local settings = buildSettingsPanel(gui)
	local richest = buildRichestBanner(gui)
	local health = buildHealthBar(gui)
	local shop = buildShopPanel(gui)
	local pets = buildPetsPanel(gui)
	local inventory = buildInventoryPanel(gui)
	local cashPack = buildCashPackPanel(gui)
	local cashHud = buildCashHUDGroup(gui)

	local middleShops = {}
	for _, definition in ipairs(MIDDLE_SHOPS) do
		middleShops[definition.key] = buildMiddleShopPanel(gui, definition.instanceName, definition.title)
	end

	local tooltip = buildTooltip(gui)

	builtRefs = {
		cashLabel = cashHud.cashLabel,
		plusButton = cashHud.plusButton,
		teleportButton = cashHud.teleportButton,
		inventoryButton = cashHud.inventoryButton,
		settingsButton = cashHud.settingsButton,
		shopButton = cashHud.shopButton,
		petsButton = cashHud.petsButton,
		shopRainbow = cashHud.shopRainbow,

		settings = settings,
		shop = shop,
		pets = pets,
		inventory = inventory,
		cashPack = cashPack,
		middleShops = middleShops,

		richestLabel = richest.label,
		healthBar = health,
		tooltip = tooltip,
	}

	return builtRefs
end

return MainHUDBuilder
