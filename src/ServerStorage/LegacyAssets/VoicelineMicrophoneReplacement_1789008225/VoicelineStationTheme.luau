--!strict
-- VoicelineStationTheme
-- Owns the imported station's accent-part contract. Apply remains compatible
-- with named themes, while ApplyColor lets stations follow saved plot colors.
local VoicelineStationTheme = {}

local ACCENT_PARTS: { [string]: boolean } = {
	VS_Base_Accent = true,
	VS_FrontPanel_Accent = true,
	VS_TopRing_Accent = true,
	VS_SpeechBubble_Accent = true,
	VS_SpeechBubble_Tail = true,
	VS_Mic_Stem = true,
	VS_Mic_Outer_Accent = true,
	VS_Mic_Center_Accent = true,
}

VoicelineStationTheme.ExpectedAccentCount = 8
VoicelineStationTheme.BaseColor = Color3.fromRGB(35, 36, 38)

VoicelineStationTheme.Themes = {
	Purple = Color3.fromHex("A855F7"),
	Cyan = Color3.fromHex("22D3EE"),
	Green = Color3.fromHex("84CC16"),
	Orange = Color3.fromHex("FF5A36"),
	Blue = Color3.fromHex("3B82F6"),
	Pink = Color3.fromHex("EC4899"),
	Yellow = Color3.fromHex("FACC15"),
	Red = Color3.fromHex("EF4444"),
}

function VoicelineStationTheme.IsAccentPart(instance: Instance): boolean
	return instance:IsA("BasePart") and ACCENT_PARTS[instance.Name] == true
end

function VoicelineStationTheme.GetAccentParts(station: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in ipairs(station:GetDescendants()) do
		if VoicelineStationTheme.IsAccentPart(descendant) then
			table.insert(parts, descendant :: BasePart)
		end
	end
	return parts
end

-- Imported material slots were flattened to light gray. Keep every neutral
-- station mesh on the same dark base color while excluding pad/collision parts.
function VoicelineStationTheme.ApplyBaseColor(station: Instance): number
	local buyPad = station:FindFirstChild("BuyPad")
	local collisionFolder = station:FindFirstChild("Collision")
	local changed = 0

	for _, descendant in ipairs(station:GetDescendants()) do
		if descendant:IsA("BasePart")
			and not VoicelineStationTheme.IsAccentPart(descendant)
			and not (buyPad and descendant:IsDescendantOf(buyPad))
			and not (collisionFolder and descendant:IsDescendantOf(collisionFolder))
		then
			descendant.Color = VoicelineStationTheme.BaseColor
			changed += 1
		end
	end

	station:SetAttribute("BaseColor", VoicelineStationTheme.BaseColor)
	return changed
end

-- Applies an exact color so the station follows the existing per-plot palette
-- and any saved custom PlotColor selected by the player.
function VoicelineStationTheme.ApplyColor(
	station: Instance,
	color: Color3,
	themeName: string?
): number
	if typeof(color) ~= "Color3" then
		warn("VoicelineStationTheme.ApplyColor requires a Color3")
		return 0
	end

	VoicelineStationTheme.ApplyBaseColor(station)

	local changed = 0
	for _, part in ipairs(VoicelineStationTheme.GetAccentParts(station)) do
		part.Color = color
		part.Material = Enum.Material.Neon
		changed += 1
	end

	station:SetAttribute("Theme", themeName or "Custom")
	station:SetAttribute("ThemeColor", color)
	return changed
end

-- Applies one of the named themes from the original model specification.
function VoicelineStationTheme.Apply(station: Instance, themeName: string): number
	local color = VoicelineStationTheme.Themes[themeName]
	if not color then
		warn(("VoicelineStationTheme: unknown theme %q"):format(tostring(themeName)))
		return 0
	end

	return VoicelineStationTheme.ApplyColor(station, color, themeName)
end

return VoicelineStationTheme
