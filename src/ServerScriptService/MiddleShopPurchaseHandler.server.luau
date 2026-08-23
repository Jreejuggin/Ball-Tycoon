-- MiddleShopPurchaseHandler
-- Server-authoritative purchase handling for the 5 MiddleShops NPCs.
-- The client NEVER decides the price or touches leaderstats.Cash directly --
-- it only sends (shopConfigName, itemId), and this script looks up the real
-- cost itself, validates funds, and performs the deduction. This is the
-- only safe way to handle in-game currency purchases; trusting a price sent
-- from the client would let anyone buy anything for free via an exploit.
--
-- ITEM GRANTING:
-- - Creature Shop: grants a real, visible item -- clones
--   ServerStorage.CreatureShopPlaceholderItem (a Tool wrapping the
--   CreatureBall_Slimey mesh) into the player's Backpack, renamed to the
--   specific creature purchased. This is a PLACEHOLDER VISUAL -- every
--   creature tier currently looks the same (the slimey ball mesh) since
--   there are no real per-creature assets yet. Swap the clone source for
--   real per-item models whenever those exist; nothing else needs to change.
--   NOTE: not yet saved to DataStore -- Backpack contents reset on
--   respawn/rejoin until a real inventory persistence system is added.
-- - Every other shop (Ball/TradingPost/Vault/Upgrade): still uses the
--   original lightweight IntValue counter under player.PurchasedItems,
--   since those don't have a placeholder asset to grant yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local purchaseEvent = ReplicatedStorage:WaitForChild("MiddleShopPurchaseEvent")
local creaturePlaceholderTemplate = ServerStorage:WaitForChild("CreatureShopPlaceholderItem")

-- Whitelist of shop configs this handler is allowed to sell from. Using an
-- explicit list (rather than requiring whatever name the client sends)
-- prevents a client from asking the server to require() something else.
local ALLOWED_CONFIG_NAMES = {
	"CreatureShopConfig",
	"BallShopConfig",
	"TradingPostConfig",
	"VaultConfig",
	"UpgradeShopConfig",
}

local loadedConfigs = {}
for _, configName in ipairs(ALLOWED_CONFIG_NAMES) do
	local configModule = ReplicatedStorage:FindFirstChild(configName)
	if configModule then
		loadedConfigs[configName] = require(configModule)
	else
		warn("[MiddleShopPurchaseHandler] Missing config module: " .. configName)
	end
end

local function findItem(config, itemId)
	for _, item in ipairs(config) do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

-- Generic placeholder tracking (used by every shop, in addition to any
-- real item granting) -- a simple owned-quantity counter.
local function incrementPurchasedItemsCounter(player, item)
	local purchasedItems = player:FindFirstChild("PurchasedItems")
	if not purchasedItems then
		purchasedItems = Instance.new("Folder")
		purchasedItems.Name = "PurchasedItems"
		purchasedItems.Parent = player
	end

	local ownedCount = purchasedItems:FindFirstChild(item.id)
	if ownedCount then
		ownedCount.Value += 1
	else
		ownedCount = Instance.new("IntValue")
		ownedCount.Name = item.id
		ownedCount.Value = 1
		ownedCount.Parent = purchasedItems
	end
end

-- Creature Shop only: clone the placeholder Tool into the player's Backpack
-- so the purchase is a real, visible, equippable item -- not just a number.
local function grantCreaturePlaceholderTool(player, item)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		warn("[MiddleShopPurchaseHandler] " .. player.Name .. " has no Backpack -- cannot grant creature item.")
		return
	end

	local toolClone = creaturePlaceholderTemplate:Clone()
	toolClone.Name = item.name
	toolClone.Parent = backpack
end

local function onPurchaseRequested(player, configName, itemId)
	-- Validate the shop is one we actually recognize.
	if type(configName) ~= "string" or not loadedConfigs[configName] then
		purchaseEvent:FireClient(player, false, "Unknown shop.")
		return
	end

	local config = loadedConfigs[configName]
	local item = findItem(config, itemId)
	if not item then
		purchaseEvent:FireClient(player, false, "Item not found.")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash then
		purchaseEvent:FireClient(player, false, "Could not read your cash balance.")
		return
	end

	if cash.Value < item.cost then
		purchaseEvent:FireClient(player, false, string.format("Not enough cash for %s (need %s).", item.name, item.priceText))
		return
	end

	-- Deduct first, then grant -- no yields happen between the funds check
	-- above and this line, so this is safe against double-spend from rapid
	-- repeated requests.
	cash.Value -= item.cost
	incrementPurchasedItemsCounter(player, item)

	if configName == "CreatureShopConfig" then
		grantCreaturePlaceholderTool(player, item)
	end

	purchaseEvent:FireClient(player, true, string.format("Purchased %s for %s!", item.name, item.priceText))
end

purchaseEvent.OnServerEvent:Connect(onPurchaseRequested)

print("[MiddleShopPurchaseHandler] Ready. Loaded " .. #ALLOWED_CONFIG_NAMES .. " shop configs.")
