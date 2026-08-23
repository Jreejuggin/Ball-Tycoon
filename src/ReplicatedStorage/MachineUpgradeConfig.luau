-- MachineUpgradeConfig
-- Shared machine upgrade data. Slot-level UpgradeLevel values are intentionally
-- simple IntValues so future DataStore saving can persist individual machine
-- progress and reapply it to whatever plot the player owns next session.
local MachineUpgradeConfig = {}

local LEVELS = {
	[1] = {
		level = 1,
		name = "Lvl 1",
		ballValue = 5,
		ballColor = Color3.fromRGB(255, 224, 35),
		upgradePrice = 0,
	},
	[2] = {
		level = 2,
		name = "Lvl 2",
		ballValue = 10,
		ballColor = Color3.fromRGB(40, 225, 80),
		upgradePrice = 2500,
	},
	[3] = {
		level = 3,
		name = "Lvl 3",
		ballValue = 20,
		ballColor = Color3.fromRGB(45, 165, 255),
		upgradePrice = 10000,
	},
	[4] = {
		level = 4,
		name = "Lvl 4",
		ballValue = 40,
		ballColor = Color3.fromRGB(175, 75, 255),
		upgradePrice = 35000,
	},
	[5] = {
		level = 5,
		name = "Lvl 5",
		ballValue = 80,
		ballColor = Color3.fromRGB(255, 145, 35),
		upgradePrice = 100000,
	},
}

MachineUpgradeConfig.MaxLevel = #LEVELS
MachineUpgradeConfig.Levels = LEVELS

local DROPPER_BALLS_PER_MINUTE = 60 / 1.5
local DEFAULT_CONVEYOR_BALLS_PER_CRATE = 5
local CONVEYOR_CRATE_INTERVAL_SECONDS = 4

local function clampLevel(level)
	level = tonumber(level) or 1
	return math.clamp(math.floor(level), 1, MachineUpgradeConfig.MaxLevel)
end

local function getSlotBallsPerCrate(slot)
	local value = slot and slot:FindFirstChild("BallsPerCrate")
	if value and value:IsA("IntValue") then
		return math.max(0, value.Value)
	end
	return DEFAULT_CONVEYOR_BALLS_PER_CRATE
end

function MachineUpgradeConfig.GetLevelInfo(level)
	return LEVELS[clampLevel(level)]
end

function MachineUpgradeConfig.GetNextLevelInfo(currentLevel)
	local nextLevel = clampLevel(currentLevel) + 1
	return LEVELS[nextLevel]
end

function MachineUpgradeConfig.EnsureUpgradeLevelValue(levelOwner)
	if not levelOwner then
		return nil
	end
	local value = levelOwner:FindFirstChild("UpgradeLevel")
	if not value then
		value = Instance.new("IntValue")
		value.Name = "UpgradeLevel"
		value.Value = 1
		value.Parent = levelOwner
	elseif not value:IsA("IntValue") then
		return nil
	end
	value.Value = clampLevel(value.Value)
	return value
end

function MachineUpgradeConfig.GetFolderLevel(levelOwner)
	local value = MachineUpgradeConfig.EnsureUpgradeLevelValue(levelOwner)
	return value and clampLevel(value.Value) or 1
end

function MachineUpgradeConfig.SetFolderLevel(levelOwner, level)
	local value = MachineUpgradeConfig.EnsureUpgradeLevelValue(levelOwner)
	if not value then
		return 1
	end
	value.Value = clampLevel(level)
	return value.Value
end

function MachineUpgradeConfig.GetFolderLevelInfo(levelOwner)
	return MachineUpgradeConfig.GetLevelInfo(MachineUpgradeConfig.GetFolderLevel(levelOwner))
end

function MachineUpgradeConfig.GetBallsPerMinute(machineFolder, slot)
	if not machineFolder then
		return DROPPER_BALLS_PER_MINUTE
	end
	if machineFolder.Name:match("^DropperSlots") then
		return DROPPER_BALLS_PER_MINUTE
	end
	return (60 / CONVEYOR_CRATE_INTERVAL_SECONDS) * getSlotBallsPerCrate(slot)
end
function MachineUpgradeConfig.GetBallValueMultiplier(slot)
	local multiplierValue = slot and slot:FindFirstChild("BallValueMultiplier")
	if multiplierValue and multiplierValue:IsA("NumberValue") then
		return multiplierValue.Value
	end
	return 1
end

function MachineUpgradeConfig.GetIncomePerMinute(machineFolder, slot)
	local levelInfo = MachineUpgradeConfig.GetFolderLevelInfo(slot or machineFolder)
	local baseIncome = slot and slot:FindFirstChild("BaseIncomePerMinute")
	if baseIncome and baseIncome:IsA("NumberValue") then
		local baseLevelInfo = MachineUpgradeConfig.GetLevelInfo(1)
		return math.floor(baseIncome.Value * (levelInfo.ballValue / baseLevelInfo.ballValue) + 0.5)
	end
	return math.floor(MachineUpgradeConfig.GetBallsPerMinute(machineFolder, slot) * levelInfo.ballValue * MachineUpgradeConfig.GetBallValueMultiplier(slot) + 0.5)
end

function MachineUpgradeConfig.FormatIncomePerMinute(amount)
	return "💵 $" .. tostring(math.floor(amount + 0.5)) .. "/min"
end

function MachineUpgradeConfig.ApplyBallStats(ball, machineFolder)
	if not ball or not ball:IsA("BasePart") then
		return
	end
	local levelInfo = MachineUpgradeConfig.GetFolderLevelInfo(machineFolder)
	local ballValue = math.floor(levelInfo.ballValue * MachineUpgradeConfig.GetBallValueMultiplier(machineFolder) + 0.5)
	ball.Color = levelInfo.ballColor
	ball.Material = Enum.Material.Neon
	ball:SetAttribute("UpgradeLevel", levelInfo.level)
	ball:SetAttribute("BallValue", ballValue)
	local value = ball:FindFirstChild("Value")
	if value and value:IsA("IntValue") then
		value.Value = ballValue
	end
end

local function ensureLevelText(incomeLabel, levelInfo)
	local levelText = incomeLabel:FindFirstChild("LevelText")
	if not levelText then
		levelText = Instance.new("TextLabel")
		levelText.Name = "LevelText"
		levelText.Parent = incomeLabel
	end
	levelText.BackgroundTransparency = 1
	levelText.Position = UDim2.fromScale(0, 0)
	levelText.Size = UDim2.fromScale(1, 0.42)
	levelText.Text = levelInfo.name
	levelText.TextColor3 = Color3.fromRGB(0, 235, 255)
	levelText.TextStrokeColor3 = Color3.new(0, 0, 0)
	levelText.TextStrokeTransparency = 0
	levelText.Font = Enum.Font.FredokaOne
	levelText.TextScaled = true
	levelText.TextWrapped = true
	levelText.TextXAlignment = Enum.TextXAlignment.Center
	levelText.TextYAlignment = Enum.TextYAlignment.Center
	levelText.ZIndex = 10
	return levelText
end

local function updateIncomeBillboard(incomeLabel, incomeText, incomeTextValue, levelInfo)
	if not incomeLabel or not incomeLabel:IsA("BillboardGui") then
		return
	end
	if not incomeText or not incomeText:IsA("TextLabel") then
		return
	end
	incomeLabel.Size = UDim2.new(5, 0, 1.65, 0)
	incomeText.BackgroundTransparency = 1
	incomeText.Position = UDim2.fromScale(0, 0.38)
	incomeText.Size = UDim2.fromScale(1, 0.62)
	incomeText.Text = incomeTextValue
	incomeText.ZIndex = 10
	ensureLevelText(incomeLabel, levelInfo)
end

local function findMachineModel(slot)
	return slot:FindFirstChild("Dropper") or slot:FindFirstChild("Conveyor") or slot:FindFirstChild("BallPress")
end

local function getBuyPadIncomeText(slot)
	local buyPad = slot:FindFirstChild("BuyPad")
	local head = buyPad and buyPad:FindFirstChild("Head")
	if not head then
		return nil
	end
	local label = head:FindFirstChild("DropperLabel") or head:FindFirstChild("ConveyorLabel") or head:FindFirstChild("BallPressLabel")
	return label and label:FindFirstChild("IncomeText") or nil
end

function MachineUpgradeConfig.ApplyFolderUpgrade(machineFolder)
	if not machineFolder then
		return
	end
	for _, slot in ipairs(machineFolder:GetChildren()) do
		local activated = slot:FindFirstChild("Activated")
		local machine = findMachineModel(slot)
		if activated and machine then
			local levelInfo = MachineUpgradeConfig.GetFolderLevelInfo(slot)
			local incomeTextValue = MachineUpgradeConfig.FormatIncomePerMinute(MachineUpgradeConfig.GetIncomePerMinute(machineFolder, slot))
			local buyPadIncomeText = getBuyPadIncomeText(slot)
			if buyPadIncomeText and buyPadIncomeText:IsA("TextLabel") then
				buyPadIncomeText.Text = incomeTextValue
			end
			local incomeLabel = machine:FindFirstChild("IncomeLabel", true)
			local incomeText = incomeLabel and incomeLabel:FindFirstChild("IncomeText")
			updateIncomeBillboard(incomeLabel, incomeText, incomeTextValue, levelInfo)
		end
	end
end

return MachineUpgradeConfig
