--!strict
-- Arrow Bounce Platform visual contract for Game1.
-- Accent parts follow the owning plot color while remaining non-glowing.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotTheme = require(ReplicatedStorage:WaitForChild("PlotTheme"))
local PlotThemeConfig = require(ReplicatedStorage:WaitForChild("PlotThemeConfig"))

local BouncePlatformTheme = {}

local ACCENT_PARTS: { [string]: boolean } = {
	Spring_Core = true,
	Accent_Panels = true,
	Arrow_Icon = true,
}

local FIXED_PARTS: { [string]: boolean } = {
	Base_Ring = true,
	Top_Pad = true,
}

local FIXED_COLOR = Color3.fromRGB(46, 50, 58)
local GHOST_COLOR = Color3.fromRGB(105, 110, 120)
local GHOST_TRANSPARENCY = 0.65

BouncePlatformTheme.ExpectedPartCount = 5
BouncePlatformTheme.ExpectedAccentCount = 3

local function isVisualPart(instance: Instance): boolean
	return instance:IsA("BasePart")
		and (ACCENT_PARTS[instance.Name] == true or FIXED_PARTS[instance.Name] == true)
end

function BouncePlatformTheme.GetVisualParts(model: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if isVisualPart(descendant) then
			table.insert(parts, descendant :: BasePart)
		end
	end
	return parts
end

function BouncePlatformTheme.GetPlotColor(plot: Instance): Color3
	return PlotTheme.GetPlotColor(plot)
end

function BouncePlatformTheme.ApplyLocked(model: Instance): number
	local parts = BouncePlatformTheme.GetVisualParts(model)
	for _, part in ipairs(parts) do
		CollectionService:RemoveTag(part, PlotThemeConfig.AccentPartTag)
		part.Color = GHOST_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = GHOST_TRANSPARENCY
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
	end

	if #parts ~= BouncePlatformTheme.ExpectedPartCount then
		warn(("[BouncePlatformTheme] Locked model has %d/%d visual parts.")
			:format(#parts, BouncePlatformTheme.ExpectedPartCount))
	end
	return #parts
end

function BouncePlatformTheme.ApplyUnlocked(model: Instance, themeColor: Color3): number
	if typeof(themeColor) ~= "Color3" then
		warn("[BouncePlatformTheme] ApplyUnlocked requires a Color3.")
		return 0
	end

	local parts = BouncePlatformTheme.GetVisualParts(model)
	local accentCount = 0

	for _, part in ipairs(parts) do
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0
		part.Anchored = true
		part.CanTouch = false
		part.CanQuery = true
		part.CastShadow = false

		if ACCENT_PARTS[part.Name] then
			part.Color = themeColor
			part.CanCollide = false
			CollectionService:AddTag(part, PlotThemeConfig.AccentPartTag)
			accentCount += 1
		else
			part.Color = FIXED_COLOR
			part.CanCollide = true
			CollectionService:RemoveTag(part, PlotThemeConfig.AccentPartTag)
		end
	end

	model:SetAttribute("ThemeColor", themeColor)
	model:SetAttribute("AccentPartCount", accentCount)

	if #parts ~= BouncePlatformTheme.ExpectedPartCount then
		warn(("[BouncePlatformTheme] Unlocked model has %d/%d visual parts.")
			:format(#parts, BouncePlatformTheme.ExpectedPartCount))
	end
	if accentCount ~= BouncePlatformTheme.ExpectedAccentCount then
		warn(("[BouncePlatformTheme] Unlocked model has %d/%d accent parts.")
			:format(accentCount, BouncePlatformTheme.ExpectedAccentCount))
	end
	return accentCount
end

return BouncePlatformTheme
