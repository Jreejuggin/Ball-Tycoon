-- TutorialGuiLoader
-- Entry point for the tutorial's client UI. Requiring TutorialController is
-- what actually constructs everything under this ScreenGui (it requires
-- WelcomePanel and StepPanel itself) -- ModuleScripts don't run until
-- something requires them, so this is that something.
--
-- The only job left here is the real trigger Phase 3/4's placeholder was
-- waiting on: wait for the player's DataLoaded attribute (set at the very
-- end of DataSaveScript's PlayerAdded handler, after TutorialProgressService
-- has already resolved TutorialEligible/StepIndex for this session), then
-- hand off to the state machine.

local Players = game:GetService("Players")

local TutorialController = require(script.Parent:WaitForChild("TutorialController"))

local player = Players.LocalPlayer

local function waitForDataLoaded()
	while not player:GetAttribute("DataLoaded") do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
end

task.spawn(function()
	waitForDataLoaded()
	TutorialController.Init()
end)
