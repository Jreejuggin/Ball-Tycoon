-- BallShopConfig
-- Items for the Ball Shop NPC. Purchased with in-game Cash, not Robux.
-- PLACEHOLDER CONTENT -- swap in your real ball types/costs.

local CashFormat = require(game:GetService("ReplicatedStorage"):WaitForChild("CashFormat"))

local function item(id, name, cost, iconText, iconColor)
	return { id = id, name = name, cost = cost, priceText = CashFormat.toPriceText(cost), iconText = iconText, iconColor = iconColor }
end

local BallShopConfig = {
	item("SpeedBall", "Speed Ball", 750, "SP", Color3.fromRGB(80, 190, 220)),
	item("BouncyBall", "Bouncy Ball", 1500, "BC", Color3.fromRGB(230, 120, 60)),
	item("GoldenBall", "Golden Ball", 5000, "GB", Color3.fromRGB(235, 190, 50)),
	item("RainbowBall", "Rainbow Ball", 15000, "RB", Color3.fromRGB(200, 90, 200)),
}

return BallShopConfig
