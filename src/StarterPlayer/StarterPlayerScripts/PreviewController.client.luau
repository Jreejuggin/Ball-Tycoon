-- PreviewController
-- Floats a single emoji preview above each plot's Home Centre structure pad.
--
-- The pad's "CurrentStructure" attribute is written by StructureSequenceService
-- on the server and tells us which structure is next in the sequence. An empty
-- value means the pad is retired (Home Centre locked, or everything bought),
-- so the preview hides.
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
}

local previews = {}   -- [pad] = { anchor, frame, emojiLabel, nameLabel, group, time }

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

	local style = STRUCTURE_STYLES[groupName]
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
local function updatePad(pad, dt)
	local preview = previews[pad]
	if not preview then
		preview = buildPreview(pad)
		previews[pad] = preview
	end

	local groupName = pad:GetAttribute("CurrentStructure")
	local mode = pad:GetAttribute("StructurePreviewMode")
	local homeCentre = pad.Parent
	local centreSlots = homeCentre and homeCentre.Parent
	local plot = centreSlots and centreSlots.Parent
	local isAvailablePreview = mode == "CentreAvailable"
	local isOwnedByLocalPlayer = plot
		and tonumber(plot:GetAttribute("Owner")) == player.UserId
	local shouldShow = groupName ~= nil
		and groupName ~= ""
		and STRUCTURE_STYLES[groupName] ~= nil
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
			local centreSlots = plot:FindFirstChild("CentreSlots")
			local homeCentre = centreSlots and centreSlots:FindFirstChild("Centre02_Home")
			local pad = homeCentre and homeCentre:FindFirstChild("StructureBuyPad")
			if pad then
				updatePad(pad, dt)
			end
		end
	end
end)
