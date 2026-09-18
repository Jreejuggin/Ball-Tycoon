-- TutorialProgressHandler
-- Thin network wiring between the two client-facing tutorial RemoteEvents
-- and TutorialProgressService, which owns the actual state (see that
-- module for why: tri-state DataStore load resolution, forward-only step
-- index, etc.). Mirrors the Service/Handler split MiddleShopPurchaseHandler
-- uses for shop purchases -- validation and network trust live here, state
-- transitions live in the service.
--
-- Both events are trusted only as far as "a stepIndex/skipped flag arrived";
-- TutorialProgressService.SetStepIndex already refuses to rewind or to
-- touch a player who isn't eligible, so a malicious or confused client
-- firing these out of order or with a garbage stepIndex can't push a
-- player's saved progress backward or resurrect a finished tutorial.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialProgressService = require(script.Parent.TutorialProgressService)

local stepEvent = ReplicatedStorage:WaitForChild("TutorialStepEvent")
local completeEvent = ReplicatedStorage:WaitForChild("TutorialCompleteEvent")

-- Fired once per completed step, with the index of the NEXT step the
-- client is about to show -- persists progress incrementally so a rejoin
-- partway through resumes at the right step instead of from the start.
local function onStepAdvanced(player, nextStepIndex)
	if type(nextStepIndex) ~= "number" then
		return
	end
	TutorialProgressService.SetStepIndex(player, nextStepIndex)
end

-- Fired once, either because the player pressed Skip on the welcome panel
-- or because they reached the end of the step list naturally.
local function onCompleted(player, wasSkipped)
	TutorialProgressService.MarkCompleted(player, wasSkipped == true)
end

stepEvent.OnServerEvent:Connect(onStepAdvanced)
completeEvent.OnServerEvent:Connect(onCompleted)
