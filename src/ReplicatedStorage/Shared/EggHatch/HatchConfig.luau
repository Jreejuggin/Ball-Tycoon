-- HatchConfig (ModuleScript) - SET B (hierarchical eggs)
-- Location: ReplicatedStorage/Shared/EggHatch/HatchConfig
--
-- Everything the hatch animation needs that is NOT code: timings, colours, image asset ids, sounds.
-- The animation is purely cosmetic. The server has already rolled, granted and saved the pet
-- before the client ever plays it, so nothing in here affects rewards.
--
-- After uploading the PNGs (Asset Manager -> Bulk Import), paste each "rbxassetid://..." id below.
-- Any id left as "" is skipped safely (the animation still plays, that layer just doesn't show).

local HatchConfig = {}

----------------------------------------------------------------------------------------------------
-- Timings (seconds). The whole sequence is ~4 s; tapping the screen speeds the rest up.
----------------------------------------------------------------------------------------------------
HatchConfig.Timing = {
	BackdropFade = 0.25,     -- screen dims
	DropIn = 0.4,            -- egg pops onto the screen
	ShakeRounds = 3,         -- each round = a wobble, then the next crack stage appears
	SwingsPerRound = 4,      -- back-and-forth swings per round
	SwingTime = 0.07,        -- seconds per swing
	PauseBetweenRounds = 0.22,
	FlashIn = 0.08,          -- white flash as the shell breaks
	FlashOut = 0.4,
	SplitTime = 0.6,         -- halves fly apart
	RevealPop = 0.45,        -- pet pops in
	Hold = 1.8,              -- how long the result stays up
	FadeOut = 0.3,
	SkipSpeedMultiplier = 4, -- tapping during the hatch plays the remaining steps 4x faster
}

-- Wobble angle (degrees) for each shake round: builds tension.
HatchConfig.ShakeAngles = { 8, 13, 19 }

-- Up to this many eggs are shown side by side (x3 hatch). Larger batches play in groups.
HatchConfig.MaxSlotsOnScreen = 3

----------------------------------------------------------------------------------------------------
-- Rarity look. Colours match EggConfig.Rarities, so the burst matches the inventory slots.
----------------------------------------------------------------------------------------------------
HatchConfig.Rarity = {
	Common    = { Color = Color3.fromRGB(230, 234, 240), Sparkles = 0,  ExtraHold = 0,   Rainbow = false },
	Uncommon  = { Color = Color3.fromRGB(46, 190, 78),   Sparkles = 0,  ExtraHold = 0,   Rainbow = false },
	Rare      = { Color = Color3.fromRGB(42, 127, 240),  Sparkles = 3,  ExtraHold = 0.2, Rainbow = false },
	Epic      = { Color = Color3.fromRGB(138, 59, 232),  Sparkles = 5,  ExtraHold = 0.4, Rainbow = false },
	Legendary = { Color = Color3.fromRGB(255, 154, 26),  Sparkles = 8,  ExtraHold = 0.8, Rainbow = false },
	Mythic    = { Color = Color3.fromRGB(255, 79, 139),  Sparkles = 12, ExtraHold = 1.4, Rainbow = true },
}

----------------------------------------------------------------------------------------------------
-- Images. Upload the PNGs and paste the ids.
----------------------------------------------------------------------------------------------------
HatchConfig.SharedImages = {
	Burst = "",      -- FX_HatchBurst.png (tintable rays)
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",    -- FX_Sparkle.png
	Shard = "",      -- FX_ShellShard.png (tintable shell piece)
	RarityTags = {   -- RarityTag_<Rarity>.png
		Common = "", Uncommon = "", Rare = "", Epic = "", Legendary = "", Mythic = "",
	},
}

-- Per egg (Set B). File names are in 1_Upload_To_Roblox/Eggs/<EggId>/.
-- All 6 images share the same framing, so stacking them at the same position lines up exactly.
HatchConfig.EggImages = {
	CottonCandyEgg = {
		Whole = "",  -- CottonCandyEgg_Hatch_Whole.png
		Top = "",    -- CottonCandyEgg_Hatch_Top.png
		Bottom = "", -- CottonCandyEgg_Hatch_Bottom.png
		Crack = { "", "", "" }, -- CottonCandyEgg_Hatch_Crack1.png, _Crack2.png, _Crack3.png
	},
	LuckyStarEgg = {
		Whole = "",  -- LuckyStarEgg_Hatch_Whole.png
		Top = "",    -- LuckyStarEgg_Hatch_Top.png
		Bottom = "", -- LuckyStarEgg_Hatch_Bottom.png
		Crack = { "", "", "" }, -- LuckyStarEgg_Hatch_Crack1.png, _Crack2.png, _Crack3.png
	},
	GoldenEgg = {
		Whole = "",  -- GoldenEgg_Hatch_Whole.png
		Top = "",    -- GoldenEgg_Hatch_Top.png
		Bottom = "", -- GoldenEgg_Hatch_Bottom.png
		Crack = { "", "", "" }, -- GoldenEgg_Hatch_Crack1.png, _Crack2.png, _Crack3.png
	},
	PrismEgg = {
		Whole = "",  -- PrismEgg_Hatch_Whole.png
		Top = "",    -- PrismEgg_Hatch_Top.png
		Bottom = "", -- PrismEgg_Hatch_Bottom.png
		Crack = { "", "", "" }, -- PrismEgg_Hatch_Crack1.png, _Crack2.png, _Crack3.png
	},
	RainbowRoyalEgg = {
		Whole = "",  -- RainbowRoyalEgg_Hatch_Whole.png
		Top = "",    -- RainbowRoyalEgg_Hatch_Top.png
		Bottom = "", -- RainbowRoyalEgg_Hatch_Bottom.png
		Crack = { "", "", "" }, -- RainbowRoyalEgg_Hatch_Crack1.png, _Crack2.png, _Crack3.png
	},
}

-- Pet icons (PetIcons_SkipIfAlreadyUploaded/<PetId>.png). If the inventory system already
-- has a PetId -> image lookup, point GetPetIcon at it instead of filling this table twice.
HatchConfig.PetIcons = {
	TennisChick = "",
	ShroomSprite = "",
	GhostBoo = "",
	CapyYuzu = "",
	SnowPenguin = "",
	CoinPup = "",
	BobaFrog = "",
	DonutPup = "",
	BoltBot = "",
	BambooPanda = "",
	VampireBat = "",
	EmberDragon = "",
	SushiCat = "",
	PumpkinCat = "",
	StrawberryCow = "",
	RaccoonBandit = "",
	CloudBunny = "",
	FrostDragon = "",
	RawrDino = "",
	WitchOwl = "",
	CrystalFox = "",
	MimicOcto = "",
	DevilImp = "",
	QueenBee = "",
	ShadowCat = "",
	GalaxyAxolotl = "",
	AngelPup = "",
	Kitsune = "",
	RainbowUnicorn = "",
	DiscoBee = "",
}

function HatchConfig.GetPetIcon(petId: string): string
	return HatchConfig.PetIcons[petId] or ""
end

-- "RainbowUnicorn" -> "Rainbow Unicorn". Replace with a real DisplayName lookup if one exists.
function HatchConfig.GetPetDisplayName(petId: string): string
	return (petId:gsub("(%l)(%u)", "%1 %2"))
end

----------------------------------------------------------------------------------------------------
-- Sounds (optional). "" = silent.
----------------------------------------------------------------------------------------------------
HatchConfig.Sounds = {
	Shake = "",   -- short rattle, plays each shake round
	Crack = "",   -- crack snap, plays when a new crack stage appears
	Pop = "",     -- shell bursting
	Reveal = { Common = "", Uncommon = "", Rare = "", Epic = "", Legendary = "", Mythic = "" },
	Volume = 0.6,
}

----------------------------------------------------------------------------------------------------
-- 3D nest hatch (optional). Where the imported <EggId>_Hatch models live.
----------------------------------------------------------------------------------------------------
HatchConfig.WorldHatchFolderPath = { "Assets", "EggHatch" } -- ReplicatedStorage/Assets/EggHatch/<EggId>_Hatch

-- "Screen" = full-screen hatch only (default), "World" = only on the nest, "Both" = nest + screen.
-- The server can override per hatch by sending Mode in the payload.
HatchConfig.DefaultMode = "Screen"

-- Pet template used by the 3D nest hatch (the pet rises out of the shell). Point this at the
-- folder the pet system already clones pets from. Return nil to skip the pet in 3D.
HatchConfig.PetModelFolderPath = { "Assets", "Pets" }

function HatchConfig.GetPetModel(petId: string): Instance?
	local node: Instance? = game:GetService("ReplicatedStorage")
	for _, name in ipairs(HatchConfig.PetModelFolderPath) do
		node = node and node:FindFirstChild(name)
	end
	return node and node:FindFirstChild(petId)
end

----------------------------------------------------------------------------------------------------
-- "Press E to open" on the nest egg (used by EggOpenService on the server and EggPromptController
-- on the client). The server enforces everything; these are only the prompt's look and feel.
----------------------------------------------------------------------------------------------------
HatchConfig.OpenPrompt = {
	Tag = "EggOpenPrompt",               -- CollectionService tag put on every egg's ProximityPrompt
	ActionText = "Open",
	KeyboardKey = Enum.KeyCode.E,
	GamepadKey = Enum.KeyCode.ButtonX,
	HoldDuration = 0.6,                  -- hold E this long (the egg wiggles harder while held)
	MaxActivationDistance = 10,
	WiggleMaxAngle = 9,                  -- degrees, reached at the end of the hold
}

return HatchConfig
