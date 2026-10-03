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

	local cashPanel = new("Frame", {
		Name = "CashPanel",
		Size = T.cashPanelSize,
		Position = T.cashPanelPosition,
		BackgroundColor3 = T.cashPanelBackground,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, group)
	corner(T.cashPanelCorner, cashPanel)
	stroke(T.cashPanelStrokeThickness, T.cashPanelStrokeTransparency, T.cashPanelStrokeColor, cashPanel)
	padding(T.cashPanelPadding, T.cashPanelPadding, T.cashPanelPadding, T.cashPanelPadding, cashPanel)

	local cashLabel = new("TextLabel", {
		Name = "CashLabel",
		Size = T.cashLabelSize,
		Position = T.cashLabelPosition,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Text = "$0",
		TextColor3 = T.cashLabelColor,
		Font = T.cashLabelFont,
		TextSize = T.cashLabelTextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = T.cashLabelStrokeTransparency,
	}, cashPanel)

	local plusButton = new("TextButton", {
		Name = "PlusButton",
		Size = T.plusSize,
		Position = T.plusPosition,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = T.plusColor,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Text = "+",
		TextColor3 = T.plusTextColor,
		Font = T.plusFont,
		TextSize = T.plusTextSize,
		TextStrokeTransparency = T.plusStrokeTransparency,
	}, cashPanel)
	corner(T.plusCorner, plusButton)

	-- TextSize/TextStroke/RichText below have no visible effect while Text is
	-- empty, but are reproduced so the instance matches the binary exactly.
	local teleportButton = new("TextButton", {
		Name = "TeleportToTycoonButton",
		Size = T.teleportSize,
		Position = T.teleportPosition,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = T.teleportColor,
		BorderSizePixel = 0,
		ZIndex = 3,
		Text = "",
		TextColor3 = T.teleportTextColor,
		Font = T.teleportFont,
		TextSize = T.teleportTextSize,
		TextStrokeTransparency = T.teleportStrokeTextTransparency,
		TextWrapped = true,
		RichText = true,
	}, group)
	corner(T.teleportCorner, teleportButton)
	stroke(T.teleportStrokeThickness, T.teleportStrokeTransparency, T.teleportStrokeColor, teleportButton, "AccentStroke")

	-- Spec described this as "0.475 -> 1 (blue -> green-ish)" with six
	-- transparency keypoints. The binary has two green keypoints and a fully
	-- opaque transparency sequence; 0.475 was the first colour's red channel.
	new("UIGradient", {
		Rotation = T.teleportGradientRotation,
		Color = T.teleportGradient,
	}, teleportButton)

	new("ImageLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = Theme.asset.teleportIcon,
		ScaleType = Enum.ScaleType.Fit,
	}, teleportButton)

	local settingsButton = new("TextButton", {
		Name = "SettingsButton",
		Size = T.settingsSize,
		Position = T.settingsPosition,
		BackgroundColor3 = T.settingsColor,
		BorderSizePixel = 0,
		ZIndex = 2,
		Text = "⚙",
		TextColor3 = T.settingsTextColor,
		Font = T.settingsFont,
		TextSize = T.settingsTextSize,
		TextStrokeTransparency = T.settingsStrokeTextTransparency,
		TextWrapped = true,
	}, group)
	corner(T.settingsCorner, settingsButton)
	stroke(T.settingsStrokeThickness, T.settingsStrokeTransparency, T.settingsStrokeColor, settingsButton)
	-- Second UICorner is a leftover from an earlier fix; kept so the tree
	-- matches the binary. Roblox applies only one, so it has no visual effect.
	corner(T.settingsCornerDuplicate, settingsButton)

	new("ImageLabel", {
		Size = T.settingsIconSize,
		BackgroundColor3 = Theme.color.white,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = Theme.asset.settingsIcon,
		ScaleType = Enum.ScaleType.Stretch,
	}, settingsButton)

	local function quickActionButton(name, xOffset, text)
		local button = new("TextButton", {
			Name = name,
			Size = T.quickSize,
			Position = UDim2.new(0, xOffset, 0, T.quickY),
			BackgroundColor3 = T.quickColor,
			BorderSizePixel = 0,
			ZIndex = 2,
			Text = text,
			TextColor3 = T.quickTextColor,
			Font = T.quickFont,
			TextSize = T.quickTextSize,
			TextScaled = true,
			TextStrokeTransparency = T.quickStrokeTextTransparency,
			TextWrapped = true,
		}, group)
		corner(T.quickCorner, button)
		stroke(T.quickStrokeThickness, T.quickStrokeTransparency, T.quickStrokeColor, button)
		padding(0, 0, 0, 0, button)
		return button
	end

	local shopButton = quickActionButton("ShopButton", T.quickShopX, "Shop")
	local petsButton = quickActionButton("PetsButton", T.quickPetsX, "Pets")

	return {
		group = group,
		cashPanel = cashPanel,
		cashLabel = cashLabel,
		plusButton = plusButton,
		teleportButton = teleportButton,
		settingsButton = settingsButton,
		shopButton = shopButton,
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
		BackgroundColor3 = T.background,
		BorderSizePixel = 0,
		ZIndex = 5,
		AutomaticSize = Enum.AutomaticSize.X,
	}, gui)
	corner(T.cornerRadius, banner)
	stroke(T.strokeThickness, T.strokeTransparency, T.strokeColor, banner)
	padding(0, 0, T.paddingX, T.paddingX, banner)

	local label = new("TextLabel", {
		Name = "RichestLabel",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "★ Richest: --- ($0)",
		TextColor3 = T.labelColor,
		Font = T.labelFont,
		TextSize = T.labelTextSize,
		TextStrokeTransparency = T.labelStrokeTransparency,
	}, banner)

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
		settingsButton = cashHud.settingsButton,
		shopButton = cashHud.shopButton,
		petsButton = cashHud.petsButton,

		settings = settings,
		shop = shop,
		pets = pets,
		cashPack = cashPack,
		middleShops = middleShops,

		richestLabel = richest.label,
		healthBar = health,
		tooltip = tooltip,
	}

	return builtRefs
end

return MainHUDBuilder
