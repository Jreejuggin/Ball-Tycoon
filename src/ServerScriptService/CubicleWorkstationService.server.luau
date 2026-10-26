--[[
	CubicleWorkstationService
	Runs every second-floor workstation on every plot: the cubicles and the
	office hierarchy after them (Senior Workers, Team Lead meeting room,
	Department Manager office). Handles purchase, level upgrades, the workers at
	each unit, and timed income. SecondFloorService / SecondFloorOfficeBuilder
	build the units; this script only adds behaviour.

	Follows the first floor's machine conventions:
	  * Price / Activated / UpgradeLevel values inside each unit, so
	    TycoonProgressService saves, restores and resets them with no changes.
	  * Ghost -> Purchased visuals and green/red affordability on the pads.
	  * Income works like the Orbital Reactor: BaseIncomePerMinute paid out every
	    CycleSeconds to the plot owner, scaled by level (CubicleLevels).

	Unlock order (a corporate ladder):
	  * Cubicles mirror the dropper rows: Cubicle1 first; upgrading it to level 2
	    reveals Cubicles 2-5; buying all of 1-5 reveals 6-10.
	  * Each office tier (Config.OfficeTiers, in order) opens once every unit of
	    the tier before it is bought. Inside a tier, units open one at a time.

	Everything is server-side; the client only plays cosmetic worker motion.
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

-- Tier list, in unlock order. The cubicles come first; the office tiers follow
-- in the order SecondFloorConfig lists them.
local TIERS = {
	{
		key = "Cubicles",
		folder = "Cubicles",
		label = "Computer Worker",
		upgradePrice = Config.CubicleUpgradePrice,
		isCubicles = true,
	},
}
for _, officeTier in ipairs(Config.OfficeTiers) do
	table.insert(TIERS, {
		key = officeTier.key,
		folder = officeTier.folder,
		label = officeTier.label,
		upgradePrice = officeTier.upgradePrice,
		isCubicles = false,
	})
end

local warnedMissingTemplates = {}

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
-- Unit records
---------------------------------------------------------------------------

local function makeRecord(unit, tier, tierIndex)
	local geometry = unit:FindFirstChild("Geometry")
	local parts = {}
	local surfaceGuis = {}
	if geometry then
		for _, descendant in ipairs(geometry:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			elseif descendant:IsA("SurfaceGui") then
				table.insert(surfaceGuis, descendant)
			end
		end
	end
	local screen = geometry and geometry:FindFirstChild("Screen")

	local spots = {}
	local spotFolder = unit:FindFirstChild("WorkerSpots")
	if spotFolder then
		for _, spot in ipairs(spotFolder:GetChildren()) do
			if spot:IsA("BasePart") then
				table.insert(spots, spot)
			end
		end
	end

	return {
		model = unit,
		tier = tier,
		tierIndex = tierIndex,
		index = unit:GetAttribute("Order") or 0,
		activated = unit:FindFirstChild("Activated"),
		level = unit:FindFirstChild("UpgradeLevel"),
		price = unit:FindFirstChild("Price"),
		baseIncome = unit:FindFirstChild("BaseIncomePerMinute"),
		cycleSeconds = unit:FindFirstChild("CycleSeconds"),
		buyPad = unit:FindFirstChild("BuyPad"),
		upgradePad = unit:FindFirstChild("UpgradePad"),
		screen = screen,
		incomeLabel = screen and screen:FindFirstChild("IncomeLabel"),
		parts = parts,
		surfaceGuis = surfaceGuis,
		spots = spots,
		state = nil,
		geometryMode = nil,
		workers = {},
		workersSpawned = false,
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
			part.Transparency = math.max(part:GetAttribute("SolidTransparency") or 0, Config.GhostTransparency)
			part.CanCollide = false
		else
			part.Transparency = 1
			part.CanCollide = false
		end
	end
	-- Signs, whiteboard and TV text only show once the unit is bought.
	for _, gui in ipairs(record.surfaceGuis) do
		gui.Enabled = mode == "Solid"
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
-- Workers
---------------------------------------------------------------------------

-- Clones a worker template with its behaviour scripts removed. The root stays
-- anchored; motion is cosmetic and client-side.
local function cloneWorker(templateName)
	local template = workerTemplates:FindFirstChild(templateName)
	if not template then
		if not warnedMissingTemplates[templateName] then
			warnedMissingTemplates[templateName] = true
			warn("[CubicleWorkstationService] Missing worker template: " .. tostring(templateName))
		end
		return nil
	end

	local worker = template:Clone()
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
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	root.Transparency = 1
	return worker, humanoid, root
end

-- Root height above the floor for a standing rig, either rig type.
local function getStandingRootHeight(humanoid, root)
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 3
end

-- Bends an R15 rig into a seated pose (thighs forward, shins down) and
-- returns the root height that rests the thighs on a seat of `seatHeight`.
-- Joint C0s replicate to clients. Returns nil for rigs it can't pose (R6),
-- so those workers stand instead.
local function poseSeated(worker, humanoid, seatHeight)
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local rootJoint = worker:FindFirstChild("Root", true)
	local leftHip = worker:FindFirstChild("LeftHip", true)
	local rightHip = worker:FindFirstChild("RightHip", true)
	local leftKnee = worker:FindFirstChild("LeftKnee", true)
	local rightKnee = worker:FindFirstChild("RightKnee", true)
	local upperLeg = worker:FindFirstChild("LeftUpperLeg")
	for _, joint in ipairs({ rootJoint, leftHip, rightHip, leftKnee, rightKnee }) do
		if not (joint and joint:IsA("Motor6D")) then
			return nil
		end
	end
	if not (upperLeg and upperLeg:IsA("BasePart")) then
		return nil
	end

	local bend = math.rad(90)
	leftHip.C0 *= CFrame.Angles(bend, 0, 0)
	rightHip.C0 *= CFrame.Angles(bend, 0, 0)
	leftKnee.C0 *= CFrame.Angles(-bend, 0, 0)
	rightKnee.C0 *= CFrame.Angles(-bend, 0, 0)

	-- Hip joint height relative to the root, through the root joint.
	local hipOffset = rootJoint.C0.Y - rootJoint.C1.Y + leftHip.C0.Y
	-- A horizontal thigh's underside sits half its thickness below the hip.
	return seatHeight - hipOffset + upperLeg.Size.Z / 2
end

-- Places a worker so its root lands on `rootCFrame`, whatever the model pivot.
local function placeWorker(worker, root, rootCFrame)
	local rootOffset = worker:GetPivot():ToObjectSpace(root.CFrame)
	worker:PivotTo(rootCFrame * rootOffset:Inverse())
end

-- Office units: one worker per WorkerSpot marker.
local function spawnSpotWorker(record, spot)
	local worker, humanoid, root = cloneWorker(spot:GetAttribute("Template") or Config.WorkerTemplateName)
	if not worker then
		return
	end
	worker.Name = "OfficeWorker"

	local rootHeight
	if spot:GetAttribute("Pose") == "Sit" then
		rootHeight = poseSeated(worker, humanoid, spot:GetAttribute("SeatHeight") or Config.SeatHeight)
	end
	rootHeight = rootHeight or getStandingRootHeight(humanoid, root)

	-- The marker's look vector is the facing direction; its Y is the floor.
	placeWorker(worker, root, spot.CFrame * CFrame.new(0, rootHeight, 0))
	CollectionService:AddTag(worker, spot:GetAttribute("Tag") or Config.TypingWorkerTag)
	worker.Parent = record.model
	table.insert(record.workers, worker)
end

-- Cubicles: one standing worker at the desk (their original layout).
local function spawnCubicleWorker(record)
	local frame = record.model:GetAttribute("CubicleFrame")
	if typeof(frame) ~= "CFrame" then
		return
	end
	local worker, humanoid, root = cloneWorker(Config.WorkerTemplateName)
	if not worker then
		return
	end
	worker.Name = "ComputerWorker"

	local standPosition = Vector3.new(Config.WorkerStandX, getStandingRootHeight(humanoid, root), 0)
	placeWorker(worker, root, frame * CFrame.lookAt(standPosition, standPosition + Vector3.xAxis))
	CollectionService:AddTag(worker, Config.TypingWorkerTag)
	worker.Parent = record.model
	table.insert(record.workers, worker)
end

local function spawnWorkers(record)
	record.workersSpawned = true
	if #record.spots > 0 then
		for _, spot in ipairs(record.spots) do
			spawnSpotWorker(record, spot)
		end
	else
		spawnCubicleWorker(record)
	end
end

local function despawnWorkers(record)
	for _, worker in ipairs(record.workers) do
		worker:Destroy()
	end
	table.clear(record.workers)
	record.workersSpawned = false
end

---------------------------------------------------------------------------
-- Per-plot logic
---------------------------------------------------------------------------

local function setupPlot(plot)
	local secondFloor = plot:FindFirstChild("SecondFloor")
	local floorActivated = secondFloor and secondFloor:FindFirstChild("Activated")
	if not (floorActivated and secondFloor:FindFirstChild("Cubicles")) then
		warn("[CubicleWorkstationService] " .. plot.Name .. " has no second-floor cubicles.")
		return
	end

	-- recordsByTier[i] holds tier i's units, sorted by Order.
	local records = {}
	local recordsByTier = {}
	for tierIndex, tier in ipairs(TIERS) do
		local tierRecords = {}
		local folder = secondFloor:FindFirstChild(tier.folder)
		if folder then
			for _, unit in ipairs(folder:GetChildren()) do
				if unit:IsA("Model") then
					local record = makeRecord(unit, tier, tierIndex)
					if isRecordComplete(record) then
						table.insert(tierRecords, record)
						table.insert(records, record)
					else
						warn("[CubicleWorkstationService] Incomplete unit: " .. unit:GetFullName())
					end
				end
			end
		elseif not tier.isCubicles then
			warn("[CubicleWorkstationService] " .. plot.Name .. " has no " .. tier.folder .. ".")
		end
		table.sort(tierRecords, function(a, b)
			return a.index < b.index
		end)
		recordsByTier[tierIndex] = tierRecords
	end

	local rowSize = Config.CubicleRowSize

	local function isTierComplete(tierIndex)
		local tierRecords = recordsByTier[tierIndex]
		if not tierRecords or #tierRecords == 0 then
			return false
		end
		for _, record in ipairs(tierRecords) do
			if not record.activated.Value then
				return false
			end
		end
		return true
	end

	-- Cubicles mirror the dropper rows: 1 first; 1 at level 2 opens the rest of
	-- row 1; buying all of row 1 opens row 2.
	local function isCubicleUnlocked(record)
		local cubicles = recordsByTier[record.tierIndex]
		if record.index <= 1 then
			return true
		end
		local first = cubicles[1]
		if record.index <= rowSize then
			return first ~= nil and first.activated.Value and first.level.Value >= 2
		end
		for i = 1, math.min(rowSize, #cubicles) do
			if not cubicles[i].activated.Value then
				return false
			end
		end
		return true
	end

	-- Office tiers: the whole previous tier bought, then one unit at a time.
	local function isOfficeUnlocked(record)
		if not isTierComplete(record.tierIndex - 1) then
			return false
		end
		local tierRecords = recordsByTier[record.tierIndex]
		local position = table.find(tierRecords, record)
		if not position or position == 1 then
			return true
		end
		return tierRecords[position - 1].activated.Value
	end

	local function isUnlocked(record)
		if record.tier.isCubicles then
			return isCubicleUnlocked(record)
		end
		return isOfficeUnlocked(record)
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
				despawnWorkers(record)
				record.incomeTimer = 0
			end
		end
		if state == "Purchased" and not record.workersSpawned then
			spawnWorkers(record)
		end

		local cash = getCash(getOwnerPlayer(plot))
		local level = getLevel(record)
		updatePad(record.buyPad, state == "Available", record.price.Value, cash, record.tier.label)
		local canUpgrade = state == "Purchased"
			and level < MAX_LEVEL
			and os.clock() >= record.upgradeCooldownUntil
		updatePad(record.upgradePad, canUpgrade, record.tier.upgradePrice, cash, "Upgrade to Lvl " .. tostring(level + 1))
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
		if record.workers[1] then
			PurchaseSoundModule.PlayWorkerSpawn(player, record.workers[1])
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

		local price = record.tier.upgradePrice
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
