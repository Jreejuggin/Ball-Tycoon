-- Only the microphone's painted shell follows the plot palette.
-- Neutral grille/grips and yellow lamps preserve the imported design.
local Theme = {}
local ACCENTS = {
	MIC_Body_Red = true,
	MIC_Foot_Red = true,
	MIC_ButtonOuter_Red = true,
	MIC_NeckLower_Red = true,
	MIC_NeckUpper_Red = true,
}
Theme.ExpectedAccentCount = 5
Theme.BaseColor = Color3.fromRGB(23, 28, 42)
Theme.LightColor = Color3.fromRGB(255, 229, 41)

function Theme.IsAccentPart(part)
	return part:IsA("BasePart") and ACCENTS[part.Name] == true
end

function Theme.GetVisualParts(station)
	local parts = {}
	local visual = station:FindFirstChild("VoicelineMicrophone_Roblox")
	if visual then
		for _, part in ipairs(visual:GetDescendants()) do
			if part:IsA("BasePart") then table.insert(parts, part) end
		end
	end
	return parts
end

function Theme.GetAccentParts(station)
	local parts = {}
	for _, part in ipairs(Theme.GetVisualParts(station)) do
		if Theme.IsAccentPart(part) then table.insert(parts, part) end
	end
	return parts
end

function Theme.ApplyColor(station, color, themeName)
	assert(typeof(color) == "Color3", "Expected a plot Color3")
	local count = 0
	for _, part in ipairs(Theme.GetVisualParts(station)) do
		part.Reflectance = 0
		if Theme.IsAccentPart(part) then
			part.Color = color
			part.Material = Enum.Material.SmoothPlastic
			count += 1
		elseif part.Name:match("_Yellow$") then
			part.Color = Theme.LightColor
			part.Material = Enum.Material.Neon
		elseif part.Name == "MIC_Grille_Base" then
			part.Color = Color3.fromRGB(48, 55, 75)
			part.Material = Enum.Material.Metal
		else
			part.Color = Theme.BaseColor
			part.Material = Enum.Material.SmoothPlastic
		end
	end
	station:SetAttribute("Theme", themeName or "Custom")
	station:SetAttribute("ThemeColor", color)
	return count
end

return Theme
