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
		id = "UnlockWorkerCentre",
		title = "Unlock the Worker Centre",
		dialog = "Workers collect cash for you automatically. Head to the worker centre and unlock it!",
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
