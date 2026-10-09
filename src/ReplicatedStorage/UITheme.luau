-- UITheme (theme selector)
--
-- ======================================================================
--  FLIP THE HUD'S LOOK BY CHANGING WHICH LINE BELOW IS COMMENTED OUT.
--  Then re-sync Rojo and press Play (Stop first -- the HUD is built at
--  runtime, so a running playtest will not pick up the change).
-- ======================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local ACTIVE_THEME = "UITheme_Production"
local ACTIVE_THEME = "UITheme_Prototype"

-- This module holds no values of its own. Every consumer requires UITheme and
-- gets whichever table ACTIVE_THEME names, so one edit here restyles the whole
-- HUD: MainHUDBuilder, ShopRowBuilder, CashPackPanelController and
-- MainHUDController all read through this indirection.
--
-- The switch lives here rather than in MainHUDBuilder because those other
-- three require the theme independently -- a constant inside the builder would
-- only ever reach the builder's own panels, leaving every shop row and
-- cash-pack row at production colours.
--
-- UITheme_Prototype started as an exact copy of UITheme_Production. It is a
-- copy, not an override layer, so a key added to one is NOT added to the other;
-- if a consumer ever reads a key the active theme lacks it will get nil. Keep
-- the two files' key sets in step when adding anything new.

return require(ReplicatedStorage:WaitForChild(ACTIVE_THEME))
