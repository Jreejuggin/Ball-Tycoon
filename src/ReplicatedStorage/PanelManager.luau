-- PanelManager
-- Shared single-panel-exclusive system: any script can register a panel
-- Frame here, and opening one automatically closes every other registered
-- panel. This is what keeps Settings/Shop/Pets/CashPack (and now the
-- MiddleShops panels) from ever stacking on top of each other, without
-- every script needing its own copy of that logic.
--
-- A panel with tabs registers a selectTab(tabName) function as well, and can
-- then be opened straight to a tab: PanelManager.open(panel, "gems"). Opening
-- a tab on a panel that is already open just switches tabs -- it does not
-- close and reopen the panel. Calls without a tab behave exactly as before.

local PanelManager = {}

local registeredPanels = {}
local tabSelectors = {}
local activeTabs = {}

function PanelManager.registerPanel(panel, selectTab)
	table.insert(registeredPanels, panel)
	tabSelectors[panel] = selectTab
end

function PanelManager.closeAll()
	for _, panel in ipairs(registeredPanels) do
		panel.Visible = false
	end
end

local function selectTab(panel, tabName)
	local selector = tabSelectors[panel]
	if not selector then
		warn("[PanelManager] " .. panel.Name .. " was asked for tab '" .. tostring(tabName) .. "' but registered no tabs.")
		return
	end
	selector(tabName)
	activeTabs[panel] = tabName
end

function PanelManager.open(panel, tabName)
	if tabName ~= nil then
		selectTab(panel, tabName)
		if panel.Visible then
			return
		end
	end
	PanelManager.closeAll()
	panel.Visible = true
end

-- With a tab: closes the panel only if it is open on that same tab, and
-- otherwise opens it there (switching tabs if it is already open).
function PanelManager.toggle(panel, tabName)
	if tabName ~= nil then
		if panel.Visible and activeTabs[panel] == tabName then
			PanelManager.closeAll()
		else
			PanelManager.open(panel, tabName)
		end
		return
	end

	local willOpen = not panel.Visible
	PanelManager.closeAll()
	panel.Visible = willOpen
end

return PanelManager
