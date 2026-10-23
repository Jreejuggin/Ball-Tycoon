-- ShopPanelController
-- Builds the Shop panel's rows from ReplicatedStorage.ShopConfig using the
-- shared ShopRowBuilder (same builder used by CashPack and the MiddleShops
-- panels). Adding a new item never requires touching this script -- just
-- add an entry to ShopConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local ShopRowBuilder = require(ReplicatedStorage:WaitForChild("ShopRowBuilder"))
local Theme = require(ReplicatedStorage:WaitForChild("UITheme"))

-- The panel is built at runtime by MainHUDBuilder, so this can no longer be a
-- LocalScript parented to it. MainHUDController passes in the row container
-- straight from the builder's refs, so this never looks it up by name.
return function(itemList)
	-- The Shop's own row style when the theme has one (the prototype's red
	-- rows); otherwise nil, and the rows take the shared Theme.row.
	ShopRowBuilder.buildRows(itemList, ShopConfig, "[Shop]", nil, Theme.shopPanel.row)
end

