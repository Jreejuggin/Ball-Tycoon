-- Tooltip
-- Shared hover-tooltip system. Uses ONE reusable label (StarterGui.MainHUD.Tooltip)
-- instead of creating a new instance per button, and follows the mouse via
-- GuiObject.MouseMoved (which reports screen-space coordinates, so setting
-- the label's Position directly from those keeps it glued near the cursor).
--
-- Usage:
--   local Tooltip = require(ReplicatedStorage.Tooltip)
--   Tooltip.attach(someButton, "Settings")
--   Tooltip.attach(someButton, "Teleport to Tycoon", { offsetX = 20, offsetY = -12 })

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Tooltip = {}

local tooltipLabel

local function getTooltipLabel()
	if not tooltipLabel then
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD")
		tooltipLabel = gui:WaitForChild("Tooltip")
	end
	return tooltipLabel
end

-- Attaches hover-tooltip behavior to `button`, showing `text` near the
-- cursor while hovered. Safe to call once per button at setup time.
function Tooltip.attach(button, text, options)
	options = options or {}
	local offsetX = options.offsetX or 16
	local offsetY = options.offsetY or -10

	button.MouseEnter:Connect(function()
		local label = getTooltipLabel()
		label.Text = text
		label.Visible = true
	end)

	button.MouseMoved:Connect(function(x, y)
		local label = getTooltipLabel()
		label.Position = UDim2.fromOffset(x + offsetX, y + offsetY)
	end)

	button.MouseLeave:Connect(function()
		local label = getTooltipLabel()
		label.Visible = false
	end)
end

return Tooltip
