-- CashPackConfig
-- Single source of truth for the Cash purchase panel (opened via the "+"
-- button next to the cash display). Same pattern as ShopConfig -- add a
-- new pack here and the panel builds itself, no UI editing required.
--
-- IMPORTANT: `productId` values are PLACEHOLDERS (0), same as ShopConfig.
-- Each pack needs its own real Developer Product from the Roblox Creator
-- Dashboard (Monetization > Developer Products) before it can actually
-- sell. Until then, Buy just warns in the output instead of erroring.

local CashPackConfig = {
	{ id = "Cash5K", name = "5K$ Cash", priceText = "R$15", productId = 0, iconText = "5K", iconColor = Color3.fromRGB(70, 190, 90) },
	{ id = "Cash25K", name = "25K$ Cash", priceText = "R$49", productId = 0, iconText = "25K", iconColor = Color3.fromRGB(70, 190, 90) },
	{ id = "Cash50K", name = "50K$ Cash", priceText = "R$99", productId = 0, iconText = "50K", iconColor = Color3.fromRGB(70, 190, 90) },
	{ id = "Cash100K", name = "100K$ Cash", priceText = "R$199", productId = 0, iconText = "100K", iconColor = Color3.fromRGB(70, 190, 90) },
	{ id = "Cash250K", name = "250K$ Cash", priceText = "R$399", productId = 0, iconText = "250K", iconColor = Color3.fromRGB(70, 190, 90) },
	{ id = "Cash500K", name = "500K$ Cash", priceText = "R$699", productId = 0, iconText = "500K", iconColor = Color3.fromRGB(70, 190, 90) },
	{ id = "Cash1M", name = "1M$ Cash", priceText = "R$999", productId = 0, iconText = "1M", iconColor = Color3.fromRGB(230, 180, 40) },
	{ id = "Cash5M", name = "5M$ Cash", priceText = "R$1999", productId = 0, iconText = "5M", iconColor = Color3.fromRGB(230, 180, 40) },
}

return CashPackConfig
