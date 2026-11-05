--[[
	OfficeAttire
	Dresses a cloned worker rig in office clothes for the second floor.

	The worker templates (ServerStorage.WorkerTemplates) are construction
	workers: a HardHat accessory plus work Shirt/Pants clothing. This module
	removes those and colors the body parts instead, so it needs no uploaded
	assets. Placeholder look, easy to swap: replace a style's colors, or give
	the rig real Shirt/Pants objects later.

	Styles:
	  Suit          - charcoal suit, white collar, red tie (supervisors)
	  ExecutiveSuit - navy suit, white collar, blue tie (department manager)
	  SmartCasual   - dark vest over white sleeves, collar, no tie
	  OfficeCasual  - light blue shirt, khaki trousers, collar, no tie

	Usage: OfficeAttire.Dress(rig, "Suit")
	Call it before the rig is parented. Extra pieces are welded to the torso,
	so they follow any pose.
]]

local OfficeAttire = {}

local WHITE_SHIRT = Color3.fromRGB(240, 240, 238)
local BLACK_SHOES = Color3.fromRGB(25, 25, 28)
local BROWN_SHOES = Color3.fromRGB(80, 50, 30)

local STYLES = {
	Suit = {
		torso = Color3.fromRGB(45, 47, 54),
		sleeves = Color3.fromRGB(45, 47, 54),
		forearms = Color3.fromRGB(45, 47, 54),
		trousers = Color3.fromRGB(40, 42, 48),
		shoes = BLACK_SHOES,
		collar = WHITE_SHIRT,
		tie = Color3.fromRGB(170, 30, 40),
	},
	ExecutiveSuit = {
		torso = Color3.fromRGB(30, 40, 70),
		sleeves = Color3.fromRGB(30, 40, 70),
		forearms = Color3.fromRGB(30, 40, 70),
		trousers = Color3.fromRGB(28, 36, 62),
		shoes = BLACK_SHOES,
		collar = WHITE_SHIRT,
		tie = Color3.fromRGB(40, 90, 170),
	},
	SmartCasual = {
		torso = Color3.fromRGB(70, 80, 95),
		sleeves = WHITE_SHIRT,
		forearms = WHITE_SHIRT,
		trousers = Color3.fromRGB(55, 58, 66),
		shoes = BLACK_SHOES,
		collar = WHITE_SHIRT,
	},
	OfficeCasual = {
		torso = Color3.fromRGB(150, 190, 230),
		sleeves = Color3.fromRGB(150, 190, 230),
		forearms = Color3.fromRGB(150, 190, 230),
		trousers = Color3.fromRGB(190, 170, 130),
		shoes = BROWN_SHOES,
		collar = Color3.fromRGB(175, 210, 240),
	},
}

local PART_ROLES = {
	UpperTorso = "torso",
	Torso = "torso", -- R6
	LowerTorso = "trousers",
	LeftUpperArm = "sleeves",
	RightUpperArm = "sleeves",
	LeftLowerArm = "forearms",
	RightLowerArm = "forearms",
	["Left Arm"] = "sleeves", -- R6
	["Right Arm"] = "sleeves", -- R6
	LeftUpperLeg = "trousers",
	RightUpperLeg = "trousers",
	LeftLowerLeg = "trousers",
	RightLowerLeg = "trousers",
	["Left Leg"] = "trousers", -- R6
	["Right Leg"] = "trousers", -- R6
	LeftFoot = "shoes",
	RightFoot = "shoes",
}

-- Small cosmetic piece welded to `anchor` at `offset` (anchor-local).
local function weldPiece(rig, anchor, name, size, offset, color, material)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Anchored = false
	piece.Massless = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = false
	piece.CFrame = anchor.CFrame * offset

	local weld = Instance.new("Weld")
	weld.Part0 = anchor
	weld.Part1 = piece
	weld.C0 = offset
	weld.Parent = piece
	piece.Parent = rig
	return piece
end

-- Removes the construction outfit: work clothing and every accessory that is
-- not hair (hard hats, vests, tool belts...).
local function removeWorkClothes(rig)
	for _, child in ipairs(rig:GetChildren()) do
		if child:IsA("Clothing") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Accessory") then
			local isHair = child.AccessoryType == Enum.AccessoryType.Hair
				or string.find(string.lower(child.Name), "hair", 1, true) ~= nil
			if not isHair then
				child:Destroy()
			end
		end
	end
end

function OfficeAttire.Dress(rig, styleName)
	local style = STYLES[styleName]
	if not style then
		warn("[OfficeAttire] Unknown style: " .. tostring(styleName))
		return
	end

	removeWorkClothes(rig)

	-- Body colors show once the clothing images are gone; BodyColors would
	-- override them, so it goes too.
	local bodyColors = rig:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end
	for partName, role in pairs(PART_ROLES) do
		local part = rig:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.Color = style[role]
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
		end
	end

	-- Shirt collar and tie on the chest (front of the torso is -Z).
	local torso = rig:FindFirstChild("UpperTorso") or rig:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local front = -torso.Size.Z / 2
		local top = torso.Size.Y / 2
		weldPiece(rig, torso, "OfficeCollar", Vector3.new(0.9, 0.35, 0.08), CFrame.new(0, top - 0.2, front - 0.03), style.collar)
		if style.tie then
			weldPiece(rig, torso, "OfficeTieKnot", Vector3.new(0.3, 0.22, 0.1), CFrame.new(0, top - 0.42, front - 0.05), style.tie)
			weldPiece(rig, torso, "OfficeTie", Vector3.new(0.26, torso.Size.Y * 0.62, 0.06), CFrame.new(0, top - 0.53 - torso.Size.Y * 0.31, front - 0.04), style.tie)
		end
	end
end

-- Supervisor extra: a clipboard held in the left hand.
function OfficeAttire.AddClipboard(rig)
	local hand = rig:FindFirstChild("LeftHand") or rig:FindFirstChild("Left Arm")
	if not (hand and hand:IsA("BasePart")) then
		return
	end
	local offset = CFrame.new(0, -hand.Size.Y / 2 - 0.1, -0.45)
	weldPiece(rig, hand, "Clipboard", Vector3.new(0.9, 1.2, 0.08), offset, Color3.fromRGB(150, 105, 60), Enum.Material.Wood)
	weldPiece(rig, hand, "ClipboardPaper", Vector3.new(0.75, 0.95, 0.02), offset * CFrame.new(0, -0.05, -0.05), WHITE_SHIRT)
end

function OfficeAttire.HasStyle(styleName)
	return STYLES[styleName] ~= nil
end

return OfficeAttire
