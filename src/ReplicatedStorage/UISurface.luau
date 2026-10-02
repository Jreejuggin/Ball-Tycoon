-- UISurface
-- Gives a GuiObject the "textured surface" look: a vertical gradient with a
-- tiled pattern overlaid on top of it.
--
-- This lives outside UITheme on purpose. UITheme is a selector over two pure
-- value tables (UITheme_Production / UITheme_Prototype), so a function there
-- would have to be duplicated into both. Instead the values stay in the theme
-- and the instance work happens here.
--
-- Usage:
--   local UISurface = require(ReplicatedStorage.UISurface)
--   UISurface.applyTexturedSurface(someFrame, Theme.cashPackPanel.titleBarSurface)
--
-- Currently applied only to CashPackPanel's TitleBar and its row Buy buttons.

local UISurface = {}

local PATTERN_NAME = "PatternLayer"

-- Reuses an existing child of this class rather than adding a second one, so
-- applyTexturedSurface can be called repeatedly on the same object. Buy
-- buttons already arrive with a UICorner and UIGradient, and those get updated
-- in place instead of duplicated.
local function ensureOfClass(parent, className)
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Parent = parent
	return inst
end

-- config fields:
--   image, tileSize, patternColor, patternTransparency
--   cornerRadius, gradientRotation, gradientTop, gradientBottom
--   strokeColor, strokeThickness   (optional -- omit for no stroke)
--   clipsDescendants               (optional, defaults true)
function UISurface.applyTexturedSurface(guiObject, config)
	-- A UIGradient multiplies against BackgroundColor3, so the background has
	-- to be white for the gradient to define the colour on its own. Leaving a
	-- green background under a green gradient darkens it into mud.
	guiObject.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	guiObject.BackgroundTransparency = 0

	-- Square tiles would otherwise paint over the rounded corners. Clipping on
	-- the parent is what actually masks them to the UICorner shape.
	--
	-- It clips every other child too, so a surface whose children intentionally
	-- overflow (e.g. a button that grows past its container on hover) should
	-- pass clipsDescendants = false.
	guiObject.ClipsDescendants = config.clipsDescendants ~= false

	local corner = ensureOfClass(guiObject, "UICorner")
	corner.CornerRadius = UDim.new(0, config.cornerRadius)

	local gradient = ensureOfClass(guiObject, "UIGradient")
	gradient.Rotation = config.gradientRotation
	gradient.Color = ColorSequence.new(config.gradientTop, config.gradientBottom)

	if config.strokeColor then
		local stroke = ensureOfClass(guiObject, "UIStroke")
		stroke.Color = config.strokeColor
		stroke.Thickness = config.strokeThickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end

	local pattern = guiObject:FindFirstChild(PATTERN_NAME)
	if not pattern then
		pattern = Instance.new("ImageLabel")
		pattern.Name = PATTERN_NAME
		pattern.Parent = guiObject
	end

	pattern.Image = config.image
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = config.tileSize
	pattern.ImageColor3 = config.patternColor
	pattern.ImageTransparency = config.patternTransparency
	pattern.BackgroundTransparency = 1
	pattern.BorderSizePixel = 0
	-- fromScale so the layer tracks its parent through ButtonHoverEffect's
	-- Size tween without needing its own animation.
	pattern.Size = UDim2.fromScale(1, 1)
	-- Children always render above their parent, so ZIndex only orders this
	-- against its siblings: 0 keeps it under every label and icon.
	pattern.ZIndex = 0

	-- Without this the square tiles would paint over the parent's rounded
	-- corners.
	local patternCorner = ensureOfClass(pattern, "UICorner")
	patternCorner.CornerRadius = UDim.new(0, config.cornerRadius)

	return pattern
end

return UISurface
