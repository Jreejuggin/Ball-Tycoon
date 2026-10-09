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
local ButtonHoverEffect = require(ReplicatedStorage:WaitForChild("ButtonHoverEffect"))

local purchaseEvent = ReplicatedStorage:WaitForChild("MiddleShopPurchaseEvent")

local gui = script.Parent
local middleShops = Workspace:WaitForChild("MiddleShops")

-- build() is idempotent, so calling it here is safe regardless of whether
-- MainHUDController (the other LocalScript in this ScreenGui) got there first.
-- It hands back named references, so this script never looks a panel, its row
-- container or its close button up by name.
local MainHUDBuilder = require(gui:WaitForChild("MainHUDBuilder"))
local refs = MainHUDBuilder.build(gui)

-- Maps each shop to: its builder ref key, its config module in
-- ReplicatedStorage, and the path (relative to MiddleShops) to the NPC's
-- ProximityPrompt.
--
-- panelKey indexes MainHUDBuilder's refs rather than naming an instance, so a
-- redesign can rename or re-parent the panel without touching this table. Each
-- key must exist in the builder's MIDDLE_SHOPS list. The Bank has a structure
-- in Workspace but no panel yet, so it is deliberately absent.
local SHOP_DEFINITIONS = {
	{
		panelKey = "creature",
		configName = "CreatureShopConfig",
		promptPath = { "CreatureShopStructure", "CreatureShopKeeper", "Body", "InteractPrompt" },
		promptActionText = "Shop",
		promptObjectText = "Creature Shop",
		logPrefix = "[CreatureShop]",
	},
	{
		panelKey = "ball",
		configName = "BallShopConfig",
		promptPath = { "BallShopStructure", "BallShopKeeper", "Body", "InteractPrompt" },
		promptActionText = "Shop",
		promptObjectText = "Ball Shop",
		logPrefix = "[BallShop]",
	},
	{
		panelKey = "gear",
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
	local shopRefs = refs.middleShops[definition.panelKey]
	local panel = shopRefs.panel
	local config = require(ReplicatedStorage:WaitForChild(definition.configName))

	-- Build this shop's rows (wired to a Cash purchase, not Robux) and
	-- register it in the shared panel system.
	ShopRowBuilder.buildRows(shopRefs.itemList, config, definition.logPrefix, makeCashPurchaseHandler(definition.configName))
	PanelManager.registerPanel(panel)

	local closeButton = shopRefs.closeButton
	closeButton.MouseButton1Click:Connect(function()
		PanelManager.closeAll()
	end)

	-- Buy buttons get this from ShopRowBuilder; without it these close buttons
	-- were the only shop buttons with no hover animation or sound.
	ButtonHoverEffect.apply(closeButton)

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

