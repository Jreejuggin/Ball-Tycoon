-- TutorialProgressService
-- Owns first-time-tutorial state so DataSaveScript only has to hand it the raw
-- DataStore result and ask for a table back at save time.
--
-- The important job here is telling three DataStore outcomes apart, because
-- GetAsync collapses two of them into "no saved table":
--   success = true,  savedData = nil    -> brand-new player, run the tutorial
--   success = true,  savedData = table  -> returning player, resume or skip it
--   success = false                     -> transient load failure, do nothing
-- Treating a failed load as "new player" would replay the tutorial for existing
-- players, so the failure case is resolved first and always resolves to
-- "already completed". DataSaveScript already refuses to save that session, so
-- this state is never written back over a real save.

local RunService = game:GetService("RunService")

local TutorialProgressService = {}

local SCHEMA_VERSION = 1

-- Studio-only test hook, mirroring PlotAssignmentScript's StudioForcedPlotName.
-- Set the Workspace attribute StudioResetTutorial to true in Edit mode to make
-- every joining player eligible again. Published servers ignore it.
local STUDIO_RESET_ATTRIBUTE = "StudioResetTutorial"

-- Mirrored onto the Player so the client can read them straight off the
-- replicated attributes instead of needing a remote round-trip on join.
local ELIGIBLE_ATTR = "TutorialEligible"
local COMPLETED_ATTR = "TutorialCompleted"
local STEP_ATTR = "TutorialStepIndex"
local SKIPPED_ATTR = "TutorialSkipped"

local function studioResetRequested()
	return RunService:IsStudio() and workspace:GetAttribute(STUDIO_RESET_ATTRIBUTE) == true
end

local function applyState(player, eligible, completed, stepIndex, skipped)
	player:SetAttribute(ELIGIBLE_ATTR, eligible)
	player:SetAttribute(COMPLETED_ATTR, completed)
	player:SetAttribute(STEP_ATTR, stepIndex)
	player:SetAttribute(SKIPPED_ATTR, skipped)
end

local function getStepIndex(player)
	return math.max(math.floor(tonumber(player:GetAttribute(STEP_ATTR)) or 0), 0)
end

-- Called once per join, before DataLoaded is set, so every other system can keep
-- using DataLoaded as the single "player state is ready" barrier.
function TutorialProgressService.Resolve(player, loadSucceeded, savedData)
	if not loadSucceeded then
		-- Fail safe. Never show the tutorial off the back of a load failure.
		applyState(player, false, true, 0, false)
		return
	end

	if studioResetRequested() then
		applyState(player, true, false, 0, false)
		return
	end

	if type(savedData) ~= "table" then
		-- The only genuine first visit: the load worked and there was nothing there.
		applyState(player, true, false, 0, false)
		return
	end

	local savedTutorial = savedData.Tutorial
	if type(savedTutorial) ~= "table" then
		-- A save written before this field existed. These players have already
		-- played, so grandfather them in as finished rather than restarting them.
		applyState(player, false, true, 0, false)
		return
	end

	local completed = savedTutorial.Completed == true
	local skipped = savedTutorial.Skipped == true
	local stepIndex = math.max(math.floor(tonumber(savedTutorial.StepIndex) or 0), 0)

	-- Still eligible if they left partway through, so a rejoin resumes instead
	-- of starting over.
	applyState(player, not (completed or skipped), completed, stepIndex, skipped)
end

function TutorialProgressService.Serialize(player)
	return {
		SchemaVersion = SCHEMA_VERSION,
		Completed = player:GetAttribute(COMPLETED_ATTR) == true,
		StepIndex = getStepIndex(player),
		Skipped = player:GetAttribute(SKIPPED_ATTR) == true,
	}
end

function TutorialProgressService.IsEligible(player)
	return player:GetAttribute(ELIGIBLE_ATTR) == true
end

-- Progress only ever moves forward. The client drives step advancement, so this
-- refuses to rewind or to reopen a tutorial that is already finished.
function TutorialProgressService.SetStepIndex(player, stepIndex)
	if not TutorialProgressService.IsEligible(player) then
		return false
	end

	stepIndex = math.max(math.floor(tonumber(stepIndex) or 0), 0)
	if stepIndex <= getStepIndex(player) then
		return false
	end

	player:SetAttribute(STEP_ATTR, stepIndex)
	return true
end

function TutorialProgressService.MarkCompleted(player, wasSkipped)
	if player:GetAttribute(COMPLETED_ATTR) == true then
		return false
	end

	player:SetAttribute(COMPLETED_ATTR, true)
	player:SetAttribute(ELIGIBLE_ATTR, false)
	player:SetAttribute(SKIPPED_ATTR, wasSkipped == true)
	return true
end

-- Dev reset. Server-only by construction (nothing on the client can reach a
-- ModuleScript in ServerScriptService); call it from the Studio command bar as
-- require(game.ServerScriptService.TutorialProgressService).Reset(player) to
-- replay the tutorial mid-session without a fresh account.
function TutorialProgressService.Reset(player)
	if player:GetAttribute("DataLoadFailed") then
		-- This session's save is already disabled; leave its state alone.
		warn("Refused to reset tutorial for " .. player.Name .. " because their data did not load.")
		return false
	end

	applyState(player, true, false, 0, false)
	return true
end

return TutorialProgressService
