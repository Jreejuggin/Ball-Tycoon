--!strict
-- Speed Upgrade Treadmill visual contract for Game1.
-- Only Accent_All, Belt_Arrows, and Console_Buttons follow the owning plot color.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotTheme = require(ReplicatedStorage:WaitForChild("PlotTheme"))

local TreadmillTheme = {}

local ACCENT_PARTS: { [string]: boolean } = {
	Accent_All = true,
	Belt_Arrows = true,
	Console_Buttons = true,
}

local FIXED_PARTS: { [string]: { color: Color3, material: Enum.Material } } = {
	Base_Main = {
		color = Color3.fromRGB(43, 47, 54),
		material = Enum.Material.SmoothPlastic,
	},
	Frame_Main = {
		color = Color3.fromRGB(43, 47, 54),
		material = Enum.Material.SmoothPlastic,
	},
	Console_Frame = {
		color = Color3.fromRGB(43, 47, 54),
		material = Enum.Material.SmoothPlastic,
	},
	Belt_Main = {
		color = Color3.fromRGB(13, 15, 18),
		material = Enum.Material.SmoothPlastic,
	},
	Console_Screen = {
		color = Color3.fromRGB(8, 19, 26),
		material = Enum.Material.SmoothPlastic,
	},
}

local GHOST_COLOR = Color3.fromRGB(105, 110, 120)
local GHOST_TRANSPARENCY = 0.65

TreadmillTheme.ExpectedPartCount = 8
TreadmillTheme.ExpectedAccentCount = 3

local function isVisualPart(instance: Instance): boolean
	return instance:IsA("BasePart")
		and (ACCENT_PARTS[instance.Name] == true or FIXED_PARTS[instance.Name] ~= nil)
end

function TreadmillTheme.GetVisualParts(model: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if isVisualPart(descendant) then
			table.insert(parts, descendant :: BasePart)
		end
	end
	return parts
end

function TreadmillTheme.GetPlotColor(plot: Instance): Color3
	return PlotTheme.GetPlotColor(plot)
end

function TreadmillTheme.ApplyLocked(model: Instance): number
	local parts = TreadmillTheme.GetVisualParts(model)
	for _, part in ipairs(parts) do
		part.Color = GHOST_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = GHOST_TRANSPARENCY
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
	end

	if #parts ~= TreadmillTheme.ExpectedPartCount then
		warn(("[TreadmillTheme] Locked model has %d/%d visual parts.")
			:format(#parts, TreadmillTheme.ExpectedPartCount))
	end
	return #parts
end

function TreadmillTheme.ApplyUnlocked(model: Instance, themeColor: Color3): number
	if typeof(themeColor) ~= "Color3" then
		warn("[TreadmillTheme] ApplyUnlocked requires a Color3.")
		return 0
	end

	local parts = TreadmillTheme.GetVisualParts(model)
	local accentCount = 0

	for _, part in ipairs(parts) do
		part.Transparency = 0
		part.Anchored = true
		part.CanTouch = false
		part.CanQuery = true
		part.CastShadow = false

		if ACCENT_PARTS[part.Name] then
			part.Color = themeColor
			-- Match the same non-glowing plot color used by other themed models.
			part.Material = Enum.Material.SmoothPlastic
			part.CanCollide = false
			accentCount += 1
		else
			local definition = FIXED_PARTS[part.Name]
			if definition then
				part.Color = definition.color
				part.Material = definition.material
			end

			-- CollisionFidelity is authored once on the stored template in Edit mode;
			-- live server scripts do not have permission to write that property.
			part.CanCollide = part.Name == "Base_Main" or part.Name == "Frame_Main"
		end
	end

	model:SetAttribute("ThemeColor", themeColor)
	model:SetAttribute("AccentPartCount", accentCount)

	if #parts ~= TreadmillTheme.ExpectedPartCount then
		warn(("[TreadmillTheme] Unlocked model has %d/%d visual parts.")
			:format(#parts, TreadmillTheme.ExpectedPartCount))
	end
	if accentCount ~= TreadmillTheme.ExpectedAccentCount then
		warn(("[TreadmillTheme] Unlocked model has %d/%d accent parts.")
			:format(accentCount, TreadmillTheme.ExpectedAccentCount))
	end
	return accentCount
end

return TreadmillTheme
