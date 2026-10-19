-- GemConfig
-- Single source of truth for the Gems tab of the purchase panel and for the
-- server's gem grants. Same shape as CashPackConfig: add a bundle here and
-- both the panel and PurchaseReceiptService pick it up.
--
-- `amount` is what the server adds to the buyer's GemData.BankedGems.
-- `name` and `iconText` are display only, so keep them in step with it by hand.
-- `iconAssetId` is the bundle art. Every image is square with the pile centred
-- and drawn larger at each tier, so all cards share one icon box and the art
-- carries the progression. If it is nil, or the image fails to load, the card
-- falls back to the `iconText` badge instead. Unlike CashPackConfig there is
-- no per-bundle `iconColor`: gem colours come from the UI theme.

-- =====================================================================
--  PLACEHOLDER DEVELOPER PRODUCT IDS -- FILL THESE IN.
--  Create one Developer Product per bundle in Creator Dashboard >
--  Monetization > Developer Products and paste its id here. 0 means "not
--  set up yet": the Buy button warns instead of prompting, and the server
--  ignores the bundle.
-- =====================================================================
local PRODUCT_ID_GEMS_100 = 0
local PRODUCT_ID_GEMS_550 = 0
local PRODUCT_ID_GEMS_1200 = 0
local PRODUCT_ID_GEMS_2500 = 0
local PRODUCT_ID_GEMS_6500 = 0

-- PLACEHOLDER bundle sizes and Robux prices -- not designed yet. `priceText`
-- is display only; the real price is whatever the Developer Product costs.
local GemConfig = {
	{ id = "Gems100", amount = 100, name = "100 Gems", priceText = "R$49", productId = PRODUCT_ID_GEMS_100, iconText = "100", iconAssetId = "rbxassetid://129057476383889" },
	{ id = "Gems550", amount = 550, name = "550 Gems", priceText = "R$249", productId = PRODUCT_ID_GEMS_550, iconText = "550", iconAssetId = "rbxassetid://77941022311266" },
	{ id = "Gems1200", amount = 1200, name = "1,200 Gems", priceText = "R$499", productId = PRODUCT_ID_GEMS_1200, iconText = "1.2K", iconAssetId = "rbxassetid://107748257694748" },
	{ id = "Gems2500", amount = 2500, name = "2,500 Gems", priceText = "R$999", productId = PRODUCT_ID_GEMS_2500, iconText = "2.5K", iconAssetId = "rbxassetid://113901141253701" },
	{ id = "Gems6500", amount = 6500, name = "6,500 Gems", priceText = "R$2499", productId = PRODUCT_ID_GEMS_6500, iconText = "6.5K", iconAssetId = "rbxassetid://126491572803221" },
}

return GemConfig
