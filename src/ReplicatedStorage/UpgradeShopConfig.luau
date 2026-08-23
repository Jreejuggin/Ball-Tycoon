-- UpgradeShopConfig
-- Items for the Upgrade Shop NPC. Purchased with in-game Cash, not Robux.
-- PLACEHOLDER CONTENT -- swap in your real upgrade perks/costs.

local CashFormat = require(game:GetService("ReplicatedStorage"):WaitForChild("CashFormat"))

local function item(id, name, cost, iconText, iconColor)
	return { id = id, name = name, cost = cost, priceText = CashFormat.toPriceText(cost), iconText = iconText, iconColor = iconColor }
end

local UpgradeShopConfig = {
	item("SpeedUpgrade", "Speed Upgrade", 1000, "SPD", Color3.fromRGB(80, 190, 220)),
	item("LuckUpgrade", "Luck Upgrade", 2500, "LUK", Color3.fromRGB(160, 90, 220)),
	item("CapacityUpgrade", "Capacity Upgrade", 3000, "CAP", Color3.fromRGB(230, 150, 60)),
	item("AutoUpgradePack", "Auto-Upgrade Pack", 8000, "AUTO", Color3.fromRGB(235, 190, 50)),
}

return UpgradeShopConfig
