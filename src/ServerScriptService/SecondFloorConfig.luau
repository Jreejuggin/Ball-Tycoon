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

-- Floor 2's Worker Centre gets a decorative copy of floor 1's Worker Centre
-- layout, one storey up: same props, same spots. They have no purchase pads
-- and no scripts. They appear as ghosts once the floor-2 Worker Centre can be
-- bought, and turn solid once it is bought. Paths are relative to the plot.
SecondFloorConfig.WorkerCentreLayout = {
	{ "HiringKiosk" },
	{ "CentreSlots", "Centre01_Worker", "Upgrades", "WorkerSpeedUpgrade", "WorkerSpeedSign" },
	{ "CentreSlots", "Centre01_Worker", "WorkerNotesGiftsStation" },
}
SecondFloorConfig.LayoutFolderName = "Layout" -- folder inside the floor-2 Worker Centre

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
SecondFloorConfig.TalkingWorkerTag = "TalkingWorker" -- meeting room; must match TypingWorkerClient

---------------------------------------------------------------------------
-- Office hierarchy (after the cubicles)
-- The rest of floor 2's machine lane, above floor 1's conveyors, Ball Press and
-- Orbital Reactor, is a corporate ladder. Each tier works like a first-floor
-- machine section: a buy button, an upgrade button (levels 1-5, same
-- multipliers and screen colors as the cubicles), and income every cycle.
--
-- Unlock order:
--   Cubicles (all 10 bought) -> Senior Workers, one after another
--   -> Team Lead meeting room -> Department Manager office.
--
-- Positions are plot-local X/Z of each unit's buy button, like everything else
-- in this file. Every unit faces +X (into the lane, away from the aisle).
---------------------------------------------------------------------------
SecondFloorConfig.OfficeTiers = {
	{
		key = "Senior",
		folder = "SeniorCubicles", -- under SecondFloor; part of the saved path
		unitName = "Senior", -- units are Senior1, Senior2, ...
		label = "Senior Worker",
		price = 1, -- test price
		upgradePrice = 1, -- test price
		baseIncomePerMinute = 2500,
		cycleSeconds = 3,
		-- Two columns of four, facing the same way, with a walkway between them.
		positions = {
			Vector3.new(38, 0, -82), Vector3.new(38, 0, -69), Vector3.new(38, 0, -56), Vector3.new(38, 0, -43),
			Vector3.new(57, 0, -82), Vector3.new(57, 0, -69), Vector3.new(57, 0, -56), Vector3.new(57, 0, -43),
		},
		workerTemplate = "ConveyorWorker",
	},
	{
		key = "TeamLead",
		folder = "MeetingRoom",
		unitName = "TeamLead",
		label = "Team Lead",
		price = 1,
		upgradePrice = 1,
		baseIncomePerMinute = 30000,
		cycleSeconds = 3,
		positions = { Vector3.new(33, 0, 4) }, -- outside the meeting room door
		-- Seat order: the team lead at the head of the table, then the team.
		workerTemplates = { "BigConveyorWorker", "Worker1", "ConveyorWorker", "Worker1", "ConveyorWorker" },
	},
	{
		key = "Manager",
		folder = "ManagerOffice",
		unitName = "Manager",
		label = "Department Manager",
		price = 1,
		upgradePrice = 1,
		baseIncomePerMinute = 90000,
		cycleSeconds = 3,
		positions = { Vector3.new(33, 0, 108) }, -- outside the office door
		workerTemplate = "BigConveyorWorker",
	},
}

-- Seated workers: height of a chair seat's top surface above the floor.
SecondFloorConfig.SeatHeight = 0.9

return SecondFloorConfig
