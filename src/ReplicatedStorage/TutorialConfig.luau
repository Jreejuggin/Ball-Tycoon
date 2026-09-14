-- TutorialConfig
-- Single source of truth for the first-time tutorial's step list. Same
-- pattern as ShopConfig/UpgradeShopConfig -- add a step here and the
-- controller (client) + TutorialProgressService (server) drive themselves
-- off it, no code changes required to extend the sequence.
--
-- Every path below is resolved relative to a root that is only known at
-- runtime (the player's own plot, or the player instance itself), so steps
-- describe WHERE things live rather than hardcoding an Instance reference:
--   root = "Plot"   -> resolved from the player's assigned plot in Workspace
--   root = "Player" -> resolved from the Player instance (e.g. leaderstats)
-- `path` is a "/"-separated chain of child names walked from that root, the
-- same relative-path convention TycoonProgressService and DataSaveScript
-- already use for plot-scoped state.
--
-- `target` says what the 3D arrow (Phase 4) points at -- always something
-- with a world position, i.e. a Model or BasePart.
-- `completion` says what the tutorial controller (Phase 5) watches to decide
-- the step is done. Two signal shapes cover every step below:
--   ValueTrue      -- path resolves to a BoolValue; done when .Value == true
--   ValueIncreased -- path resolves to an IntValue/NumberValue; done when
--                     .Value rises above whatever it was when the step started

local TutorialConfig = {
	{
		id = "BuyFirstDropper",
		title = "Buy Your First Dropper",
		dialog = "Head to your plot and step on the glowing pad to buy your first dropper!",
		target = { root = "Plot", path = "DropperSlots/Slot1/BuyPad" },
		completion = { type = "ValueTrue", root = "Plot", path = "DropperSlots/Slot1/Activated" },
	},
	{
		id = "CollectCash",
		title = "Collect Your Cash",
		dialog = "Balls are dropping! Walk over to your dropper and grab the cash it drops.",
		target = { root = "Plot", path = "DropperSlots/Slot1/Dropper" },
		completion = { type = "ValueIncreased", root = "Player", path = "leaderstats/Cash" },
	},
	{
		id = "UpgradeFirstDropper",
		title = "Upgrade Your Dropper",
		dialog = "Nice! Now step on the upgrade pad to make your dropper even more valuable.",
		target = { root = "Plot", path = "DropperSlots/Slot1/UpgradeBuyPad" },
		completion = { type = "ValueIncreased", root = "Plot", path = "DropperSlots/Slot1/UpgradeLevel" },
	},
	{
		-- CentreZoneService.luau (server) gates the worker centre behind the
		-- WHOLE first row of droppers, not just Slot1: requirementMet() ->
		-- firstDroppersComplete() requires Slot1 through Slot5's Activated all
		-- true before Centre01_Worker/BuyPad's CanTouch even turns on -- until
		-- then it's a "LOCKED" pad, greyed out and untouchable. Pointing the
		-- tutorial at it right after Slot1 (as this list used to) sent the
		-- player to a pad they couldn't actually buy yet. These three steps
		-- close that gap by walking the player through the rest of the row
		-- first, matching FIRST_DROPPER_COUNT = 5 in that service.
		id = "BuySecondDropper",
		title = "Buy Your Second Dropper",
		dialog = "Keep going! Buy the next dropper in the row.",
		target = { root = "Plot", path = "DropperSlots/Slot2/BuyPad" },
		completion = { type = "ValueTrue", root = "Plot", path = "DropperSlots/Slot2/Activated" },
	},
	{
		id = "BuyThirdDropper",
		title = "Buy Your Third Dropper",
		dialog = "Great progress! Buy the next dropper in the row.",
		target = { root = "Plot", path = "DropperSlots/Slot3/BuyPad" },
		completion = { type = "ValueTrue", root = "Plot", path = "DropperSlots/Slot3/Activated" },
	},
	{
		id = "BuyFourthDropper",
		title = "Buy Your Fourth Dropper",
		dialog = "Almost done with this row! Buy the next dropper.",
		target = { root = "Plot", path = "DropperSlots/Slot4/BuyPad" },
		completion = { type = "ValueTrue", root = "Plot", path = "DropperSlots/Slot4/Activated" },
	},
	{
		id = "BuyFifthDropper",
		title = "Buy Your Fifth Dropper",
		dialog = "One more! Buy the last dropper to complete the row.",
		target = { root = "Plot", path = "DropperSlots/Slot5/BuyPad" },
		completion = { type = "ValueTrue", root = "Plot", path = "DropperSlots/Slot5/Activated" },
	},
	{
		id = "UnlockWorkerCentre",
		title = "Unlock the Worker Centre",
		dialog = "The whole row is bought! Workers collect cash for you automatically -- head to the worker centre and unlock it!",
		target = { root = "Plot", path = "CentreSlots/Centre01_Worker/BuyPad" },
		completion = { type = "ValueTrue", root = "Plot", path = "CentreSlots/Centre01_Worker/Activated" },
	},
	{
		-- The worker centre BuyPad only unlocks the ZONE -- CentreZoneService
		-- sets Centre01_Worker/Activated, not a hired worker. Hiring itself
		-- happens at the HiringKiosk (a separate touch-based pad, wired by
		-- the Studio-native WorkerSpawnerController -- see PROJECT_STATE.luau
		-- section 2.3), which sets CentreSlots/Centre01_Worker/WorkerActivations/
		-- Worker1. Two real purchases, so two real steps -- a single step
		-- watching only Activated completed the moment the ZONE unlocked,
		-- before any worker existed.
		id = "HireFirstWorker",
		title = "Hire Your First Worker",
		dialog = "Almost there! Head to the hiring kiosk and hire your first worker.",
		target = { root = "Plot", path = "HiringKiosk" },
		completion = { type = "ValueTrue", root = "Plot", path = "CentreSlots/Centre01_Worker/WorkerActivations/Worker1" },
	},
}

return TutorialConfig
