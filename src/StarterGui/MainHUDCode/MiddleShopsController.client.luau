-- MiddleShopsController
-- Wires up the NPC shops in Workspace.MiddleShops: builds each shop's
-- item rows from its config (same ShopRowBuilder used by the main Shop
-- panel), registers each panel with the shared PanelManager, opens the
-- right panel when the player triggers that shop's ProximityPrompt, and
-- wires Buy buttons to a real in-game Cash purchase (server-authoritative
-- via MiddleShopPurchaseEvent -- NOT the Robux flow the main Shop uses).
--
-- To add a 6th shop later: create its config module, add one panel using
-- the same chrome as the others, and add one entry to SHOP_DEFINITIONS below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))
local ShopRowBuilder = require(ReplicatedStorage:WaitForChild("ShopRowBuilder"))

local purchaseEvent = ReplicatedStorage:WaitForChild("MiddleShopPurchaseEvent")

local gui = script.Parent
local middleShops = Workspace:WaitForChild("MiddleShops")

-- Maps each shop to: its panel name in this ScreenGui, its config module in
-- ReplicatedStorage, and the path (relative to MiddleShops) to the NPC's
-- ProximityPrompt.
--
-- Every entry's panel and config must actually exist: the loop below resolves
-- both with a no-timeout WaitForChild, so a missing one stalls it and leaves
-- the remaining shops unwired. The Bank has a structure in Workspace but no
-- panel yet, so it is deliberately absent.
local SHOP_DEFINITIONS = {
	{
		panelName = "CreatureShopPanel",
		configName = "CreatureShopConfig",
		promptPath = { "CreatureShopStructure", "CreatureShopKeeper", "Body", "InteractPrompt" },
		promptActionText = "Shop",
		promptObjectText = "Creature Shop",
		logPrefix = "[CreatureShop]",
	},
	{
		panelName = "BallShopPanel",
		configName = "BallShopConfig",
		promptPath = { "BallShopStructure", "BallShopKeeper", "Body", "InteractPrompt" },
		promptActionText = "Shop",
		promptObjectText = "Ball Shop",
		logPrefix = "[BallShop]",
	},
	{
		panelName = "GearShopPanel",
		configName = "GearShopConfig",
		promptPath = { "GearShopStructure", "GearShopKeeper", "Body", "InteractPrompt" },
		promptActionText = "Shop",
		promptObjectText = "Gear Shop",
		logPrefix = "[GearShop]",
	},
}

local function resolvePath(root, pathParts)
	local current = root
	for _, partName in ipairs(pathParts) do
		current = current:WaitForChild(partName, 5)
		if not current then
			return nil
		end
	end
	return current
end

-- Builds the Buy-button handler for one shop: fires the purchase request to
-- the server with (configName, itemId) only -- never a price. The server
-- looks up the real cost itself from its own copy of the same config, so
-- there's nothing here a client could tamper with to buy for less.
local function makeCashPurchaseHandler(configName)
	return function(item)
		purchaseEvent:FireServer(configName, item.id)
	end
end

-- Server responds with (success, message) after every purchase attempt.
-- Simple print/warn feedback for now -- swap for a toast/notification UI
-- later if you want something more visible than the Output window.
purchaseEvent.OnClientEvent:Connect(function(success, message)
	if success then
		print("[MiddleShops] " .. message)
	else
		warn("[MiddleShops] Purchase failed: " .. message)
	end
end)

for _, definition in ipairs(SHOP_DEFINITIONS) do
	local panel = gui:WaitForChild(definition.panelName)
	local config = require(ReplicatedStorage:WaitForChild(definition.configName))

	-- Build this shop's rows (wired to a Cash purchase, not Robux) and
	-- register it in the shared panel system.
	ShopRowBuilder.buildRows(panel.ItemList, config, definition.logPrefix, makeCashPurchaseHandler(definition.configName))
	PanelManager.registerPanel(panel)

	panel.TitleBar.CloseButton.MouseButton1Click:Connect(function()
		PanelManager.closeAll()
	end)

	-- Wire the NPC's ProximityPrompt.
	local prompt = resolvePath(middleShops, definition.promptPath)
	if not prompt then
		warn(definition.logPrefix .. " could not find its ProximityPrompt at the expected path -- panel will not open from the NPC.")
		continue
	end

	prompt.ActionText = definition.promptActionText
	prompt.ObjectText = definition.promptObjectText

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then
			return
		end
		PanelManager.open(panel)
	end)
end

print("[MiddleShopsController] Wired " .. #SHOP_DEFINITIONS .. " shop panels.")

