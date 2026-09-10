-- TutorialGuiLoader
-- Entry point for the tutorial's client UI. Requiring WelcomePanel is what
-- actually constructs its Frame under this ScreenGui -- ModuleScripts don't
-- run until something requires them, so this is that something. Future
-- tutorial UI modules (the step banner, in Phase 5) get required here too.
--
-- TEMPORARY (Phase 3): there's no tutorial controller yet to decide WHEN the
-- welcome panel should appear, so the block below shows it once, automatically,
-- in Studio only -- purely so it can be previewed end to end while later
-- phases are still being built. Phase 5 replaces this block with the real
-- trigger: wait for the player's DataLoaded and TutorialEligible attributes,
-- then call WelcomePanel.Show() from the state machine instead.

local RunService = game:GetService("RunService")

local WelcomePanel = require(script.Parent:WaitForChild("WelcomePanel"))

WelcomePanel.StartRequested:Connect(function()
	print("[Tutorial] Start requested -- Phase 5 will begin step 1 here.")
end)

WelcomePanel.SkipRequested:Connect(function()
	print("[Tutorial] Skip requested -- Phase 5 will persist this to the server here.")
end)

if RunService:IsStudio() then
	task.wait(1) -- let the rest of the HUD finish laying out first
	WelcomePanel.Show()
end
