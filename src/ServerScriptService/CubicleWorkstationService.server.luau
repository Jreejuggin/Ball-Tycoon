--[[
	CubicleWorkstationService
	Runs the second floor's cubicles on every plot: purchase, level upgrades, the
	computer worker at each desk, and timed income. SecondFloorService builds the
	cubicles; this script only adds behaviour.

	Follows the first floor's machine conventions:
	  * Price / Activated / UpgradeLevel values inside each cubicle, so
	    TycoonProgressService saves, restores and resets them with no changes.
	  * Ghost -> Purchased visuals and green/red affordability on the pads.
	  * Unlock order mirrors the dropper rows: Cubicle1 first; upgrading it to
	    level 2 reveals Cubicles 2-5; buying all of 1-5 reveals 6-10.
	  * Income works like the Orbital Reactor: BaseIncomePerMinute paid out every
	    CycleSeconds to the plot owner, scaled by level.
	Everything is server-side; the client only plays the cosmetic typing motion.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ServerScriptService:WaitForChild("SecondFloorConfig"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local workerTemplates = ServerStorage:WaitForChild("WorkerTemplates")

local COLOR_GREEN = Color3.new(0, 1, 0)
local COLOR_RED = Color3.new(0.8, 0.1, 0.1)
local UPDATE_INTERVAL_SECONDS = 0.5
local MAX_LEVEL = #Config.CubicleLevels

local warnedMissingTemplate = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function getOwnerPlayer(plot)
	local ownerId = tonumber(plot:GetAttribute("Owner"))
	return ownerId and Players:GetPlayerByUserId(ownerId) or nil
end

local function getCash(player)
	local leaderstats = player and player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Cash")
end

local function getPlayerFromHit(hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character) or nil
end

local function formatMoney(amount)
	local text = tostring(math.floor(amount + 0.5))
	local left, number, right = string.match(text, "^([^%d]*%d)(%d*)(.-)$")
	if not left then
		return text
	end
	return left .. (number:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local function setBillboardsEnabled(part, enabled)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("BillboardGui") then
			child.Enabled = enabled
		end
	end
end

local function setLabelText(pad, labelName, text)
	local gui = pad:FindFirstChild(labelName)
	if not gui then
		return
	end
	for _, label in ipairs(gui:GetDescendants()) do
		if label:IsA("TextLabel") then
			label.Text = text
		end
	end
end

-- Shows or hides a pad, colored green/red by whether the owner can afford it.
local function updatePad(pad, visible, price, ownerCash, nameText)
	pad.Transparency = visible and 0.5 or 1
	pad.CanTouch = visible
	setBillboardsEnabled(pad, visible)
	if not visible then
		return
	end

	local affordable = price == 0 or (ownerCash ~= nil and ownerCash.Value >= price)
	local color = affordable and COLOR_GREEN or COLOR_RED
	pad.Color = color
	local priceLabel = pad:FindFirstChild("PriceLabel")
	local priceText = priceLabel and priceLabel:FindFirstChild("PriceText")
	if priceText then
		priceText.Text = price == 0 and "FREE" or ("$" .. formatMoney(price))
		priceText.TextColor3 = color
	end
	setLabelText(pad, "DropperLabel", nameText)
end

---------------------------------------------------------------------------
-- Cubicle records
---------------------------------------------------------------------------

local function makeRecord(cubicle)
	local geometry = cubicle:FindFirstChild("Geometry")
	local parts = {}
	if geometry then
		for _, descendant in ipairs(geometry:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	local screen = geometry and geometry:FindFirstChild("Screen")

	return {
		model = cubicle,
		index = cubicle:GetAttribute("Order") or 0,
		activated = cubicle:FindFirstChild("Activated"),
		level = cubicle:FindFirstChild("UpgradeLevel"),
		price = cubicle:FindFirstChild("Price"),
		baseIncome = cubicle:FindFirstChild("BaseIncomePerMinute"),
		cycleSeconds = cubicle:FindFirstChild("CycleSeconds"),
		buyPad = cubicle:FindFirstChild("BuyPad"),
		upgradePad = cubicle:FindFirstChild("UpgradePad"),
		screen = screen,
		incomeLabel = screen and screen:FindFirstChild("IncomeLabel"),
		parts = parts,
		state = nil,
		geometryMode = nil,
		worker = nil,
		processing = false,
		upgradeCooldownUntil = 0,
		incomeTimer = 0,
	}
end

local function isRecordComplete(record)
	return record.activated and record.level and record.price and record.baseIncome
		and record.cycleSeconds and record.buyPad and record.upgradePad
end

local function getLevel(record)
	return math.clamp(record.level.Value, 1, MAX_LEVEL)
end

local function getIncomePerMinute(record)
	return record.baseIncome.Value * Config.CubicleLevels[getLevel(record)].multiplier
end

local function setGeometry(record, mode)
	if record.geometryMode == mode then
		return
	end
	record.geometryMode = mode
	for _, part in ipairs(record.parts) do
		if mode == "Solid" then
			part.Transparency = part:GetAttribute("SolidTransparency") or 0
			part.CanCollide = part:GetAttribute("SolidCanCollide") ~= false
		elseif mode == "Ghost" then
			part.Transparency = Config.GhostTransparency
			part.CanCollide = false
		else
			part.Transparency = 1
			part.CanCollide = false
		end
	end
end

local function updateLabels(record, purchased)
	local label = record.incomeLabel
	if label then
		label.Enabled = purchased
		if purchased then
			local incomeText = label:FindFirstChild("IncomeText")
			local levelText = label:FindFirstChild("LevelText")
			if incomeText then
				incomeText.Text = "💵 $" .. formatMoney(getIncomePerMinute(record)) .. "/min"
			end
			if levelText then
				levelText.Text = "Lvl " .. tostring(getLevel(record))
			end
		end
	end
	if record.screen then
		record.screen.Color = Config.CubicleLevels[getLevel(record)].screenColor
	end
end

---------------------------------------------------------------------------
-- Computer workers
---------------------------------------------------------------------------

-- Clones a worker rig, strips its behaviour scripts, and stands it at the desk
-- facing the monitor. The root is anchored; the typing motion is client-side.
local function spawnWorker(record)
	local template = workerTemplates:FindFirstChild(Config.WorkerTemplateName)
	if not template then
		if not warnedMissingTemplate then
			warnedMissingTemplate = true
			warn("[CubicleWorkstationService] Missing worker template: " .. Config.WorkerTemplateName)
		end
		return
	end

	local frame = record.model:GetAttribute("CubicleFrame")
	if typeof(frame) ~= "CFrame" then
		return
	end

	local worker = template:Clone()
	worker.Name = "ComputerWorker"
	for _, descendant in ipairs(worker:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	local humanoid = worker:FindFirstChildOfClass("Humanoid")
	local root = worker:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		worker:Destroy()
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	root.Transparency = 1

	-- Root height that puts the feet on the floor, for either rig type.
	local rootHeight = humanoid.RigType == Enum.HumanoidRigType.R15
		and (humanoid.HipHeight + root.Size.Y / 2)
		or 3
	local standPosition = Vector3.new(Config.WorkerStandX, rootHeight, 0)
	local target = frame * CFrame.lookAt(standPosition, standPosition + Vector3.xAxis)

	-- Move the whole rig so the root lands on target, whatever the model's pivot.
	local rootOffset = worker:GetPivot():ToObjectSpace(root.CFrame)
	worker:PivotTo(target * rootOffset:Inverse())

	CollectionService:AddTag(worker, Config.TypingWorkerTag)
	worker.Parent = record.model
	record.worker = worker
end

local function despawnWorker(record)
	if record.worker then
		record.worker:Destroy()
		record.worker = nil
	end
end

---------------------------------------------------------------------------
-- Per-plot logic
---------------------------------------------------------------------------

local function setupPlot(plot)
	local secondFloor = plot:FindFirstChild("SecondFloor")
	local floorActivated = secondFloor and secondFloor:FindFirstChild("Activated")
	local cubicleFolder = secondFloor and secondFloor:FindFirstChild("Cubicles")
	if not (floorActivated and cubicleFolder) then
		warn("[CubicleWorkstationService] " .. plot.Name .. " has no second-floor cubicles.")
		return
	end

	local records = {}
	for _, cubicle in ipairs(cubicleFolder:GetChildren()) do
		local record = makeRecord(cubicle)
		if isRecordComplete(record) then
			table.insert(records, record)
		else
			warn("[CubicleWorkstationService] Incomplete cubicle: " .. cubicle:GetFullName())
		end
	end
	table.sort(records, function(a, b)
		return a.index < b.index
	end)

	local rowSize = Config.CubicleRowSize

	-- Mirrors the dropper rows: 1 first; 1 at level 2 opens the rest of row 1;
	-- buying all of row 1 opens row 2.
	local function isUnlocked(record)
		if record.index <= 1 then
			return true
		end
		local first = records[1]
		if record.index <= rowSize then
			return first ~= nil and first.activated.Value and first.level.Value >= 2
		end
		for i = 1, math.min(rowSize, #records) do
			if not records[i].activated.Value then
				return false
			end
		end
		return true
	end

	local function getState(record)
		if not floorActivated.Value then
			return "Hidden"
		end
		if record.activated.Value then
			return "Purchased"
		end
		if isUnlocked(record) then
			return "Available"
		end
		return "Hidden"
	end

	local function applyRecord(record, force)
		local state = getState(record)
		if force or state ~= record.state then
			record.state = state
			if state == "Purchased" then
				setGeometry(record, "Solid")
			elseif state == "Available" then
				setGeometry(record, "Ghost")
			else
				setGeometry(record, "Hidden")
			end
			if state ~= "Purchased" then
				despawnWorker(record)
				record.incomeTimer = 0
			end
		end
		if state == "Purchased" and not (record.worker and record.worker.Parent) then
			spawnWorker(record)
		end

		local cash = getCash(getOwnerPlayer(plot))
		local level = getLevel(record)
		updatePad(record.buyPad, state == "Available", record.price.Value, cash, "Computer Worker")
		local canUpgrade = state == "Purchased"
			and level < MAX_LEVEL
			and os.clock() >= record.upgradeCooldownUntil
		updatePad(record.upgradePad, canUpgrade, Config.CubicleUpgradePrice, cash, "Upgrade to Lvl " .. tostring(level + 1))
		updateLabels(record, state == "Purchased")
	end

	local function payIncome(record, deltaTime, owner)
		local cycle = math.max(1, record.cycleSeconds.Value)
		record.incomeTimer += deltaTime
		if record.incomeTimer < cycle then
			return
		end
		record.incomeTimer -= cycle
		local cash = getCash(owner)
		if cash then
			cash.Value += math.floor(getIncomePerMinute(record) * cycle / 60 + 0.5)
		end
	end

	local function onBuyTouched(record, hit)
		if record.processing or record.state ~= "Available" or record.activated.Value then
			return
		end
		local player = getPlayerFromHit(hit)
		if not player or getOwnerPlayer(plot) ~= player then
			return
		end
		if not floorActivated.Value or not isUnlocked(record) then
			return
		end

		local price = record.price.Value
		local cash = getCash(player)
		if price > 0 and (not cash or cash.Value < price) then
			return
		end

		-- Lock before charging, so repeated touches cannot charge twice.
		record.processing = true
		if price > 0 then
			cash.Value -= price
		end
		record.activated.Value = true
		applyRecord(record, true)

		PurchaseSoundModule.PlayPurchaseForTarget(player, record.buyPad)
		if record.worker then
			PurchaseSoundModule.PlayWorkerSpawn(player, record.worker)
		end
		if #record.parts > 0 then
			PurchaseEffectModule.PlayAcrossParts(record.parts)
		end

		task.delay(0.4, function()
			record.processing = false
		end)
	end

	local function onUpgradeTouched(record, hit)
		if record.processing or record.state ~= "Purchased" then
			return
		end
		if os.clock() < record.upgradeCooldownUntil then
			return
		end
		local level = getLevel(record)
		if level >= MAX_LEVEL then
			return
		end
		local player = getPlayerFromHit(hit)
		if not player or getOwnerPlayer(plot) ~= player then
			return
		end

		local price = Config.CubicleUpgradePrice
		local cash = getCash(player)
		if price > 0 and (not cash or cash.Value < price) then
			return
		end

		record.processing = true
		if price > 0 then
			cash.Value -= price
		end
		record.level.Value = level + 1
		-- The pad hides during the cooldown, so standing on it can't chain upgrades.
		record.upgradeCooldownUntil = os.clock() + Config.CubicleUpgradeCooldownSeconds
		applyRecord(record, false)

		PurchaseSoundModule.PlayPurchaseForTarget(player, record.upgradePad)
		if record.screen then
			PurchaseEffectModule.Play(record.screen.Position)
		end
		record.processing = false
	end

	for _, record in ipairs(records) do
		record.buyPad.Touched:Connect(function(hit)
			onBuyTouched(record, hit)
		end)
		record.upgradePad.Touched:Connect(function(hit)
			onUpgradeTouched(record, hit)
		end)
		applyRecord(record, true)
	end

	local lastTick = os.clock()
	task.spawn(function()
		while plot.Parent do
			task.wait(UPDATE_INTERVAL_SECONDS)
			local now = os.clock()
			local deltaTime = now - lastTick
			lastTick = now

			local owner = getOwnerPlayer(plot)
			for _, record in ipairs(records) do
				applyRecord(record, false)
				if record.state == "Purchased" and owner then
					payIncome(record, deltaTime, owner)
				else
					record.incomeTimer = 0
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Startup: wait for SecondFloorService to finish each plot, then run it.
---------------------------------------------------------------------------

for _, plot in ipairs(Workspace:GetChildren()) do
	if plot:IsA("Model") and string.match(plot.Name, "^P%d+$") then
		task.spawn(function()
			while not plot:GetAttribute("SecondFloorBuilt") do
				plot:GetAttributeChangedSignal("SecondFloorBuilt"):Wait()
			end
			setupPlot(plot)
		end)
	end
end
