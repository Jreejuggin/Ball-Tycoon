--[[
	WorldShopConfig
	Shared, data-driven list of what each of the 5 middle "world shop" NPCs sells.
	Both the server and the client can require this module, so the item
	list only ever needs to be edited in one place.

	NOTE: This currently only powers the browse/preview panel (read-only).
	No currency is deducted from here. When you're ready to make items
	actually purchasable, that logic must be added SERVER-SIDE (see
	StructureBuyPadScript for the pattern this project already uses).
]]

local WorldShopConfig = {}

WorldShopConfig.Shops = {
	BallShop = {
		DisplayName = "Ball Shop",
		Description = "Upgrade the balls your droppers produce.",
		Items = {
			{ Name = "Speed Ball", Description = "Balls move faster down the conveyor.", Price = 250 },
			{ Name = "Mega Ball", Description = "Balls are worth more when sold.", Price = 750 },
			{ Name = "Golden Ball", Description = "A rare, high-value ball skin.", Price = 2500 },
		},
	},

	CreatureShop = {
		DisplayName = "Creature Shop",
		Description = "Hatch companions to help collect cash.",
		Items = {
			{ Name = "Common Egg", Description = "A basic companion egg.", Price = 100 },
			{ Name = "Rare Egg", Description = "Better odds at strong companions.", Price = 900 },
			{ Name = "Mythical Egg", Description = "The rarest companions in the game.", Price = 5000 },
		},
	},

	TradingPost = {
		DisplayName = "Trading Post",
		Description = "Exchange goods and boost your trade income.",
		Items = {
			{ Name = "Sell-All Token", Description = "Instantly sell your entire inventory.", Price = 150 },
			{ Name = "Trade Boost", Description = "+10% cash from trades for 10 minutes.", Price = 500 },
			{ Name = "Exchange Insurance", Description = "Protects one trade from being a loss.", Price = 1200 },
		},
	},

	Vault = {
		DisplayName = "Vault",
		Description = "Protect and grow your saved cash.",
		Items = {
			{ Name = "Cash Multiplier", Description = "+5% passive cash generation.", Price = 1000 },
			{ Name = "Auto-Collect", Description = "Automatically collects nearby cash.", Price = 3000 },
			{ Name = "Vault Insurance", Description = "Keeps a portion of cash safe on loss.", Price = 4500 },
		},
	},

	UpgradeShop = {
		DisplayName = "Upgrade Shop",
		Description = "Personal upgrades for your character.",
		Items = {
			{ Name = "Speed Boost", Description = "Permanently increases WalkSpeed.", Price = 300 },
			{ Name = "Jump Boost", Description = "Permanently increases JumpPower.", Price = 300 },
			{ Name = "Luck Boost", Description = "Improves odds on egg hatches.", Price = 1500 },
		},
	},
}

return WorldShopConfig