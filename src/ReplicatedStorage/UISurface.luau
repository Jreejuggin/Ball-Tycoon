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
-- Applied by the prototype theme to every panel header (the cash panel's and
-- the four shop panels'), their close buttons, and every row's Buy button.

local UISurface = {}

local PATTERN_NAME = "PatternLayer"
local FACE_NAME = "SurfaceFace"

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
--   depth, depthColor              (optional -- omit for a flat surface)
--   clipsDescendants               (optional, defaults true)

-- Paints the gradient and the tiled pattern onto one object.
--
-- Split out of applyTexturedSurface because a surface with depth paints its
-- face rather than itself: the object underneath has to stay a flat slab of
-- depthColor for the lip to read as an extruded side.
local function paintTexture(obj, config)
	-- A UIGradient multiplies against BackgroundColor3, so the background has
	-- to be white for the gradient to define the colour on its own. Leaving a
	-- green background under a green gradient darkens it into mud.
	obj.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	obj.BackgroundTransparency = 0

	local corner = ensureOfClass(obj, "UICorner")
	corner.CornerRadius = UDim.new(0, config.cornerRadius)

	local gradient = ensureOfClass(obj, "UIGradient")
	gradient.Rotation = config.gradientRotation
	gradient.Color = ColorSequence.new(config.gradientTop, config.gradientBottom)

	local pattern = obj:FindFirstChild(PATTERN_NAME)
	if not pattern then
		pattern = Instance.new("ImageLabel")
		pattern.Name = PATTERN_NAME
		pattern.Parent = obj
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

function UISurface.applyTexturedSurface(guiObject, config)
	-- Square tiles would otherwise paint over the rounded corners. Clipping on
	-- the parent is what actually masks them to the UICorner shape.
	--
	-- It clips every other child too, so a surface whose children intentionally
	-- overflow (e.g. a button that grows past its container on hover) should
	-- pass clipsDescendants = false.
	guiObject.ClipsDescendants = config.clipsDescendants ~= false

	if config.strokeColor then
		local stroke = ensureOfClass(guiObject, "UIStroke")
		stroke.Color = config.strokeColor
		stroke.Thickness = config.strokeThickness
		-- Border rather than Contextual. On a TextButton -- the X and the Buy
		-- buttons -- Contextual puts the stroke around the rendered TEXT, and
		-- both of those blank their own Text and draw a Caption child instead,
		-- so the outline had nothing to draw around and never showed up. On a
		-- plain Frame like the TitleBar the two modes behave the same, which is
		-- why only the buttons were missing their border.
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end

	local depth = config.depth or 0
	if depth <= 0 then
		return paintTexture(guiObject, config)
	end

	-- The 3D look: the object itself becomes a flat slab of the darker
	-- depthColor, and the lit face sits on top of it `depth` pixels short, so
	-- the slab shows along the bottom as an extruded lip. Both carry the same
	-- cornerRadius, so the lip tapers away into the rounded bottom corners.
	guiObject.BackgroundColor3 = config.depthColor
	guiObject.BackgroundTransparency = 0

	local corner = ensureOfClass(guiObject, "UICorner")
	corner.CornerRadius = UDim.new(0, config.cornerRadius)

	local face = guiObject:FindFirstChild(FACE_NAME)
	if not face then
		face = Instance.new("Frame")
		face.Name = FACE_NAME
		face.Parent = guiObject
	end
	face.BorderSizePixel = 0
	-- Scale on the width so the face follows ButtonHoverEffect's Size tween;
	-- the depth stays a fixed pixel offset so the lip does not thicken as the
	-- button grows.
	face.Size = UDim2.new(1, 0, 1, -depth)
	face.Position = UDim2.fromScale(0, 0)
	-- Siblings only (the GUI is ZIndexBehavior.Sibling): 0 keeps the face below
	-- every caption and label sharing this parent.
	face.ZIndex = 0

	return paintTexture(face, config)
end

return UISurface
