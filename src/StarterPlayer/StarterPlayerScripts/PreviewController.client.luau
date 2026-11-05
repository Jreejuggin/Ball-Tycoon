-- PreviewController
-- Floats a single emoji preview above each plot's Home Centre structure pad.
--
-- The pad's "CurrentStructure" attribute is written by StructureSequenceService
-- on the server and tells us which structure is next in the sequence. An empty
-- value means the pad is retired (Home Centre locked, or everything bought),
-- so the preview hides.
--
-- Covers both floors: floor 1's pad at <plot>/CentreSlots/Centre02_Home and
-- floor 2's at <plot>/SecondFloor/CentreSlots/Centre02_Home (built by
-- SecondFloorService). Floor-2 structure groups carry a floor suffix
-- ("Walls_F2"), which is stripped so both floors share one set of icons.
--
-- The Second Floor purchase pad (SecondFloorService's FloorBuyPad) gets the
-- same floating icon. It has no CurrentStructure attribute: its icon shows
-- whenever the server shows the pad (the floor is up for sale), and hides
-- once the pad hides again (bought, or not unlocked yet).
--
-- Purely cosmetic. No purchase logic lives on the client.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ws = game:GetService("Workspace")

local player = Players.LocalPlayer

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local CONFIG = {
	HEIGHT_ABOVE_PAD = 8,     -- studs above the pad
	BOB_AMPLITUDE    = 0.4,   -- how far it floats up/down
	BOB_SPEED        = 1.5,   -- bob cycles per second
	BACKGROUND_ALPHA = 0.7,   -- 0 = solid, 1 = invisible
	EMOJI_HEIGHT     = 0.6,   -- fraction of the frame used by the emoji
	AVAILABLE_TEXT_ALPHA = 0.55,
	AVAILABLE_STROKE_ALPHA = 0.7,
	AVAILABLE_BACKGROUND_ALPHA = 0.92,

	-- Size is in STUDS (the scale component of UDim2), which makes the
	-- billboard behave like a physical object: it occupies a fixed amount of
	-- world space and shrinks with distance, the same as the pad below it.
	--
	-- Do NOT use offset/pixel sizing here. Offset pins the billboard to a
	-- constant number of screen pixels, so backing away leaves it the same
	-- size while the world shrinks around it, and it appears to grow.
	BILLBOARD_STUDS = Vector2.new(5, 6),
}

local STRUCTURE_STYLES = {
	Walls         = { emoji = "🧱", label = "Walls",      color = Color3.fromRGB(180, 100,  50) },
	Glass         = { emoji = "🧊", label = "Glass",      color = Color3.fromRGB(100, 150, 200) },
	LaserDoor     = { emoji = "🚪", label = "Laser Door", color = Color3.fromRGB(255, 100, 100) },
	Roof          = { emoji = "🏠", label = "Roof",       color = Color3.fromRGB(150, 150, 150) },
	CeilingLights = { emoji = "💡", label = "Lights",     color = Color3.fromRGB(255, 255, 100) },
	SecondFloor   = { emoji = "🏢", label = "2nd Floor",  color = Color3.fromRGB(70, 160, 255) },
}

local previews = {}   -- [pad] = { anchor, frame, emojiLabel, nameLabel, group, time }

-- Where each floor's Home Centre structure pad lives, relative to the plot.
local PAD_PATHS = {
	{ "CentreSlots", "Centre02_Home", "StructureBuyPad" },                -- floor 1
	{ "SecondFloor", "CentreSlots", "Centre02_Home", "StructureBuyPad" }, -- floor 2
}

-- Pads that always offer the same upgrade. Their icon follows the pad's own
-- visibility instead of a CurrentStructure attribute.
local FIXED_PADS = {
	{ path = { "SecondFloor", "FloorBuyPad" }, style = "SecondFloor" },
}

local function findChildPath(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

-- "Walls_F2" -> "Walls". Matches SecondFloorConfig.GroupSuffix and leaves
-- floor-1 names untouched.
local function getStyleKey(groupName)
	return (string.gsub(groupName, "_F%d+$", ""))
end

--------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------
-- One billboard is built per pad and then re-skinned as the sequence
-- advances, rather than destroying and rebuilding it each stage.
local function buildPreview(pad)
	local anchor = Instance.new("Part")
	anchor.Name = "StructurePreviewAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Parent = ws

	local bill = Instance.new("BillboardGui")
	bill.Name = "StructurePreview"
	bill.Adornee = anchor
	bill.Size = UDim2.fromScale(CONFIG.BILLBOARD_STUDS.X, CONFIG.BILLBOARD_STUDS.Y)
	bill.MaxDistance = math.huge
	-- Keeps the colours constant from every camera angle: LightInfluence 0
	-- stops world lighting tinting the GUI, AlwaysOnTop stops geometry and
	-- atmosphere in front of it dimming it, Brightness pins the exposure.
	bill.LightInfluence = 0
	bill.AlwaysOnTop = true
	bill.Brightness = 1
	bill.Enabled = false
	bill.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Name = "Background"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = CONFIG.BACKGROUND_ALPHA
	frame.BorderSizePixel = 0
	frame.Parent = bill

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = frame

	local emojiLabel = Instance.new("TextLabel")
	emojiLabel.Name = "EmojiLabel"
	emojiLabel.Size = UDim2.fromScale(1, CONFIG.EMOJI_HEIGHT)
	emojiLabel.Position = UDim2.fromScale(0, 0)
	emojiLabel.BackgroundTransparency = 1
	emojiLabel.TextScaled = true
	emojiLabel.TextColor3 = Color3.new(1, 1, 1)
	emojiLabel.Font = Enum.Font.GothamBold
	emojiLabel.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 1 - CONFIG.EMOJI_HEIGHT)
	nameLabel.Position = UDim2.fromScale(0, CONFIG.EMOJI_HEIGHT)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = frame

	return {
		anchor = anchor,
		bill = bill,
		frame = frame,
		emojiLabel = emojiLabel,
		nameLabel = nameLabel,
		group = nil,
		mode = nil,
		time = 0,
	}
end

-- Repaint only when the stage actually changed.
local function applyStyle(preview, groupName)
	if preview.group == groupName then return end
	preview.group = groupName

	local style = STRUCTURE_STYLES[getStyleKey(groupName)]
	if not style then return end

	preview.frame.BackgroundColor3 = style.color
	preview.emojiLabel.Text = style.emoji
	preview.nameLabel.Text = style.label
end

local function applyPresentation(preview, mode)
	if preview.mode == mode then return end
	preview.mode = mode

	local isAvailablePreview = mode == "CentreAvailable"
	local textAlpha = isAvailablePreview and CONFIG.AVAILABLE_TEXT_ALPHA or 0
	preview.frame.BackgroundTransparency = isAvailablePreview
		and CONFIG.AVAILABLE_BACKGROUND_ALPHA
		or CONFIG.BACKGROUND_ALPHA
	preview.emojiLabel.TextTransparency = textAlpha
	preview.nameLabel.TextTransparency = textAlpha
	preview.nameLabel.TextStrokeTransparency = isAvailablePreview
		and CONFIG.AVAILABLE_STROKE_ALPHA
		or 0
end

--------------------------------------------------------------------
-- Update
--------------------------------------------------------------------
local function updatePad(plot, pad, dt, fixedStyle)
	local preview = previews[pad]
	if not preview then
		preview = buildPreview(pad)
		previews[pad] = preview
	end

	local groupName, mode
	if fixedStyle then
		-- Shown only while the server shows the pad (Transparency below 1).
		groupName = pad.Transparency < 1 and fixedStyle or ""
		mode = "Purchase"
	else
		groupName = pad:GetAttribute("CurrentStructure")
		mode = pad:GetAttribute("StructurePreviewMode")
	end
	local isAvailablePreview = mode == "CentreAvailable"
	local isOwnedByLocalPlayer = tonumber(plot:GetAttribute("Owner")) == player.UserId
	local shouldShow = type(groupName) == "string"
		and groupName ~= ""
		and STRUCTURE_STYLES[getStyleKey(groupName)] ~= nil
		and (not isAvailablePreview or isOwnedByLocalPlayer)

	if preview.bill.Enabled ~= shouldShow then
		preview.bill.Enabled = shouldShow
	end
	if not shouldShow then return end

	applyStyle(preview, groupName)
	applyPresentation(preview, mode)

	preview.time += dt
	local bob = math.sin(preview.time * CONFIG.BOB_SPEED * math.pi * 2) * CONFIG.BOB_AMPLITUDE
	preview.anchor.Position = pad.Position + Vector3.new(0, CONFIG.HEIGHT_ABOVE_PAD + bob, 0)
end

local function sweepStale()
	for pad, preview in pairs(previews) do
		if not pad.Parent then
			preview.anchor:Destroy()
			previews[pad] = nil
		end
	end
end

local cleanupTimer = 0

RunService.RenderStepped:Connect(function(dt)
	cleanupTimer += dt
	if cleanupTimer >= 5 then
		cleanupTimer = 0
		sweepStale()
	end

	for _, plot in ipairs(ws:GetChildren()) do
		if plot.Name:match("^P%d+$") then
			for _, path in ipairs(PAD_PATHS) do
				local pad = findChildPath(plot, path)
				if pad and pad:IsA("BasePart") then
					updatePad(plot, pad, dt)
				end
			end
			for _, fixed in ipairs(FIXED_PADS) do
				local pad = findChildPath(plot, fixed.path)
				if pad and pad:IsA("BasePart") then
					updatePad(plot, pad, dt, fixed.style)
				end
			end
		end
	end
end)
