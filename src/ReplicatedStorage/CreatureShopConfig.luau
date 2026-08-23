-- CreatureShopConfig
-- Items for the Creature Shop NPC in Workspace.MiddleShops.CreatureShopStructure.
-- Purchased with in-game Cash (deducted server-side), NOT Robux.
--
-- PLACEHOLDER CONTENT: I don't have your actual creature roster/economy, so
-- these are generic placeholder tiers themed to "Creature Shop" with
-- placeholder Cash costs. Swap in real creature names/costs whenever
-- you're ready -- the panel rebuilds itself from whatever is in this table.
--
-- `cost` is the only value the server trusts for deduction -- `priceText`
-- is purely cosmetic display text generated from it.
--
-- There's no real item/inventory system yet, so a successful purchase just
-- creates a placeholder marker in the player's PurchasedItems folder
-- (see ServerScriptService.MiddleShopPurchaseHandler) -- swap that out for
-- real item-granting once inventory exists.

local CashFormat = require(game:GetService("ReplicatedStorage"):WaitForChild("CashFormat"))

local function item(id, name, cost, iconText, iconColor)
	return { id = id, name = name, cost = cost, priceText = CashFormat.toPriceText(cost), iconText = iconText, iconColor = iconColor }
end

local CreatureShopConfig = {
	item("CommonCreature", "Common Creature", 500, "C", Color3.fromRGB(120, 170, 90)),
	item("RareCreature", "Rare Creature", 2000, "R", Color3.fromRGB(80, 150, 220)),
	item("EpicCreature", "Epic Creature", 10000, "E", Color3.fromRGB(160, 90, 220)),
	item("LegendaryCreature", "Legendary Creature", 50000, "L", Color3.fromRGB(235, 190, 50)),
}

return CreatureShopConfig
