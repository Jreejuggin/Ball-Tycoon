-- GearShopConfig
-- Items for the Gear Shop NPC. Purchased with in-game Cash, not Robux.
-- PLACEHOLDER CONTENT -- swap in your real gear types/costs.

local CashFormat = require(game:GetService("ReplicatedStorage"):WaitForChild("CashFormat"))

local function item(id, name, cost, iconText, iconColor)
	return { id = id, name = name, cost = cost, priceText = CashFormat.toPriceText(cost), iconText = iconText, iconColor = iconColor }
end

local GearShopConfig = {
	item("GripGloves", "Grip Gloves", 900, "GG", Color3.fromRGB(90, 170, 210)),
	item("SpeedBoots", "Speed Boots", 2000, "SB", Color3.fromRGB(220, 140, 70)),
	item("MagnetGlove", "Magnet Glove", 6500, "MG", Color3.fromRGB(180, 110, 210)),
	item("PowerGauntlet", "Power Gauntlet", 18000, "PG", Color3.fromRGB(230, 180, 60)),
}

return GearShopConfig
