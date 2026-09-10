-- MachineIncomeCashRainClient
-- Adds a subtle cash-bill pop/fade animation behind each purchased machine's
-- income-per-minute BillboardGui. The faster a machine earns, the faster the
-- cash bills appear. Runs locally so it costs no server work.

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Upload your PNG to Roblox, then paste the asset id here, for example:
-- local CASH_IMAGE_ID = "rbxassetid://1234567890"
local localPlayer = Players.LocalPlayer
local cashImageIdValue = ReplicatedStorage:WaitForChild("CashRainImageId")
local function getCashImageId()
	return cashImageIdValue.Value
end

local FALLBACK_CASH_TEXT = "💵"
local MIN_SPAWN_INTERVAL = 0.28
local MAX_SPAWN_INTERVAL = 1.45
local BASE_INCOME_PER_MIN = 200
local LABEL_SCAN_INTERVAL = 3
local MAX_ACTIVE_BILLS_PER_LABEL = 8

local trackedLabels = {}

local function parseIncomePerMinute(text)
	if typeof(text) ~= "string" then
		return BASE_INCOME_PER_MIN
	end

	local beforePerMinute = string.match(text, "(.-)/min") or text
	local digits = string.gsub(beforePerMinute, "[^%d]", "")
	local value = tonumber(digits)
	return value and math.max(value, 1) or BASE_INCOME_PER_MIN
end

local function getSpawnInterval(incomePerMinute)
	local scale = math.pow(BASE_INCOME_PER_MIN / math.max(incomePerMinute, 1), 0.45)
	return math.clamp(MAX_SPAWN_INTERVAL * scale, MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL)
end

local function getPlotForInstance(instance)
	local current = instance
	while current and current.Parent ~= Workspace do
		current = current.Parent
	end

	if current and current.Parent == Workspace and string.match(current.Name, "^P%d+$") then
		return current
	end

	return nil
end

local function isOwnedByLocalPlayer(instance)
	local plot = getPlotForInstance(instance)
	if not plot or not localPlayer then
		return false
	end

	return plot:GetAttribute("Owner") == localPlayer.UserId
end

local function clearCashBills(layer)
	for _, child in ipairs(layer:GetChildren()) do
		if child.Name == "CashRainBill" then
			child:Destroy()
		end
	end
end

local function ensureLayer(billboardGui)
	local incomeText = billboardGui:FindFirstChild("IncomeText")
	if not incomeText or not incomeText:IsA("TextLabel") then
		return nil, nil
	end

	incomeText.BackgroundTransparency = 1
	incomeText.ZIndex = 10

	local layer = billboardGui:FindFirstChild("CashRainLayer")
	if not layer then
		layer = Instance.new("Frame")
		layer.Name = "CashRainLayer"
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.ClipsDescendants = false
		layer.Size = UDim2.fromScale(1, 1)
		layer.Position = UDim2.fromScale(0, 0)
		layer.ZIndex = 1
		layer.Parent = billboardGui
	end

	return layer, incomeText
end

local function createCashBill(layer)
	local cashImageId = getCashImageId()
	local useImage = cashImageId ~= ""
	local bill

	if useImage then
		bill = Instance.new("ImageLabel")
		bill.Image = cashImageId
		bill.ImageTransparency = 0.25
		bill.ScaleType = Enum.ScaleType.Fit
	else
		bill = Instance.new("TextLabel")
		bill.Text = FALLBACK_CASH_TEXT
		bill.TextTransparency = 0.2
		bill.TextScaled = true
		bill.Font = Enum.Font.GothamBold
		bill.TextColor3 = Color3.fromRGB(110, 255, 75)
		bill.TextStrokeTransparency = 0.75
	end

	bill.Name = "CashRainBill"
	bill.BackgroundTransparency = 1
	bill.AnchorPoint = Vector2.new(0.5, 0.5)
	bill.ZIndex = 2
	bill.Rotation = math.random(-24, 24)
	-- Large billboard-scale cash images: roughly 15-20x the original subtle bills.
	bill.Size = UDim2.fromScale(math.random(320, 440) / 100, math.random(360, 520) / 100)
	bill.Position = UDim2.fromScale(math.random(18, 82) / 100, math.random(16, 70) / 100)
	bill.Parent = layer

	return bill, useImage
end

local function animateCashBill(layer, tracker)
	if tracker.activeBills >= MAX_ACTIVE_BILLS_PER_LABEL then
		return
	end

	tracker.activeBills += 1
	local bill, isImage = createCashBill(layer)

	local endPosition = bill.Position - UDim2.fromScale(math.random(-8, 8) / 100, math.random(16, 30) / 100)
	local endRotation = bill.Rotation + math.random(-18, 18)
	local lifetime = math.random(70, 105) / 100

	local tween = TweenService:Create(
		bill,
		TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = endPosition,
			Rotation = endRotation,
			Size = bill.Size + UDim2.fromScale(0.05, 0.05),
		}
	)

	local fadeTween
	if isImage then
		fadeTween = TweenService:Create(
			bill,
			TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ImageTransparency = 1}
		)
	else
		fadeTween = TweenService:Create(
			bill,
			TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{TextTransparency = 1, TextStrokeTransparency = 1}
		)
	end

	tween:Play()
	fadeTween:Play()

	task.delay(lifetime + 0.05, function()
		if bill then
			bill:Destroy()
		end
		tracker.activeBills = math.max(0, tracker.activeBills - 1)
	end)
end

local function trackIncomeLabel(billboardGui)
	if trackedLabels[billboardGui] then
		return
	end
	if not billboardGui:IsA("BillboardGui") or billboardGui.Name ~= "IncomeLabel" then
		return
	end

	local layer, incomeText = ensureLayer(billboardGui)
	if not layer or not incomeText then
		return
	end

	local tracker = {
		activeBills = 0,
		running = true,
	}
	trackedLabels[billboardGui] = tracker

	billboardGui.Destroying:Connect(function()
		tracker.running = false
		trackedLabels[billboardGui] = nil
	end)

	task.spawn(function()
		task.wait(math.random() * 1.5)
		while tracker.running and billboardGui.Parent do
			if billboardGui.Enabled and incomeText.Visible and isOwnedByLocalPlayer(billboardGui) then
				local incomePerMinute = parseIncomePerMinute(incomeText.Text)
				animateCashBill(layer, tracker)
				task.wait(getSpawnInterval(incomePerMinute))
			else
				task.wait(0.5)
			end
		end
	end)
end

local function scanIncomeLabels()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BillboardGui") and descendant.Name == "IncomeLabel" then
			trackIncomeLabel(descendant)
		end
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BillboardGui") and descendant.Name == "IncomeLabel" then
		task.defer(trackIncomeLabel, descendant)
	end
end)

scanIncomeLabels()

while true do
	task.wait(LABEL_SCAN_INTERVAL)
	scanIncomeLabels()
end
