--[[
	ManagerCenterService
	Runs floor 2's Manager Center on every plot. It is floor 1's Worker Centre
	for the office floor, and works the same way:

	  * One supervisor pad (same spot as floor 1's worker pad) sells one
	    supervisor per office section, in the order of
	    SecondFloorConfig.SupervisorStages. A supervisor can only be bought once
	    their whole section is bought, like floor 1's workers and their machine
	    sections. Green/red/locked pad, owner + cash checks, a cooldown after
	    each purchase, celebration only on a live purchase.
	  * A Productivity Training pad (same spot as floor 1's Worker Speed pad)
	    raises the bonus every hired supervisor gives, levels 1-5.

	A hired supervisor stands at their section in a suit and makes those
	employees work faster: CubicleWorkstationService multiplies that section's
	cash per minute by SupervisorBonus.GetMultiplier. No other section, floor
	or player is affected.

	Purchases are BoolValues in the centre's WorkerActivations folder and the
	training level is an UpgradeLevel, so TycoonProgressService saves, restores
	and resets them with no changes. Everything here is server-side.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ServerScriptService:WaitForChild("SecondFloorConfig"))
local OfficeAttire = require(ServerScriptService:WaitForChild("OfficeAttire"))
local SupervisorBonus = require(ServerScriptService:WaitForChild("SupervisorBonus"))
local PurchaseEffectModule = require(ReplicatedStorage:WaitForChild("PurchaseEffectModule"))
local PurchaseSoundModule = require(ReplicatedStorage:WaitForChild("PurchaseSoundModule"))

local workerTemplates = ServerStorage:WaitForChild("WorkerTemplates")

local COLOR_GREEN = Color3.new(0, 1, 0)
local COLOR_RED = Color3.new(0.8, 0.1, 0.1)
local UPDATE_INTERVAL_SECONDS = 0.5
local TRAINING_COOLDOWN_SECONDS = 1.5
local SUPERVISOR_TAG = "SupervisorWorker" -- must match TypingWorkerClient
local RESTORING_PROGRESS_ATTR = "RestoringProgress" -- set by TycoonProgressService
local MAX_TRAINING_LEVEL = #Config.ProductivityTrainingLevels

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

-- 1.5 -> "x1.5", 1.75 -> "x1.75", 2 -> "x2"
local function formatMultiplier(multiplier)
	local text = string.format("x%.2f", multiplier)
	text = string.gsub(text, "0$", "")
	text = string.gsub(text, "%.0?$", "")
	return text
end

local function findChildPath(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

-- Shows or hides one of the copied floor-1 pads and fills its two labels.
-- `nameLabel` / `nameTextName` are the floor-1 pad's own label names.
local function updatePad(pad, visible, price, ownerCash, nameLabelName, nameText)
	pad.Transparency = visible and 0.5 or 1
	pad.CanTouch = visible
	for _, child in ipairs(pad:GetChildren()) do
		if child:IsA("BillboardGui") then
			child.Enabled = visible
		end
	end
	if not visible then
		return
	end

	local affordable = price == 0 or (ownerCash ~= nil and ownerCash.Value >= price)
	local color = affordable and COLOR_GREEN or COLOR_RED
	pad.Color = color
	local priceText = findChildPath(pad, "PriceLabel", "PriceText")
	if priceText then
		priceText.Text = price == 0 and "FREE" or ("$" .. tostring(price))
		priceText.TextColor3 = color
	end
	local nameLabel = pad:FindFirstChild(nameLabelName)
	local label = nameLabel and nameLabel:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = nameText
	end
end

---------------------------------------------------------------------------
-- Supervisor NPCs
---------------------------------------------------------------------------

-- Name tag above a supervisor, like floor 1's worker LevelLabel.
local function setNameTag(supervisor, title, multiplier)
	local head = supervisor:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local tag = head:FindFirstChild("SupervisorLabel")
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "SupervisorLabel"
		tag.Adornee = head
		tag.AlwaysOnTop = true
		tag.Size = UDim2.new(7, 0, 1.6, 0)
		tag.StudsOffset = Vector3.new(0, 2.9, 0)
		tag.LightInfluence = 0
		tag.MaxDistance = 120
		tag.Parent = head

		local function addText(name, y, height, color)
			local label = Instance.new("TextLabel")
			label.Name = name
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(0, y)
			label.Size = UDim2.fromScale(1, height)
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.TextColor3 = color
			label.TextStrokeColor3 = Color3.new(0, 0, 0)
			label.TextStrokeTransparency = 0
			label.Parent = tag
		end
		addText("Title", 0, 0.55, Color3.fromRGB(255, 255, 255))
		addText("Bonus", 0.58, 0.42, Color3.fromRGB(110, 255, 75))
	end
	tag.Title.Text = title
	tag.Bonus.Text = formatMultiplier(multiplier) .. " productivity"
end

-- Clones the template, strips its behaviour, dresses it in a suit with a
-- clipboard, and stands it at its section facing the employees.
local function spawnSupervisor(plot, stage, floorY, parent)
	local template = workerTemplates:FindFirstChild(Config.SupervisorTemplateName)
	if not template then
		warn("[ManagerCenterService] Missing worker template: " .. tostring(Config.SupervisorTemplateName))
		return nil
	end
	local floor = plot:FindFirstChild("Floor")
	if not (floor and floor:IsA("BasePart")) then
		return nil
	end

	local supervisor = template:Clone()
	supervisor.Name = stage.key
	for _, descendant in ipairs(supervisor:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	local humanoid = supervisor:FindFirstChildOfClass("Humanoid")
	local root = supervisor:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		supervisor:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	root.Transparency = 1

	OfficeAttire.Dress(supervisor, Config.SupervisorOutfit)
	OfficeAttire.AddClipboard(supervisor)

	-- Plot-local spot -> world, on floor 2, facing the section.
	local rootHeight = humanoid.RigType == Enum.HumanoidRigType.R15
		and (humanoid.HipHeight + root.Size.Y / 2)
		or 3
	local worldSpot = floor.CFrame:PointToWorldSpace(Vector3.new(stage.position.X, 0, stage.position.Z))
	local position = Vector3.new(worldSpot.X, floorY + rootHeight, worldSpot.Z)
	local facing = floor.CFrame:VectorToWorldSpace(stage.facing)
	facing = Vector3.new(facing.X, 0, facing.Z).Unit
	local rootOffset = supervisor:GetPivot():ToObjectSpace(root.CFrame)
	supervisor:PivotTo(CFrame.lookAt(position, position + facing) * rootOffset:Inverse())

	supervisor:SetAttribute("SupervisorSection", stage.section)
	CollectionService:AddTag(supervisor, SUPERVISOR_TAG)
	setNameTag(supervisor, stage.displayName, SupervisorBonus.GetTrainingMultiplier(plot))
	supervisor.Parent = parent
	return supervisor
end

local function playSupervisorEffect(supervisor)
	local parts = {}
	for _, descendant in ipairs(supervisor:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			table.insert(parts, descendant)
		end
	end
	-- Let the new character render first, like floor 1's workers.
	task.delay(0.1, function()
		local root = supervisor:FindFirstChild("HumanoidRootPart")
		if root then
			PurchaseEffectModule.Play(root.Position + Vector3.new(0, 2.5, 0))
		end
		if #parts > 0 then
			PurchaseEffectModule.PlayAcrossParts(parts)
		end
	end)
end

---------------------------------------------------------------------------
-- Per-plot logic
---------------------------------------------------------------------------

local function setupPlot(plot)
	local secondFloor = plot:FindFirstChild("SecondFloor")
	local floorActivated = secondFloor and secondFloor:FindFirstChild("Activated")
	local centre = findChildPath(secondFloor, "CentreSlots", "Centre01_Worker")
	local centreActivated = centre and centre:FindFirstChild("Activated")
	local activations = centre and centre:FindFirstChild("WorkerActivations")
	local supervisorPad = findChildPath(centre, "Upgrades", "SupervisorBuyPad")
	local trainingPad = findChildPath(centre, "Upgrades", "ProductivityTraining", "BuyPad")
	local trainingLevel = findChildPath(centre, "Upgrades", "ProductivityTraining", "UpgradeLevel")
	local supervisorFolder = centre and centre:FindFirstChild("Supervisors")
	if not (floorActivated and centreActivated and activations and supervisorPad and trainingPad and trainingLevel and supervisorFolder) then
		warn("[ManagerCenterService] " .. plot.Name .. " has no complete Manager Center.")
		return
	end
	local signText = findChildPath(centre, Config.LayoutFolderName, "TrainingSign", "LayoutText", "Text")
	local floorY = supervisorPad.Position.Y - supervisorPad.Size.Y / 2

	local stageValues = {}
	for _, stage in ipairs(Config.SupervisorStages) do
		stageValues[stage] = activations:FindFirstChild(stage.key)
	end

	local supervisors = {} -- [stage] = model
	local lastHired = {} -- [stage] = bool, so restores stay quiet
	local processing = false
	local supervisorCooldownUntil = 0
	local trainingCooldownUntil = 0
	local lastTrainingMultiplier = nil

	local function isCentrePurchased()
		return floorActivated.Value and centreActivated.Value
	end

	local function isHired(stage)
		local value = stageValues[stage]
		return value ~= nil and value.Value
	end

	-- Every unit of the stage's section bought (within its Order range).
	local function isSectionComplete(stage)
		local folder = secondFloor:FindFirstChild(stage.folder)
		if not folder then
			return false
		end
		local found = 0
		for _, unit in ipairs(folder:GetChildren()) do
			local order = unit:GetAttribute("Order")
			local inRange = not stage.orders
				or (order ~= nil and order >= stage.orders[1] and order <= stage.orders[2])
			if inRange then
				local activated = unit:FindFirstChild("Activated")
				if not (activated and activated.Value) then
					return false
				end
				found += 1
			end
		end
		return found > 0
	end

	-- Like floor 1: the first unhired supervisor whose section is complete.
	local function getPurchasableStage()
		if not isCentrePurchased() then
			return nil
		end
		for _, stage in ipairs(Config.SupervisorStages) do
			if not isHired(stage) and isSectionComplete(stage) then
				return stage
			end
		end
		return nil
	end

	local function syncSupervisors()
		local restoring = plot:GetAttribute(RESTORING_PROGRESS_ATTR) == true
		for _, stage in ipairs(Config.SupervisorStages) do
			local hired = isHired(stage) and isCentrePurchased()
			local model = supervisors[stage]
			if hired and not (model and model.Parent) then
				model = spawnSupervisor(plot, stage, floorY, supervisorFolder)
				supervisors[stage] = model
				if model and lastHired[stage] == false and not restoring then
					playSupervisorEffect(model)
				end
			elseif not hired and model then
				model:Destroy()
				supervisors[stage] = nil
			end
			lastHired[stage] = hired
		end
	end

	local function updateTrainingDisplays()
		local level = SupervisorBonus.GetTrainingLevel(plot)
		local multiplier = Config.ProductivityTrainingLevels[level].multiplier
		if multiplier == lastTrainingMultiplier then
			return
		end
		lastTrainingMultiplier = multiplier
		if signText then
			signText.Text = string.format("PRODUCTIVITY TRAINING\nLvl %d  -  %s", level, formatMultiplier(multiplier))
		end
		for stage, model in pairs(supervisors) do
			if model.Parent then
				setNameTag(model, stage.displayName, multiplier)
			end
		end
	end

	local function updateState()
		syncSupervisors()
		updateTrainingDisplays()

		local cash = getCash(getOwnerPlayer(plot))
		local now = os.clock()

		local stage = getPurchasableStage()
		local showSupervisor = stage ~= nil and now >= supervisorCooldownUntil and not processing
		updatePad(supervisorPad, showSupervisor, stage and stage.price or 0, cash, "WorkerLabel", stage and stage.displayName or "")

		local level = trainingLevel.Value
		local nextLevel = Config.ProductivityTrainingLevels[level + 1]
		local showTraining = isCentrePurchased() and nextLevel ~= nil and now >= trainingCooldownUntil
		updatePad(trainingPad, showTraining, nextLevel and nextLevel.cost or 0, cash, "UpgradeLabel", "Productivity Lv. " .. tostring(level + 1))
	end

	supervisorPad.Touched:Connect(function(hit)
		if processing or os.clock() < supervisorCooldownUntil then
			return
		end
		local stage = getPurchasableStage()
		if not stage then
			return
		end
		local player = getPlayerFromHit(hit)
		if not player or getOwnerPlayer(plot) ~= player then
			return
		end
		local cash = getCash(player)
		if stage.price > 0 and (not cash or cash.Value < stage.price) then
			return
		end

		-- Lock before charging, so repeated touches cannot charge twice.
		processing = true
		if stage.price > 0 then
			cash.Value -= stage.price
		end
		-- Mark the change as handled first, so this live purchase owns the
		-- one celebration and syncSupervisors does not replay it.
		lastHired[stage] = true
		stageValues[stage].Value = true
		local supervisor = spawnSupervisor(plot, stage, floorY, supervisorFolder)
		supervisors[stage] = supervisor
		local soundTarget = supervisor or supervisorPad
		PurchaseSoundModule.PlayPurchaseForTarget(player, soundTarget)
		PurchaseSoundModule.PlayWorkerSpawn(player, soundTarget)
		if supervisor then
			playSupervisorEffect(supervisor)
		end
		local allHired = true
		for _, other in ipairs(Config.SupervisorStages) do
			if not isHired(other) then
				allHired = false
			end
		end
		if allHired then
			PurchaseSoundModule.PlayAreaUnlocked(player, soundTarget)
		end

		supervisorCooldownUntil = os.clock() + Config.SupervisorPurchaseCooldownSeconds
		processing = false
		updateState()
	end)

	trainingPad.Touched:Connect(function(hit)
		if processing or os.clock() < trainingCooldownUntil or not isCentrePurchased() then
			return
		end
		local level = trainingLevel.Value
		local nextLevel = Config.ProductivityTrainingLevels[level + 1]
		if not nextLevel or level >= MAX_TRAINING_LEVEL then
			return
		end
		local player = getPlayerFromHit(hit)
		if not player or getOwnerPlayer(plot) ~= player then
			return
		end
		local cash = getCash(player)
		if nextLevel.cost > 0 and (not cash or cash.Value < nextLevel.cost) then
			return
		end

		processing = true
		if nextLevel.cost > 0 then
			cash.Value -= nextLevel.cost
		end
		trainingLevel.Value = level + 1
		-- The pad hides during the cooldown, so standing on it can't chain upgrades.
		trainingCooldownUntil = os.clock() + TRAINING_COOLDOWN_SECONDS
		processing = false
		updateState()

		PurchaseSoundModule.PlayPurchaseForTarget(player, trainingPad)
		PurchaseEffectModule.Play(trainingPad.Position + Vector3.new(0, 1.4, 0))
	end)

	for _, stage in ipairs(Config.SupervisorStages) do
		lastHired[stage] = isHired(stage) and isCentrePurchased()
	end
	updateState()
	task.spawn(function()
		while plot.Parent do
			task.wait(UPDATE_INTERVAL_SECONDS)
			updateState()
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
