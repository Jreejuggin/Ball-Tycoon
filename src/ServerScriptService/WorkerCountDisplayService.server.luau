--!strict
-- WorkerCountDisplayService
-- Displays saved worker progress inside each hiring kiosk.
-- The label is hidden until Worker1 is purchased, updates from WorkerActivations,
-- and remains below the kiosk roof so it reads as first-floor world UI.

local ANCHOR_NAME = "WorkerCountAnchor"
local GUI_NAME = "WorkerCountLabel"
local TEXT_NAME = "WorkerCountText"
local ANCHOR_LOCAL_POSITION = Vector3.new(0, 7.45, -1.55)
local MAX_VIEW_DISTANCE = 50

local TEXT_COLOR = Color3.fromRGB(0, 225, 255)
local STROKE_COLOR = Color3.fromRGB(0, 0, 0)

local function ensureDisplay(kiosk: Model): (BillboardGui, TextLabel)
	local anchor = kiosk:FindFirstChild(ANCHOR_NAME)
	if not anchor or not anchor:IsA("BasePart") then
		if anchor then
			anchor:Destroy()
		end
		anchor = Instance.new("Part")
		anchor.Name = ANCHOR_NAME
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Parent = kiosk
	end

	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.CFrame = kiosk:GetPivot() * CFrame.new(ANCHOR_LOCAL_POSITION)

	local gui = anchor:FindFirstChild(GUI_NAME)
	if not gui or not gui:IsA("BillboardGui") then
		if gui then
			gui:Destroy()
		end
		gui = Instance.new("BillboardGui")
		gui.Name = GUI_NAME
		gui.Parent = anchor
	end

	gui.Adornee = anchor
	gui.Size = UDim2.new(5, 0, 1.65, 0)
	gui.StudsOffset = Vector3.zero
	gui.StudsOffsetWorldSpace = Vector3.zero
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = MAX_VIEW_DISTANCE
	gui.Enabled = false

	local textLabel = gui:FindFirstChild(TEXT_NAME)
	if not textLabel or not textLabel:IsA("TextLabel") then
		if textLabel then
			textLabel:Destroy()
		end
		textLabel = Instance.new("TextLabel")
		textLabel.Name = TEXT_NAME
		textLabel.Parent = gui
	end

	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Position = UDim2.fromScale(0, 0)
	textLabel.AnchorPoint = Vector2.zero
	textLabel.TextScaled = true
	textLabel.TextWrapped = true
	textLabel.FontFace = Font.new(
		"rbxasset://fonts/families/GothamSSm.json",
		Enum.FontWeight.Bold,
		Enum.FontStyle.Normal
	)
	textLabel.TextColor3 = TEXT_COLOR
	textLabel.TextStrokeColor3 = STROKE_COLOR
	textLabel.TextStrokeTransparency = 0
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.Text = ""

	return gui, textLabel
end

local function countWorkers(activations: Folder): (number, number)
	local unlocked = 0
	local total = 0

	for _, child in ipairs(activations:GetChildren()) do
		if child:IsA("BoolValue") then
			total += 1
			if child.Value then
				unlocked += 1
			end
		end
	end

	return unlocked, total
end

local function wirePlot(plot: Instance): boolean
	local kiosk = plot:FindFirstChild("HiringKiosk")
	local centreSlots = plot:FindFirstChild("CentreSlots")
	local workerCentre = centreSlots and centreSlots:FindFirstChild("Centre01_Worker")
	local activations = workerCentre and workerCentre:FindFirstChild("WorkerActivations")

	if not kiosk or not kiosk:IsA("Model")
		or not activations or not activations:IsA("Folder")
	then
		warn(("[WorkerCountDisplayService] Missing kiosk or WorkerActivations in %s"):format(
			plot:GetFullName()
		))
		return false
	end

	local gui, textLabel = ensureDisplay(kiosk)
	local valueConnections: { [BoolValue]: RBXScriptConnection } = {}

	local function updateDisplay()
		local unlocked, total = countWorkers(activations)
		local firstWorker = activations:FindFirstChild("Worker1")
		local firstWorkerPurchased = firstWorker ~= nil
			and firstWorker:IsA("BoolValue")
			and firstWorker.Value
		local hasOwner = plot:GetAttribute("Owner") ~= nil

		gui.Enabled = hasOwner and firstWorkerPurchased and total > 0
		if total > 0 and unlocked >= total then
			textLabel.Text = "MAX WORKERS"
		else
			textLabel.Text = string.format("%d/%d Workers", unlocked, total)
		end

		kiosk:SetAttribute("WorkersUnlocked", unlocked)
		kiosk:SetAttribute("WorkerCapacity", total)
	end

	local function wireValue(value: Instance)
		if not value:IsA("BoolValue") or valueConnections[value] then
			return
		end
		valueConnections[value] = value:GetPropertyChangedSignal("Value"):Connect(updateDisplay)
	end

	for _, child in ipairs(activations:GetChildren()) do
		wireValue(child)
	end

	activations.ChildAdded:Connect(function(child)
		wireValue(child)
		updateDisplay()
	end)
	activations.ChildRemoved:Connect(function(child)
		local connection = valueConnections[child :: any]
		if connection then
			connection:Disconnect()
			valueConnections[child :: any] = nil
		end
		updateDisplay()
	end)
	plot:GetAttributeChangedSignal("Owner"):Connect(updateDisplay)

	updateDisplay()
	return true
end

local wiredCount = 0
for plotIndex = 1, 10 do
	local plot = workspace:FindFirstChild("P" .. plotIndex)
	if plot and wirePlot(plot) then
		wiredCount += 1
	end
end

print(("[WorkerCountDisplayService] Wired %d hiring-kiosk worker counters."):format(
	wiredCount
))
