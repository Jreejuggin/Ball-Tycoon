-- Local-only audio previews. Opening is authorized by the station server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("VoicelineMenuEvent")
local SFXSettings = require(ReplicatedStorage:WaitForChild("SFXSettings"))
local Catalog = require(ReplicatedStorage:WaitForChild("VoicelineCatalog"))
local allowed = {}
for _, entry in ipairs(Catalog) do allowed[entry.id] = entry end

local function create(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for property, value in pairs(properties or {}) do object[property] = value end
	object.Parent = parent
	return object
end
local function corner(parent, radius)
	create("UICorner", "Corners", parent, {CornerRadius = UDim.new(0, radius)})
end
local white = Color3.fromRGB(244, 246, 252)
local muted = Color3.fromRGB(167, 177, 197)
local yellow = Color3.fromRGB(255, 229, 41)
local gui = create("ScreenGui", "VoicelineMenu", player:WaitForChild("PlayerGui"), {
	Enabled = false, ResetOnSpawn = false, DisplayOrder = 60,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false,
})
local shade = create("Frame", "Shade", gui, {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.4, BorderSizePixel = 0, Active = true,
})
local panel = create("Frame", "Panel", shade, {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.92, 0, 0.86, 0), BackgroundColor3 = Color3.fromRGB(19, 23, 34),
	BorderSizePixel = 0,
})
create("UISizeConstraint", "MaximumSize", panel, {MaxSize = Vector2.new(620, 510)})
corner(panel, 18)
local accent = create("UIStroke", "PlotAccent", panel, {Thickness = 2, Color = yellow})
local function label(name, parent, text, position, size, fontSize, color)
	return create("TextLabel", name, parent, {
		Text = text, Position = position, Size = size, BackgroundTransparency = 1,
		TextColor3 = color or white, TextSize = fontSize, Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	})
end
label("Eyebrow", panel, "WORKER AUDIO COLLECTION", UDim2.fromOffset(22, 15), UDim2.new(1, -92, 0, 20), 11, yellow)
local title = label("Title", panel, "Voicelines", UDim2.fromOffset(22, 37), UDim2.new(1, -92, 0, 35), 28)
title.Font = Enum.Font.GothamBold
local subtitle = label("Subtitle", panel, "Choose a voiceline to preview.", UDim2.fromOffset(22, 77), UDim2.new(1, -44, 0, 30), 13, muted)
subtitle.TextWrapped = true
local closeButton = create("TextButton", "Close", panel, {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 20),
	Size = UDim2.fromOffset(44, 44), Text = "X", TextSize = 18, Font = Enum.Font.GothamBold,
	TextColor3 = white, BackgroundColor3 = Color3.fromRGB(40, 47, 63),
	BorderSizePixel = 0, Selectable = true,
})
corner(closeButton, 10)
local list = create("ScrollingFrame", "AudioList", panel, {
	Position = UDim2.fromOffset(18, 119), Size = UDim2.new(1, -36, 1, -221),
	BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5, ScrollBarImageColor3 = muted,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
create("UIListLayout", "Layout", list, {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
create("UIPadding", "Padding", list, {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4)})
local nowPlaying = label("NowPlaying", panel, "Select Preview to listen.", UDim2.new(0, 22, 1, -89), UDim2.new(1, -44, 0, 42), 13, white)
nowPlaying.TextWrapped = true
local hint = label("Hint", panel, "Only you hear previews. Close: X / Esc / B", UDim2.new(0, 22, 1, -39), UDim2.new(1, -44, 0, 28), 11, muted)
hint.TextWrapped = true

local currentSound, currentId, session, previousSelection
local rows, rowConnections, soundConnections = {}, {}, {}
local distanceConnection
local generation = 0
local function disconnectAll(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end
local function stopPreview(message)
	generation += 1
	disconnectAll(soundConnections)
	if currentSound then
		currentSound:Stop()
		currentSound:Destroy()
		currentSound = nil
	end
	currentId = nil
	for _, row in pairs(rows) do
		row.button.Text = "Preview"
		row.button.BackgroundColor3 = Color3.fromRGB(51, 62, 82)
	end
	nowPlaying.Text = message or "Select Preview to listen."
	nowPlaying.TextColor3 = white
end
local function close()
	gui.Enabled = false
	session = nil
	stopPreview()
	ContextActionService:UnbindAction("CloseVoicelineMenu")
	if distanceConnection then distanceConnection:Disconnect(); distanceConnection = nil end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
	end
end
local function preview(entry)
	if not gui.Enabled then return end
	if currentId == entry.id then stopPreview("Preview stopped."); return end
	stopPreview()
	currentId = entry.id
	local request = generation
	local row = rows[entry.id]
	row.button.Text = "Stop"
	row.button.BackgroundColor3 = Color3.fromRGB(143, 55, 69)
	nowPlaying.Text = "Loading " .. entry.name .. "..."
	local sound = Instance.new("Sound")
	sound.Name = "VoicelinePreview"
	sound.SoundId = entry.soundId
	sound.Volume = 0.75
	sound.Looped = false
	SFXSettings.ApplyToSound(sound)
	currentSound = sound
	local began = false
	local function begin()
		if began or generation ~= request or currentSound ~= sound or not gui.Enabled then return end
		began = true
		sound:Play()
		local mutedSuffix = SFXSettings.IsMuted() and " (SFX muted in settings)" or ""
		nowPlaying.Text = "Playing: " .. entry.name .. mutedSuffix
		nowPlaying.TextColor3 = yellow
		task.delay(30, function()
			if generation == request and currentSound == sound then stopPreview("Preview finished.") end
		end)
	end
	table.insert(soundConnections, sound.Loaded:Connect(begin))
	table.insert(soundConnections, sound.Ended:Connect(function()
		if generation == request then stopPreview("Preview finished. Choose another voiceline.") end
	end))
	sound.Parent = SoundService
	if sound.IsLoaded then begin() end
	task.delay(8, function()
		if generation == request and currentSound == sound and not began then
			stopPreview("Audio unavailable. This clip may need experience permission.")
			nowPlaying.TextColor3 = Color3.fromRGB(255, 164, 142)
		end
	end)
end

closeButton.Activated:Connect(close)
player.CharacterRemoving:Connect(close)
event.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or typeof(payload.station) ~= "Instance"
		or typeof(payload.plot) ~= "Instance" or type(payload.entries) ~= "table" then return end
	local station, plot = payload.station, payload.plot
	if not station:IsDescendantOf(workspace) or station.Parent ~= plot
		or plot:GetAttribute("Owner") ~= player.UserId or not station:GetAttribute("Unlocked") then return end
	close()
	session = payload
	previousSelection = GuiService.SelectedObject
	disconnectAll(rowConnections)
	for _, row in pairs(rows) do row.frame:Destroy() end
	table.clear(rows)
	local count, firstButton = 0, nil
	for _, item in ipairs(payload.entries) do
		local entry = type(item) == "table" and allowed[item.id]
		if entry and entry.soundId == item.soundId and not rows[entry.id] then
			count += 1
			local frame = create("Frame", entry.id, list, {
				Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = Color3.fromRGB(30, 36, 50),
				BorderSizePixel = 0, LayoutOrder = count,
			})
			corner(frame, 10)
			local nameLabel = label("Name", frame, entry.name, UDim2.fromOffset(14, 8), UDim2.new(1, -116, 0, 32), 15)
			nameLabel.TextWrapped = true
			label("Availability", frame, "Available", UDim2.fromOffset(14, 44), UDim2.new(1, -116, 0, 20), 12, yellow)
			local button = create("TextButton", "Preview", frame, {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(88, 44), Text = "Preview", TextSize = 13,
				Font = Enum.Font.GothamBold, TextColor3 = white,
				BackgroundColor3 = Color3.fromRGB(51, 62, 82), BorderSizePixel = 0, Selectable = true,
			})
			corner(button, 8)
			rows[entry.id] = {frame = frame, button = button}
			firstButton = firstButton or button
			table.insert(rowConnections, button.Activated:Connect(function() preview(entry) end))
		end
	end
	accent.Color = typeof(payload.color) == "Color3" and payload.color or yellow
	subtitle.Text = count .. " available voicelines | Preview any clip below."
	nowPlaying.Text = count > 0 and "Select Preview to listen." or "No voicelines configured yet."
	list.CanvasPosition = Vector2.zero
	gui.Enabled = true
	if game:GetService("UserInputService").GamepadEnabled then GuiService.SelectedObject = firstButton or closeButton end
	ContextActionService:BindActionAtPriority("CloseVoicelineMenu", function(_, state)
		if state == Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
	local elapsed = 0
	distanceConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		if not session then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local visual = station:FindFirstChild("VoicelineMicrophone_Roblox")
		local anchor = visual and visual:FindFirstChild("MIC_ButtonGlow_Yellow", true)
		if not station:IsDescendantOf(workspace) or not root or not anchor or not humanoid
			or humanoid.Health <= 0 or plot:GetAttribute("Owner") ~= player.UserId
			or not station:GetAttribute("Unlocked") or (root.Position - anchor.Position).Magnitude > 14 then close() end
	end)
end)