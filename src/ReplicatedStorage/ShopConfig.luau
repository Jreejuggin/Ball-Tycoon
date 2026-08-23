-- ShopConfig
-- Single source of truth for what appears in the Shop panel.
-- To add a new item later: just add another entry to this list -- the Shop
-- UI builds itself from this table, no UI editing required.
--
-- IMPORTANT: `productId` values below are PLACEHOLDERS (0). Real Robux
-- purchases require a Developer Product created in the Roblox Creator
-- Dashboard (Monetization > Developer Products) for THIS specific game.
-- Once created, copy each product's ID here. Until then, the Buy button
-- will warn in the output instead of opening the purchase prompt, so
-- nothing breaks or errors out during testing.

local ShopConfig = {
	{
		id = "AutoCollect",
		name = "Auto Collect!",
		priceText = "R$149",
		productId = 0, -- TODO: replace with real Developer Product ID
		iconText = "AC",
		iconColor = Color3.fromRGB(70, 190, 90),
	},
	{
		id = "TwoXCash",
		name = "2X Cash",
		priceText = "R$349",
		productId = 0, -- TODO: replace with real Developer Product ID
		iconText = "2X",
		iconColor = Color3.fromRGB(230, 180, 40),
	},
	{
		id = "InfiniteCash",
		name = "Infinite Cash!",
		priceText = "R$1499",
		productId = 0, -- TODO: replace with real Developer Product ID
		iconText = "\226\136\158", -- infinity symbol
		iconColor = Color3.fromRGB(160, 90, 220),
	},
	{
		id = "MegaDropper",
		name = "Mega Dropper!",
		priceText = "R$249",
		productId = 0, -- TODO: replace with real Developer Product ID
		iconText = "MD",
		iconColor = Color3.fromRGB(230, 110, 50),
	},
	{
		id = "GoldenDropper",
		name = "Golden Dropper!",
		priceText = "R$599",
		productId = 0, -- TODO: replace with real Developer Product ID
		iconText = "GD",
		iconColor = Color3.fromRGB(235, 200, 60),
	},
}

return ShopConfig
