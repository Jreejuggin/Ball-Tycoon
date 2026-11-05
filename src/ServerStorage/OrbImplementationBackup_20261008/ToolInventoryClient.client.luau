-- A presentation layer for tools already owned by the player. Purchases and damage stay on the server.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local MAX_HOTBAR_SLOTS = 10
local SLOT_GAP = 6
local ACTION_PREFIX = "TycoonToolInventory_"
local NUMBER_KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero,
}

local previousGui = playerGui:FindFirstChild("ToolInventoryGui")
if previousGui then
	previousGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ToolInventoryGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

local function round(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function textLabel(parent, name, text, position, size, fontSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextSize = fontSize
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"
hotbar.BackgroundTransparency = 1
hotbar.AnchorPoint = Vector2.new(0, 1)
hotbar.Parent = gui

local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotbarLayout.Padding = UDim.new(0, SLOT_GAP)
hotbarLayout.Parent = hotbar

local toggle = Instance.new("TextButton")
toggle.Name = "InventoryToggle"
toggle.AnchorPoint = Vector2.new(0, 1)
toggle.BackgroundColor3 = Color3.fromRGB(29, 32, 39)
toggle.BackgroundTransparency = 0.18
toggle.Text = "Bag"
toggle.Font = Enum.Font.GothamMedium
toggle.TextSize = 13
toggle.TextColor3 = Color3.fromRGB(245, 245, 245)
toggle.Selectable = true
toggle.Parent = gui
round(toggle, 8)

local panel = Instance.new("Frame")
panel.Name = "InventoryPanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = gui
round(panel, 10)

local panelTitle = textLabel(panel, "Title", "Inventory", UDim2.fromOffset(16, 10), UDim2.new(1, -70, 0, 28), 18)
panelTitle.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton")
close.Name = "Close"
close.Position = UDim2.new(1, -42, 0, 8)
close.Size = UDim2.fromOffset(32, 32)
close.BackgroundTransparency = 1
close.Text = "×"
close.TextSize = 26
close.Font = Enum.Font.Gotham
close.TextColor3 = Color3.fromRGB(245, 245, 245)
close.Selectable = true
close.Parent = panel

local grid = Instance.new("ScrollingFrame")
grid.Name = "Tools"
grid.Position = UDim2.fromOffset(12, 48)
grid.Size = UDim2.new(1, -24, 1, -60)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 5
grid.ScrollBarImageColor3 = Color3.fromRGB(150, 158, 170)
grid.CanvasSize = UDim2.fromOffset(0, 0)
grid.Parent = panel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.CellSize = UDim2.fromOffset(76, 76)
gridLayout.Parent = grid

local emptyLabel = textLabel(panel, "Empty", "No extra tools", UDim2.fromOffset(12, 60), UDim2.new(1, -24, 0, 26), 14)
emptyLabel.TextColor3 = Color3.fromRGB(175, 180, 190)

local alive = true
local refreshQueued = false
local records = {}
local orderByTool = setmetatable({}, { __mode = "k" })
local nextOrder = 0
local orderedRecords = {}
local hotbarRecords = {}
local globalConnections = {}
local backpackConnections = {}
local characterConnections = {}
local viewportConnection
local backpack
local character
local coreBackpackDisabled = false
local refresh

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function queueRefresh()
	if not alive or refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		if alive then
			refresh()
		end
	end)
end

local function usingGamepad()
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

local function equippedRecord()
	for _, record in ipairs(orderedRecords) do
		if record.tool.Parent == character then
			return record
		end
	end
	return nil
end

local function setPanelVisible(visible)
	panel.Visible = visible
	toggle.Text = visible and "Close" or "Bag"
	if usingGamepad() then
		local equipped = equippedRecord()
		local first = visible and orderedRecords[#hotbarRecords + 1] or hotbarRecords[1]
		local selected = equipped and (equipped.button.Parent == hotbar or visible) and equipped or first
		GuiService.SelectedObject = selected and selected.button or toggle
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) and not visible then
		GuiService.SelectedObject = nil
	end
end

local function activateTool(tool)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if tool.Parent == character then
		humanoid:UnequipTools()
	elseif tool.Parent == backpack then
		humanoid:EquipTool(tool)
	end
	queueRefresh()
end

local PREVIEW_CHILDREN = { SpecialMesh = true, Decal = true, Texture = true, SurfaceAppearance = true }

local function updatePreview(record)
	local viewport = record.viewport
	viewport:ClearAllChildren()
	local model = Instance.new("Model")
	model.Name = "ToolPreview"
	local originalHandle = record.tool:FindFirstChild("Handle")
	local origin = originalHandle and originalHandle:IsA("BasePart") and originalHandle.CFrame or CFrame.identity
	for _, source in ipairs(record.tool:GetDescendants()) do
		if source:IsA("BasePart") and source.Transparency < 1 then
			local ok, part = pcall(function()
				return source:Clone()
			end)
			if ok and part then
				-- Only renderers enter the preview: tool scripts, remotes, constraints and effects never run here.
				for _, child in ipairs(part:GetChildren()) do
					if not PREVIEW_CHILDREN[child.ClassName] then
						child:Destroy()
					end
				end
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.CFrame = origin:ToObjectSpace(source.CFrame)
				part.Parent = model
			end
		end
	end
	if #model:GetChildren() == 0 then
		model:Destroy()
		return
	end
	local bounds, size = model:GetBoundingBox()
	local previewRotation = record.tool:GetAttribute("InventoryPreviewRotation")
	if typeof(previewRotation) == "Vector3" then
		model:PivotTo(CFrame.Angles(math.rad(previewRotation.X), math.rad(previewRotation.Y), math.rad(previewRotation.Z))
			* CFrame.new(-bounds.Position) * model:GetPivot())
		bounds, size = model:GetBoundingBox()
	end
	model:PivotTo(CFrame.new(-bounds.Position) * model:GetPivot())
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	local distance = math.max(size.Magnitude * 0.5, 0.1) / math.sin(math.rad(camera.FieldOfView * 0.5)) * 1.1
	camera.CFrame = CFrame.lookAt(Vector3.new(0.35, 0.18, 1).Unit * distance, Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function createRecord(tool)
	if not orderByTool[tool] then
		nextOrder += 1
		orderByTool[tool] = nextOrder
	end
	local record = { tool = tool, order = orderByTool[tool], connections = {}, presentationDirty = true }
	local button = Instance.new("TextButton")
	button.Name = "ToolSlot_" .. tostring(record.order)
	button.Text = ""
	button.BackgroundColor3 = Color3.fromRGB(33, 36, 44)
	button.BackgroundTransparency = 0.22
	button.Selectable = true
	button.AutoButtonColor = true
	button.Parent = hotbar
	round(button, 8)
	record.button = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(255, 225, 128)
	stroke.Thickness = 2
	stroke.Enabled = false
	stroke.Parent = button
	record.stroke = stroke
	record.title = textLabel(button, "Title", "", UDim2.fromOffset(13, 5), UDim2.new(1, -26, 0, 18), 13)
	record.shortcut = textLabel(button, "Shortcut", "", UDim2.fromOffset(4, 3), UDim2.fromOffset(12, 14), 10)
	record.shortcut.TextColor3 = Color3.fromRGB(172, 180, 193)
	record.shortcut.TextXAlignment = Enum.TextXAlignment.Left
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.Position = UDim2.new(0, 7, 0, 25)
	image.Size = UDim2.new(1, -14, 1, -30)
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = button
	record.image = image
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ModelIcon"
	viewport.BackgroundTransparency = 1
	viewport.Position = image.Position
	viewport.Size = image.Size
	viewport.Ambient = Color3.fromRGB(190, 190, 190)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.6, -1, -0.6)
	viewport.Parent = button
	record.viewport = viewport
	table.insert(record.connections, button.Activated:Connect(function()
		activateTool(tool)
	end))
	local function markPresentationDirty()
		record.presentationDirty = true
		queueRefresh()
	end
	for _, property in ipairs({ "Name", "TextureId" }) do
		table.insert(record.connections, tool:GetPropertyChangedSignal(property):Connect(markPresentationDirty))
	end
	for _, attribute in ipairs({ "InventoryLevel", "InventoryDisplayName", "InventoryIcon", "InventoryPreviewRotation", "ItemId" }) do
		table.insert(record.connections, tool:GetAttributeChangedSignal(attribute):Connect(markPresentationDirty))
	end
	local function changedDescendant(descendant)
		if descendant:IsA("BasePart") or PREVIEW_CHILDREN[descendant.ClassName] then
			markPresentationDirty()
		end
	end
	table.insert(record.connections, tool.DescendantAdded:Connect(changedDescendant))
	table.insert(record.connections, tool.DescendantRemoving:Connect(changedDescendant))
	return record
end

local function updatePresentation(record)
	local level = tonumber(record.tool:GetAttribute("InventoryLevel"))
	local displayName = record.tool:GetAttribute("InventoryDisplayName")
	if level and level >= 1 then
		record.title.Text = "Lvl " .. tostring(math.floor(level))
	else
		record.title.Text = type(displayName) == "string" and displayName ~= "" and displayName or record.tool.Name
	end
	local iconOverride = record.tool:GetAttribute("InventoryIcon")
	local icon = type(iconOverride) == "string" and iconOverride ~= "" and iconOverride or record.tool.TextureId
	record.image.Image = icon
	record.image.Visible = icon ~= ""
	record.viewport.Visible = icon == ""
	if icon == "" then
		updatePreview(record)
	else
		record.viewport:ClearAllChildren()
	end
	record.presentationDirty = false
end

refresh = function()
	local owned = {}
	local function collectTools(container)
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") then
					owned[child] = true
					if not records[child] then
						records[child] = createRecord(child)
					end
				end
			end
		end
	end
	collectTools(backpack)
	collectTools(character)
	for tool, record in pairs(records) do
		if not owned[tool] then
			disconnectAll(record.connections)
			record.button:Destroy()
			records[tool] = nil
		end
	end
	table.clear(orderedRecords)
	for _, record in pairs(records) do
		table.insert(orderedRecords, record)
	end
	table.sort(orderedRecords, function(a, b)
		return a.order < b.order
	end)
	local camera = Workspace.CurrentCamera
	local viewportSize = camera and camera.ViewportSize or Vector2.new(800, 600)
	local capacity = math.clamp(math.floor((viewportSize.X - 96) / (64 + SLOT_GAP)), 1, MAX_HOTBAR_SLOTS)
	local slotSize = math.clamp(math.floor((viewportSize.X - 96 - (capacity - 1) * SLOT_GAP) / capacity), 48, 72)
	local visibleCount = math.min(capacity, #orderedRecords)
	local hotbarWidth = math.max(0, visibleCount * (slotSize + SLOT_GAP) - SLOT_GAP)
	local totalWidth = hotbarWidth + (visibleCount > 0 and SLOT_GAP or 0) + 48
	hotbar.Position = UDim2.new(0.5, -totalWidth * 0.5, 1, -14)
	hotbar.Size = UDim2.fromOffset(hotbarWidth, slotSize)
	toggle.Position = UDim2.new(0.5, -totalWidth * 0.5 + hotbarWidth + (visibleCount > 0 and SLOT_GAP or 0), 1, -14)
	toggle.Size = UDim2.fromOffset(48, slotSize)
	panel.Position = UDim2.new(0.5, 0, 1, -slotSize - 26)
	panel.Size = UDim2.fromOffset(math.min(680, viewportSize.X - 24), math.max(120, math.min(360, viewportSize.Y - slotSize - 60)))
	table.clear(hotbarRecords)
	for index, record in ipairs(orderedRecords) do
		local onHotbar = index <= capacity
		record.button.Parent = onHotbar and hotbar or grid
		record.button.NextSelectionLeft = nil
		record.button.NextSelectionRight = nil
		record.button.LayoutOrder = index
		record.button.Size = UDim2.fromOffset(slotSize, slotSize)
		record.shortcut.Text = onHotbar and tostring(index % 10) or ""
		record.stroke.Enabled = record.tool.Parent == character
		if record.presentationDirty then
			updatePresentation(record)
		end
		if onHotbar then
			table.insert(hotbarRecords, record)
		end
	end
	for index, record in ipairs(hotbarRecords) do
		record.button.NextSelectionLeft = hotbarRecords[index - 1] and hotbarRecords[index - 1].button or toggle
		record.button.NextSelectionRight = hotbarRecords[index + 1] and hotbarRecords[index + 1].button or toggle
	end
	toggle.NextSelectionLeft = hotbarRecords[#hotbarRecords] and hotbarRecords[#hotbarRecords].button or nil
	toggle.NextSelectionRight = hotbarRecords[1] and hotbarRecords[1].button or nil
	emptyLabel.Visible = #orderedRecords <= capacity
	grid.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 8)
end

local function attachBackpack(newBackpack)
	disconnectAll(backpackConnections)
	backpack = newBackpack
	if backpack then
		table.insert(backpackConnections, backpack.ChildAdded:Connect(queueRefresh))
		table.insert(backpackConnections, backpack.ChildRemoved:Connect(queueRefresh))
	end
	queueRefresh()
end

local function attachCharacter(newCharacter)
	disconnectAll(characterConnections)
	character = newCharacter
	if character then
		table.insert(characterConnections, character.ChildAdded:Connect(queueRefresh))
		table.insert(characterConnections, character.ChildRemoved:Connect(queueRefresh))
	end
	queueRefresh()
end

local function attachCamera()
	if viewportConnection then
		viewportConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	viewportConnection = camera and camera:GetPropertyChangedSignal("ViewportSize"):Connect(queueRefresh) or nil
	queueRefresh()
end

table.insert(globalConnections, toggle.Activated:Connect(function()
	setPanelVisible(not panel.Visible)
end))
table.insert(globalConnections, close.Activated:Connect(function()
	setPanelVisible(false)
end))
table.insert(globalConnections, gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	grid.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 8)
end))
table.insert(globalConnections, player.CharacterAdded:Connect(attachCharacter))
table.insert(globalConnections, player.CharacterRemoving:Connect(function(removingCharacter)
	if character == removingCharacter then
		attachCharacter(nil)
	end
end))
table.insert(globalConnections, player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		attachBackpack(child)
	end
end))
table.insert(globalConnections, player.ChildRemoved:Connect(function(child)
	if child == backpack then
		attachBackpack(nil)
	end
end))
table.insert(globalConnections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera))

local function canHandleInput(state)
	return alive and gui.Enabled and state == Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() == nil
end

for index, key in ipairs(NUMBER_KEYS) do
	ContextActionService:BindAction(ACTION_PREFIX .. tostring(index), function(_, state)
		local record = hotbarRecords[index]
		if canHandleInput(state) and record then
			activateTool(record.tool)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, key)
end

ContextActionService:BindAction(ACTION_PREFIX .. "Toggle", function(_, state)
	if canHandleInput(state) then
		setPanelVisible(not panel.Visible)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.B, Enum.KeyCode.Backquote, Enum.KeyCode.ButtonY)

ContextActionService:BindAction(ACTION_PREFIX .. "Cycle", function(_, state, input)
	if not canHandleInput(state) or #orderedRecords == 0 then
		return Enum.ContextActionResult.Pass
	end
	local currentIndex = 0
	local equipped = equippedRecord()
	for index, record in ipairs(orderedRecords) do
		if record == equipped then
			currentIndex = index
			break
		end
	end
	local step = input.KeyCode == Enum.KeyCode.ButtonL1 and -1 or 1
	local nextIndex = currentIndex == 0 and (step < 0 and #orderedRecords or 1) or ((currentIndex - 1 + step) % #orderedRecords + 1)
	local nextRecord = orderedRecords[nextIndex]
	if nextRecord.button.Parent == grid then
		setPanelVisible(true)
	end
	GuiService.SelectedObject = nextRecord.button
	activateTool(nextRecord.tool)
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)

attachBackpack(player:FindFirstChildOfClass("Backpack"))
attachCharacter(player.Character)
attachCamera()
refresh()

-- CoreGui can still be initializing when PlayerScripts start; leave the native inventory usable if setup fails.
task.spawn(function()
	for _ = 1, 8 do
		if not alive then
			return
		end
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			coreBackpackDisabled = true
			gui.Enabled = true
			return
		end
		task.wait(0.5)
	end
	warn("ToolInventoryClient could not replace CoreGui Backpack; the native inventory remains available.")
end)

script.Destroying:Connect(function()
	alive = false
	disconnectAll(globalConnections)
	disconnectAll(backpackConnections)
	disconnectAll(characterConnections)
	if viewportConnection then
		viewportConnection:Disconnect()
	end
	for _, record in pairs(records) do
		disconnectAll(record.connections)
	end
	for index = 1, MAX_HOTBAR_SLOTS do
		ContextActionService:UnbindAction(ACTION_PREFIX .. tostring(index))
	end
	ContextActionService:UnbindAction(ACTION_PREFIX .. "Toggle")
	ContextActionService:UnbindAction(ACTION_PREFIX .. "Cycle")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	gui:Destroy()
	if coreBackpackDisabled then
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
		end)
	end
end)
