-- TutorialController
-- The first-time tutorial's state machine. Ties together everything the
-- earlier phases built: waits for the player's DataLoaded + TutorialEligible
-- attributes (Phase 1), walks TutorialConfig's step list (Phase 2), drives
-- WelcomePanel and StepPanel (Phase 3), points ArrowIndicator + ArrowTrail
-- at each step's target (Phase 4), and reports progress back to the server
-- over the two tutorial RemoteEvents.
--
-- Step resolution: each step's `target` and `completion` are
-- { root, path } specs -- root says WHERE to start ("Player" or "Plot"),
-- path is a "/"-separated chain of child names walked from there. Both are
-- resolved fresh per step (never cached across steps) since a step's target
-- can be a totally different part of the plot than the last one.
--
-- Async resolution safety: resolving a step's target/completion can yield
-- (WaitForChild, waiting on the plot to be assigned) for real time. A
-- `generation` counter is bumped every time startStep or finish runs, and
-- every yielding branch checks it hasn't changed before touching any
-- state -- so a stale resolution from a step the player already skipped
-- past (or a tutorial that already ended) can't act after the fact.
--
-- Welcome-panel outcomes: Start begins step 0, Skip ends the tutorial, and
-- DismissedExternally (the card being closed out from under us by another
-- panel opening) is treated as Start -- see the comment in Init.
--
-- Usage: TutorialController.Init() -- call once, after DataLoaded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialConfig = require(ReplicatedStorage:WaitForChild("TutorialConfig"))
local ArrowIndicator = require(ReplicatedStorage:WaitForChild("ArrowIndicator"))
local ArrowTrail = require(ReplicatedStorage:WaitForChild("ArrowTrail"))

local WelcomePanel = require(script.Parent:WaitForChild("WelcomePanel"))
local StepPanel = require(script.Parent:WaitForChild("StepPanel"))

local stepEvent = ReplicatedStorage:WaitForChild("TutorialStepEvent")
local completeEvent = ReplicatedStorage:WaitForChild("TutorialCompleteEvent")

local ROOT_WAIT_TIMEOUT = 15 -- seconds to wait for AssignedPlotName to appear
local INSTANCE_WAIT_TIMEOUT = 15 -- seconds to wait for each path segment

local TutorialController = {}

local player = Players.LocalPlayer

local generation = 0
local arrow, trail
local completionCleanup

-- root = "Player" -> the Player instance itself.
-- root = "Plot"   -> the player's assigned plot in Workspace, waiting (up
--                     to ROOT_WAIT_TIMEOUT) for AssignedPlotName to be set
--                     if it isn't yet, since plot assignment and this
--                     controller's startup aren't otherwise ordered against
--                     each other.
local function resolveRoot(rootName)
	if rootName == "Player" then
		return player
	end

	if rootName == "Plot" then
		local plotName = player:GetAttribute("AssignedPlotName")
		if type(plotName) ~= "string" then
			local changedSignal = player:GetAttributeChangedSignal("AssignedPlotName")
			local deadline = os.clock() + ROOT_WAIT_TIMEOUT
			while type(player:GetAttribute("AssignedPlotName")) ~= "string" and os.clock() < deadline do
				changedSignal:Wait()
			end
			plotName = player:GetAttribute("AssignedPlotName")
		end
		if type(plotName) ~= "string" then
			return nil
		end
		return workspace:WaitForChild(plotName, INSTANCE_WAIT_TIMEOUT)
	end

	return nil
end

local function resolvePath(root, path)
	local instance = root
	for segment in string.gmatch(path, "[^/]+") do
		if not instance then
			return nil
		end
		instance = instance:WaitForChild(segment, INSTANCE_WAIT_TIMEOUT)
	end
	return instance
end

-- Shared by `target` and `completion` specs -- both are { root, path }.
local function resolveInstance(spec)
	local root = resolveRoot(spec.root)
	if not root then
		return nil
	end
	return resolvePath(root, spec.path)
end

local function pointMarkersAt(targetInstance)
	if arrow then
		arrow:SetTarget(targetInstance)
	else
		arrow = ArrowIndicator.new(targetInstance)
	end
	if trail then
		trail:SetTarget(targetInstance)
	else
		trail = ArrowTrail.new(targetInstance)
	end
end

local function clearMarkers()
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
	if trail then
		trail:Destroy()
		trail = nil
	end
end

local function stopWatchingCompletion()
	if completionCleanup then
		completionCleanup()
		completionCleanup = nil
	end
end

-- done when valueInstance.Value == true; fires immediately if it's already
-- true by the time the step starts.
local function watchValueTrue(valueInstance, onDone)
	if valueInstance.Value == true then
		task.defer(onDone)
		return function() end
	end

	local connection
	connection = valueInstance:GetPropertyChangedSignal("Value"):Connect(function()
		if valueInstance.Value == true then
			connection:Disconnect()
			onDone()
		end
	end)
	return function()
		connection:Disconnect()
	end
end

-- done when valueInstance.Value rises above whatever it was when the step
-- started (not just "changed" -- a purchase that spends cash would lower
-- it, which should never look like progress).
local function watchValueIncreased(valueInstance, onDone)
	local baseline = valueInstance.Value
	local connection
	connection = valueInstance:GetPropertyChangedSignal("Value"):Connect(function()
		if valueInstance.Value > baseline then
			connection:Disconnect()
			onDone()
		end
	end)
	return function()
		connection:Disconnect()
	end
end

local function finish(wasSkipped)
	generation += 1
	stopWatchingCompletion()
	clearMarkers()
	StepPanel.Hide()
	completeEvent:FireServer(wasSkipped)
end

local function startStep(stepIndex)
	generation += 1
	local myGeneration = generation
	stopWatchingCompletion()

	local stepConfig = TutorialConfig[stepIndex + 1]
	if not stepConfig then
		-- Ran off the end of the list: every step is done.
		finish(false)
		return
	end

	task.spawn(function()
		local targetInstance = resolveInstance(stepConfig.target)
		if myGeneration ~= generation then
			return
		end
		if not targetInstance then
			warn(string.format(
				"[TutorialController] Couldn't resolve target for step '%s' -- skipping it.",
				stepConfig.id
			))
			startStep(stepIndex + 1)
			return
		end

		local completionInstance = resolveInstance(stepConfig.completion)
		if myGeneration ~= generation then
			return
		end
		if not completionInstance then
			warn(string.format(
				"[TutorialController] Couldn't resolve completion target for step '%s' -- skipping it.",
				stepConfig.id
			))
			startStep(stepIndex + 1)
			return
		end

		pointMarkersAt(targetInstance)
		StepPanel.Show(stepConfig)

		local function onStepComplete()
			if myGeneration ~= generation then
				return
			end
			stepEvent:FireServer(stepIndex + 1)
			startStep(stepIndex + 1)
		end

		local completionType = stepConfig.completion.type
		if completionType == "ValueTrue" then
			completionCleanup = watchValueTrue(completionInstance, onStepComplete)
		elseif completionType == "ValueIncreased" then
			completionCleanup = watchValueIncreased(completionInstance, onStepComplete)
		else
			warn(string.format(
				"[TutorialController] Unknown completion type '%s' for step '%s' -- skipping it.",
				tostring(completionType),
				stepConfig.id
			))
			startStep(stepIndex + 1)
		end
	end)
end

-- Call once, after the player's DataLoaded attribute is true. Does nothing
-- if the player isn't TutorialEligible (already finished, skipped, or their
-- save failed to load). A stepIndex greater than 0 means they're rejoining
-- partway through -- resume silently at that step instead of re-showing
-- the welcome panel.
function TutorialController.Init()
	if player:GetAttribute("TutorialEligible") ~= true then
		return
	end

	local stepIndex = math.max(math.floor(tonumber(player:GetAttribute("TutorialStepIndex")) or 0), 0)

	if stepIndex <= 0 then
		-- The welcome panel has exactly one outcome, but three ways to reach
		-- it, and only one may ever take effect -- hence the one-shot guard
		-- rather than three bare Connects.
		local decided = false
		local function once(handler)
			return function()
				if decided then
					return
				end
				decided = true
				handler()
			end
		end

		WelcomePanel.StartRequested:Connect(once(function()
			startStep(0)
		end))
		WelcomePanel.SkipRequested:Connect(once(function()
			finish(true)
		end))
		-- Any other PanelManager-registered panel opening (a MiddleShops
		-- ProximityPrompt, Settings, Shop, Pets) runs closeAll(), which hides
		-- the welcome card without either button firing. Start the tutorial
		-- anyway: the player never chose to skip, and waiting for a decision
		-- that can no longer arrive used to strand them with no panel, no
		-- markers, and a saved step index of 0 that re-showed this same panel
		-- on every future join.
		WelcomePanel.DismissedExternally:Connect(once(function()
			startStep(0)
		end))

		WelcomePanel.Show()
	else
		startStep(stepIndex)
	end
end

return TutorialController
