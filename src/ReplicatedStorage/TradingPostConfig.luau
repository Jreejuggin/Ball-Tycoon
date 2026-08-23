-- TradingPostConfig
-- Items for the Trading Post NPC. Purchased with in-game Cash, not Robux.
-- PLACEHOLDER CONTENT -- a real trading post might eventually need its own
-- trade-UI (offer/accept between players) rather than a Buy list; these are
-- placeholder perks for that feature in the meantime.

local CashFormat = require(game:GetService("ReplicatedStorage"):WaitForChild("CashFormat"))

local function item(id, name, cost, iconText, iconColor)
	return { id = id, name = name, cost = cost, priceText = CashFormat.toPriceText(cost), iconText = iconText, iconColor = iconColor }
end

local TradingPostConfig = {
	item("ExtraTradeSlot", "Extra Trade Slot", 1000, "+1", Color3.fromRGB(90, 170, 220)),
	item("TradeBoost", "Trade Boost", 2500, "TB", Color3.fromRGB(230, 150, 60)),
	item("VIPTradingAccess", "VIP Trading Access", 7500, "VIP", Color3.fromRGB(235, 190, 50)),
}

return TradingPostConfig
