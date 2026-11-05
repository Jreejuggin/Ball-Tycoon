-- EggConfig (ModuleScript) - SET B
-- Data only: egg tiers, prices, contents and odds for the Ball Pets.
-- Put it in ReplicatedStorage so the shop UI can READ it, but the server must do every purchase and roll
-- (see Egg_Tiers_Guide.md section 6). Chances in each egg add up to exactly 100.
-- Prices are starting values: tune them to your income curve (see the guide).

local EggConfig = {}

-- Rarity order (low -> high) and UI colours (top of each slot gradient)
EggConfig.Rarities = {
	{ Name = "Common",    Rank = 1, Color = Color3.fromRGB(230, 234, 240) },
	{ Name = "Uncommon",  Rank = 2, Color = Color3.fromRGB(46, 190, 78) },
	{ Name = "Rare",      Rank = 3, Color = Color3.fromRGB(42, 127, 240) },
	{ Name = "Epic",      Rank = 4, Color = Color3.fromRGB(138, 59, 232) },
	{ Name = "Legendary", Rank = 5, Color = Color3.fromRGB(255, 154, 26) },
	{ Name = "Mythic",    Rank = 6, Color = Color3.fromRGB(255, 79, 139) }, -- UI uses the rainbow slot image
}

-- Shop order (Set B: hierarchical ladder, mixed themes; pets listed weakest -> strongest)
EggConfig.Order = { "CottonCandyEgg", "LuckyStarEgg", "GoldenEgg", "PrismEgg", "RainbowRoyalEgg" }

EggConfig.Eggs = {
	CottonCandyEgg = {
		DisplayName = "Cotton Candy Egg", Tier = 1, Currency = "Cash", Price = 500,
		Pets = {
			{ PetId = "TennisChick",   Rarity = "Common",   Chance = 30 },
			{ PetId = "ShroomSprite",  Rarity = "Common",   Chance = 25 },
			{ PetId = "GhostBoo",      Rarity = "Common",   Chance = 20 },
			{ PetId = "CapyYuzu",      Rarity = "Uncommon", Chance = 12 },
			{ PetId = "SnowPenguin",   Rarity = "Uncommon", Chance = 9 },
			{ PetId = "CoinPup",       Rarity = "Rare",     Chance = 4 },
		},
	},
	LuckyStarEgg = {
		DisplayName = "Lucky Star Egg", Tier = 2, Currency = "Cash", Price = 5000,
		Pets = {
			{ PetId = "BobaFrog",      Rarity = "Common",   Chance = 28 },
			{ PetId = "DonutPup",      Rarity = "Common",   Chance = 24 },
			{ PetId = "BoltBot",       Rarity = "Common",   Chance = 20 },
			{ PetId = "BambooPanda",   Rarity = "Uncommon", Chance = 14 },
			{ PetId = "VampireBat",    Rarity = "Uncommon", Chance = 10 },
			{ PetId = "EmberDragon",   Rarity = "Rare",     Chance = 4 },
		},
	},
	GoldenEgg = {
		DisplayName = "Golden Egg", Tier = 3, Currency = "Cash", Price = 50000,
		Pets = {
			{ PetId = "SushiCat",      Rarity = "Common",   Chance = 32 },
			{ PetId = "PumpkinCat",    Rarity = "Common",   Chance = 26 },
			{ PetId = "StrawberryCow", Rarity = "Uncommon", Chance = 18 },
			{ PetId = "RaccoonBandit", Rarity = "Uncommon", Chance = 14 },
			{ PetId = "CloudBunny",    Rarity = "Rare",     Chance = 8 },
			{ PetId = "FrostDragon",   Rarity = "Epic",     Chance = 2 },
		},
	},
	PrismEgg = {
		DisplayName = "Prism Egg", Tier = 4, Currency = "Gems", Price = 250,
		Pets = {
			{ PetId = "RawrDino",      Rarity = "Common",    Chance = 35 },
			{ PetId = "WitchOwl",      Rarity = "Uncommon",  Chance = 28 },
			{ PetId = "CrystalFox",    Rarity = "Rare",      Chance = 15 },
			{ PetId = "MimicOcto",     Rarity = "Rare",      Chance = 15 },
			{ PetId = "DevilImp",      Rarity = "Epic",      Chance = 6 },
			{ PetId = "QueenBee",      Rarity = "Legendary", Chance = 1 },
		},
	},
	RainbowRoyalEgg = {
		DisplayName = "Rainbow Royal Egg", Tier = 5, Currency = "Gems", Price = 2500,
		Pets = {
			{ PetId = "ShadowCat",      Rarity = "Rare",      Chance = 45 },
			{ PetId = "GalaxyAxolotl",  Rarity = "Epic",      Chance = 25 },
			{ PetId = "AngelPup",       Rarity = "Epic",      Chance = 22 },
			{ PetId = "Kitsune",        Rarity = "Legendary", Chance = 4.5 },
			{ PetId = "RainbowUnicorn", Rarity = "Legendary", Chance = 3 },
			{ PetId = "DiscoBee",       Rarity = "Mythic",    Chance = 0.5 },
		},
	},
}

-- Weighted roll. Call this ONLY on the server, with a server-owned Random.
function EggConfig.Roll(eggId, rng)
	local egg = EggConfig.Eggs[eggId]
	assert(egg, "Unknown egg " .. tostring(eggId))
	local total = 0
	for _, p in ipairs(egg.Pets) do
		total += p.Chance
	end
	local pick = rng:NextNumber() * total
	for _, p in ipairs(egg.Pets) do
		pick -= p.Chance
		if pick <= 0 then
			return p.PetId, p.Rarity
		end
	end
	local last = egg.Pets[#egg.Pets]
	return last.PetId, last.Rarity
end

return EggConfig
