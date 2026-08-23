--!strict
--[[
	PlotTheme
	Reusable server-owned theming for plot props.
	Requiring this module has no side effects.
]]

local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent.PlotThemeConfig)

local PlotTheme = {}
local FALLBACK_COLOR = Color3.fromRGB(150, 150, 150)

local function ensureReadable(color: Color3): Color3
	if not Config.EnforceMinBrightness then
		return color
	end

	local hue, saturation, value = color:ToHSV()
	if value < Config.MinBrightness then
		value = Config.MinBrightness
	end
	return Color3.fromHSV(hue, saturation, value)
end

local function isThemePart(instance: Instance): boolean
	return instance:IsA("BasePart")
		and instance.Name:sub(1, #Config.ThemePrefix) == Config.ThemePrefix
end

function PlotTheme.GetOwningPlot(instance: Instance): Instance?
	local node: Instance? = instance
	while node do
		if node.Name:match("^P%d+$") then
			return node
		end
		node = node.Parent
	end
	return nil
end

function PlotTheme.GetPlotColor(plot: Instance): Color3
	local attributeColor = plot:GetAttribute("PlotColor")
	if typeof(attributeColor) == "Color3" then
		return attributeColor
	end

	local configuredColor = Config.PlotColors[plot.Name]
	if configuredColor then
		plot:SetAttribute("PlotColor", configuredColor)
		return configuredColor
	end

	warn(("[PlotTheme] No color configured for %s; using fallback grey."):format(plot:GetFullName()))
	return FALLBACK_COLOR
end

function PlotTheme.ApplyToModel(model: Instance, color: Color3): number
	local tint = ensureReadable(color)
	local themeFolder = model:FindFirstChild(Config.ThemeFolderName)
	local changedCount = 0

	if themeFolder then
		for _, instance in ipairs(themeFolder:GetDescendants()) do
			if instance:IsA("BasePart") then
				instance.Color = tint
				changedCount += 1
			end
		end
	end

	-- Recolor and report misplaced Theme_ parts so hierarchy mistakes stay visible.
	for _, instance in ipairs(model:GetDescendants()) do
		if isThemePart(instance)
			and not (themeFolder and instance:IsDescendantOf(themeFolder))
		then
			instance.Color = tint
			changedCount += 1
			warn(("[PlotTheme] %s is outside %s; move it into that folder."):format(
				instance:GetFullName(),
				Config.ThemeFolderName
			))
		end
	end

	if changedCount == 0 then
		warn(("[PlotTheme] No theme parts found in %s"):format(model:GetFullName()))
	end
	return changedCount
end

function PlotTheme.ApplyToAccentPart(part: BasePart, color: Color3)
	part.Color = ensureReadable(color)
end

function PlotTheme.ApplyToPlot(plot: Instance): number
	local color = PlotTheme.GetPlotColor(plot)
	local totalChanged = 0

	for _, model in ipairs(CollectionService:GetTagged(Config.Tag)) do
		if model:IsDescendantOf(plot) then
			totalChanged += PlotTheme.ApplyToModel(model, color)
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(Config.AccentPartTag)) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(plot) then
			PlotTheme.ApplyToAccentPart(instance, color)
			totalChanged += 1
		end
	end

	return totalChanged
end

function PlotTheme.SetPlotColor(plot: Instance, color: Color3): number
	if plot:GetAttribute("PlotColor") == color then
		return PlotTheme.ApplyToPlot(plot)
	end

	-- PlotThemeService listens to this attribute and performs the recolor.
	plot:SetAttribute("PlotColor", color)
	return 0
end

return PlotTheme
