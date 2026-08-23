--!strict
-- WorkerNotesGiftsStationTheme
-- Exact color contract for the 42 imported Worker Notes & Gifts station meshes.
-- Only the 11 accent meshes follow PlotColor; the other 31 always keep fixed colors.
local WorkerNotesGiftsStationTheme = {}

local ACCENT_PARTS: { [string]: boolean } = {
	WGS_Base_Accent = true,
	WGS_PillarAccent_Left = true,
	WGS_PillarAccent_Right = true,
	WGS_MailSlot_Accent = true,
	WGS_Shelf_Accent = true,
	WGS_Backboard_TopAccent = true,
	WGS_BackboardGift_Box = true,
	WGS_FrontIcon_Envelope = true,
	WGS_FrontIcon_Gift = true,
	WGS_FrontIcon_GiftBow = true,
	WGS_Gift_Box = true,
}

type FixedDefinition = {
	color: Color3,
	material: Enum.Material,
}

local FIXED_PARTS: { [string]: FixedDefinition } = {}

local function assignFixed(names: { string }, color: Color3, material: Enum.Material)
	for _, name in ipairs(names) do
		FIXED_PARTS[name] = {
			color = color,
			material = material,
		}
	end
end

assignFixed({
	"WGS_Base_Lower", "WGS_Base_Upper", "WGS_Body",
	"WGS_Pillar_Left", "WGS_Pillar_Right",
	"WGS_Pin_Blue", "WGS_Pin_Cream", "WGS_Pin_Pink",
	"WGS_BackboardGift_Ribbon",
}, Color3.fromRGB(17, 19, 24), Enum.Material.SmoothPlastic)

assignFixed({
	"WGS_Counter", "WGS_Shelf", "WGS_Backboard_Frame",
	"WGS_BackSupport_Left", "WGS_BackSupport_Right",
	"WGS_FrontPanel_Frame", "WGS_MailSlot_Frame",
	"WGS_NoteLines_Blue", "WGS_NoteLines_Cream", "WGS_NoteLines_Pink",
}, Color3.fromRGB(37, 41, 50), Enum.Material.SmoothPlastic)

assignFixed({
	"WGS_FrontPanel_Inset", "WGS_Backboard_Inset", "WGS_MailSlot_Interior",
	"WGS_FrontIcon_EnvFolds", "WGS_FrontIcon_GiftRibbon",
}, Color3.fromRGB(8, 10, 15), Enum.Material.SmoothPlastic)

assignFixed({
	"WGS_Envelope", "WGS_Note_Cream",
}, Color3.fromRGB(234, 214, 176), Enum.Material.SmoothPlastic)

assignFixed({
	"WGS_Gift_Ribbon", "WGS_Gift_Bow",
}, Color3.fromRGB(245, 184, 46), Enum.Material.Metal)

assignFixed({
	"WGS_Note_Blue",
}, Color3.fromRGB(110, 168, 199), Enum.Material.SmoothPlastic)

assignFixed({
	"WGS_Note_Pink",
}, Color3.fromRGB(217, 139, 166), Enum.Material.SmoothPlastic)

assignFixed({
	"WGS_Envelope_Seal",
}, Color3.fromRGB(228, 80, 107), Enum.Material.SmoothPlastic)

WorkerNotesGiftsStationTheme.ExpectedAccentCount = 11
WorkerNotesGiftsStationTheme.ExpectedFixedCount = 31
WorkerNotesGiftsStationTheme.ExpectedVisualPartCount = 42
WorkerNotesGiftsStationTheme.DefaultAccentColor = Color3.fromRGB(168, 85, 247)

local function isExcluded(station: Instance, instance: Instance): boolean
	local buyPad = station:FindFirstChild("BuyPad")
	local collisionFolder = station:FindFirstChild("Collision")
	return (buyPad ~= nil and instance:IsDescendantOf(buyPad))
		or (collisionFolder ~= nil and instance:IsDescendantOf(collisionFolder))
end

function WorkerNotesGiftsStationTheme.IsAccentPart(instance: Instance): boolean
	return instance:IsA("BasePart") and ACCENT_PARTS[instance.Name] == true
end

function WorkerNotesGiftsStationTheme.GetVisualParts(station: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in ipairs(station:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant.Name:sub(1, 4) == "WGS_"
			and not isExcluded(station, descendant)
		then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- Applies all 31 fixed colors. Safe to call repeatedly.
function WorkerNotesGiftsStationTheme.ApplyFixedColors(station: Instance): number
	local changed = 0
	for _, part in ipairs(WorkerNotesGiftsStationTheme.GetVisualParts(station)) do
		local definition = FIXED_PARTS[part.Name]
		if definition then
			part.Color = definition.color
			part.Material = definition.material
			changed += 1
		end
	end
	return changed
end

-- Applies the owning plot's exact color to the 11 accents only, so saved/custom
-- plot themes stay in sync without erasing the fixed envelope, notes, or ribbons.
function WorkerNotesGiftsStationTheme.ApplyColor(
	station: Instance,
	plotColor: Color3,
	themeName: string?
): number
	if typeof(plotColor) ~= "Color3" then
		warn("WorkerNotesGiftsStationTheme.ApplyColor requires a Color3")
		return 0
	end

	local fixedCount = WorkerNotesGiftsStationTheme.ApplyFixedColors(station)
	local accentCount = 0
	for _, part in ipairs(WorkerNotesGiftsStationTheme.GetVisualParts(station)) do
		if ACCENT_PARTS[part.Name] then
			part.Color = plotColor
			-- Match the non-glowing plot accents used by the Hiring Kiosk and Worker Speed sign.
			part.Material = Enum.Material.SmoothPlastic
			accentCount += 1
		end
	end

	station:SetAttribute("Theme", themeName or "Custom")
	station:SetAttribute("ThemeColor", plotColor)
	station:SetAttribute("FixedColorPartCount", fixedCount)
	return accentCount
end

-- Compatibility wrapper for older callers. Locked/available state is shown by
-- transparency; fixed colors remain exact and accents retain a real theme color.
function WorkerNotesGiftsStationTheme.ApplyLocked(
	station: Instance,
	plotColor: Color3?
): number
	return WorkerNotesGiftsStationTheme.ApplyColor(
		station,
		plotColor or WorkerNotesGiftsStationTheme.DefaultAccentColor,
		"Locked"
	)
end

return WorkerNotesGiftsStationTheme
