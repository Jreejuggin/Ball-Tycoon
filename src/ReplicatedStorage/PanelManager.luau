-- PanelManager
-- Shared single-panel-exclusive system: any script can register a panel
-- Frame here, and opening one automatically closes every other registered
-- panel. This is what keeps Settings/Shop/Pets/CashPack (and now the
-- MiddleShops panels) from ever stacking on top of each other, without
-- every script needing its own copy of that logic.

local PanelManager = {}

local registeredPanels = {}

function PanelManager.registerPanel(panel)
	table.insert(registeredPanels, panel)
end

function PanelManager.closeAll()
	for _, panel in ipairs(registeredPanels) do
		panel.Visible = false
	end
end

function PanelManager.open(panel)
	PanelManager.closeAll()
	panel.Visible = true
end

function PanelManager.toggle(panel)
	local willOpen = not panel.Visible
	PanelManager.closeAll()
	panel.Visible = willOpen
end

return PanelManager
