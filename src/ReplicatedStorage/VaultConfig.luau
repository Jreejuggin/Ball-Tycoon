-- VaultConfig
-- Items for the Vault NPC. Purchased with in-game Cash, not Robux.
-- PLACEHOLDER CONTENT -- swap in your real vault perks/costs.

local CashFormat = require(game:GetService("ReplicatedStorage"):WaitForChild("CashFormat"))

local function item(id, name, cost, iconText, iconColor)
	return { id = id, name = name, cost = cost, priceText = CashFormat.toPriceText(cost), iconText = iconText, iconColor = iconColor }
end

local VaultConfig = {
	item("VaultSlot10", "Vault Slot +10", 500, "+10", Color3.fromRGB(150, 150, 160)),
	item("VaultSlot50", "Vault Slot +50", 2000, "+50", Color3.fromRGB(90, 170, 220)),
	item("VaultSecurityUpgrade", "Vault Security Upgrade", 1500, "SEC", Color3.fromRGB(230, 150, 60)),
	item("VaultAutoSort", "Vault Auto-Sort", 1000, "AS", Color3.fromRGB(235, 190, 50)),
}

return VaultConfig
