--[[
	SecondFloorConfig
	Every tunable value for the second floor, in one place.

	POSITIONS are plot-local: X/Z offsets from the centre of a plot's Floor part,
	measured along that Floor's own axes. Each plot's Floor CFrame carries its
	rotation, so one set of numbers is correct on all 10 plots. Values were
	measured on P1, whose Floor is unrotated.
]]

local SecondFloorConfig = {}

-- Prices: test values, matching the first floor's current $1 prices.
SecondFloorConfig.FloorPrice = 1
SecondFloorConfig.StructurePrice = 1
SecondFloorConfig.CubiclePrice = 1
SecondFloorConfig.CubicleUpgradePrice = 1

-- Floor 2 gets a copy of every first-floor centre, one storey up, with the same
-- prices, order and dependencies (copied from the first floor at server start).
-- Progress restarts at level 1: these are separate purchases from floor 1's.
SecondFloorConfig.Centres = {
	"Centre01_Worker",
	"Centre02_Home",
	"Centre03_Avatar",
	"Centre04_Orb",
	"Centre05_Pet",
}

-- Floor 1's Worker Centre unlocks after a full row of droppers; floor 2's
-- unlocks after the first row of cubicles (CubicleRowSize, below).
SecondFloorConfig.WorkerCentreRequirement = "Cubicles"
SecondFloorConfig.WorkerCentreRequirementText = "Buy a row of cubicles"

-- The floor-2 Home Centre sells its structures from one pad, in this order,
-- exactly like floor 1 (StructureSequenceService). The Laser Door is left out
-- because floor 2's entrance is the staircase. GroupSuffix keeps these
-- structure groups separate from the first floor's.
SecondFloorConfig.GroupSuffix = "_F2"
SecondFloorConfig.HomeStructureSlots = { "Slot_Walls", "Slot_Glass", "Slot_Roof", "Slot_CeilingLights" }

-- Floor 1's central structure pad sits right above where the stairwell opens on
-- floor 2, so floor 2's copy is moved here instead (plot-local X/Z, still
-- inside the Home Centre zone).
SecondFloorConfig.HomeStructurePadPosition = Vector3.new(-28, 0, -59.2)
SecondFloorConfig.HomeCompletionMessage = "All Level 2 Home Upgrades Implemented!"

-- Staircase inside the Home Centre: three flights with two 90-degree turns.
-- StairOrigin is the corner where flight 1 starts, on the first floor.
-- If the stairs clip into a prop, move StairOrigin; everything else follows.
SecondFloorConfig.StairOrigin = Vector3.new(-68, 0, -60)
SecondFloorConfig.StairWidth = 6
SecondFloorConfig.StepDepth = 1.5
SecondFloorConfig.TargetStepRise = 0.5 -- adjusted slightly so the top step meets floor 2 exactly
SecondFloorConfig.FloorPadOffset = Vector3.new(3, 0, -4) -- from StairOrigin: just before step 1
-- Clear space needed above a step. Any step closer than this to floor 2's
-- underside gets floor 2 opened above it. Characters are about 5-5.5 studs tall
-- and need extra room for the step-up motion, so keep this comfortably larger.
SecondFloorConfig.StairHeadroom = 8

SecondFloorConfig.GhostTransparency = 0.6
SecondFloorConfig.SafetyRailHeight = 8 -- invisible edge barrier around floor 2

-- Cubicles sit directly above the first floor's dropper rows and unlock in the
-- same order as the droppers: row 1 first, then row 2.
SecondFloorConfig.CubicleSources = {
	{ folder = "DropperSlots", slots = { "Slot1", "Slot2", "Slot3", "Slot4", "Slot5" } },
	{ folder = "DropperSlots2", slots = { "Slot1", "Slot2", "Slot3", "Slot4", "Slot5" } },
}
SecondFloorConfig.CubicleRowSize = 5

-- Income works like the Orbital Reactor. A level-1 cubicle earns the same as a
-- level-1 first-floor dropper ($200/min). Screen colors match the machines.
SecondFloorConfig.CubicleBaseIncomePerMinute = 200
SecondFloorConfig.CubicleCycleSeconds = 3
SecondFloorConfig.CubicleLevels = {
	{ multiplier = 1, screenColor = Color3.fromRGB(255, 224, 35) },
	{ multiplier = 2, screenColor = Color3.fromRGB(40, 225, 80) },
	{ multiplier = 4, screenColor = Color3.fromRGB(45, 165, 255) },
	{ multiplier = 8, screenColor = Color3.fromRGB(175, 75, 255) },
	{ multiplier = 16, screenColor = Color3.fromRGB(255, 145, 35) },
}
SecondFloorConfig.CubicleUpgradeCooldownSeconds = 1.5

-- Computer workers.
SecondFloorConfig.WorkerTemplateName = "Worker1" -- from ServerStorage.WorkerTemplates
SecondFloorConfig.WorkerStandX = 3.6 -- cubicle-local X where the worker stands at the desk
SecondFloorConfig.TypingWorkerTag = "TypingWorker" -- must match TypingWorkerClient

return SecondFloorConfig
