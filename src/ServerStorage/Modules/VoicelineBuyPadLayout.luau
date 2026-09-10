-- Matches WorkerSpeedService's title / benefit / price layout.
-- Keep labels on an upright anchor: a cylinder's local X axis is vertical.
local Layout = {}
local PAD_DIAMETER = 4.285063
local PAD_THICKNESS = 0.354892
local WHITE = Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 235, 90)

local function ensure(parent, name, className)
	local instance = parent:FindFirstChild(name)
	if instance then
		assert(instance:IsA(className), name .. " has an unexpected class")
		return instance
	end
	instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function textLabel(parent, name, color, position, size)
	local label = ensure(parent, name, "TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.FontFace = Font.new(
		"rbxasset://fonts/families/GothamSSm.json",
		Enum.FontWeight.Bold, Enum.FontStyle.Normal
	)
	label.Position = position
	label.Size = size
	return label
end

local function billboard(anchor, name, height, offset)
	local gui = ensure(anchor, name, "BillboardGui")
	gui.Adornee = anchor
	gui.Size = UDim2.new(4, 0, height, 0)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.StudsOffsetWorldSpace = Vector3.zero
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = math.huge
	gui.Enabled = false
	return gui
end

function Layout.Apply(station)
	local pad = assert(station:FindFirstChild("BuyPad"), "Missing voiceline BuyPad")
	local head = assert(pad:FindFirstChild("Head"), "Missing voiceline pad Head")
	assert(head:IsA("Part"), "Voiceline pad must be a Part")
	local position = head.Position
	head.Shape = Enum.PartType.Cylinder
	head.Size = Vector3.new(PAD_THICKNESS, PAD_DIAMETER, PAD_DIAMETER)
	-- Absolute orientation makes repeated setup safe; do not rotate incrementally.
	head.CFrame = CFrame.new(position) * station:GetPivot().Rotation * CFrame.Angles(0, 0, math.pi / 2)
	head.Anchored = true
	head.Material = Enum.Material.Neon
	head.CanCollide = false
	head.CastShadow = false

	local anchor = ensure(pad, "LabelAnchor", "Part")
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false

	local oldPrice = head:FindFirstChild("PriceLabel")
	if oldPrice then
		assert(not anchor:FindFirstChild("PriceLabel"), "Duplicate price labels")
		oldPrice.Parent = anchor
	end
	local titleGui = billboard(anchor, "UpgradeLabel", 2, 5)
	local title = textLabel(titleGui, "TitleText", WHITE, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.55))
	local benefit = textLabel(titleGui, "BenefitText", YELLOW, UDim2.fromScale(0, 0.52), UDim2.fromScale(1, 0.48))
	local priceGui = billboard(anchor, "PriceLabel", 1.5, 3)
	local price = textLabel(priceGui, "PriceText", WHITE, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	title.Text = "Worker Voicelines"
	return {upgradeLabel = titleGui, titleText = title, benefitText = benefit, priceLabel = priceGui, priceText = price}
end

return Layout
