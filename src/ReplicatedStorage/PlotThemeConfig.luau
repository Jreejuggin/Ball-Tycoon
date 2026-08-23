--!strict
--[[
	PlotThemeConfig
	Single source of truth for plot-owned accent colors.

	A themed model needs a ThemeParts folder and the ThemedModel tag.
	PlotColor attributes override this fallback palette.
]]

local PlotThemeConfig = {}

PlotThemeConfig.PlotColors = {
	P1 = Color3.fromRGB(214, 48, 49),
	P2 = Color3.fromRGB(230, 126, 34),
	P3 = Color3.fromRGB(241, 196, 15),
	P4 = Color3.fromRGB(141, 198, 63),
	P5 = Color3.fromRGB(39, 174, 96),
	P6 = Color3.fromRGB(26, 188, 156),
	P7 = Color3.fromRGB(41, 128, 185),
	P8 = Color3.fromRGB(69, 85, 200),
	P9 = Color3.fromRGB(142, 68, 173),
	P10 = Color3.fromRGB(233, 84, 145),
}

-- Keep the selected color exact across kiosks, machines, walls, and glass.
PlotThemeConfig.EnforceMinBrightness = false
PlotThemeConfig.MinBrightness = 0.35

PlotThemeConfig.ThemeFolderName = "ThemeParts"
PlotThemeConfig.ThemePrefix = "Theme_"
PlotThemeConfig.Tag = "ThemedModel"
PlotThemeConfig.AccentPartTag = "PlotThemeAccent"

-- Client GUIs request a color through this server-owned RemoteEvent.
PlotThemeConfig.RemoteFolderName = "ThemeRemotes"
PlotThemeConfig.RequestEventName = "RequestPlotColor"
PlotThemeConfig.RequestCooldownSeconds = 0.15

-- Source colors used to identify the existing cosmetic theme during setup.
-- Runtime recoloring uses tags, so changing colors repeatedly never loses membership.
PlotThemeConfig.SourceAccentColors = {
	Color3.fromRGB(255, 10, 10),
	Color3.fromRGB(110, 0, 0), -- tinted perimeter glass
}

PlotThemeConfig.ThemeableRoots = {
	DropperSlots = true,
	DropperSlots2 = true,
	ConveyorSlots = true,
	ConveyorBeltBig = true,
	ConveyorBeltSuper = true,
	ultra_conveyor = true,
	BallPressMachines = true,
	OrbitalReactorMachines = true,
	CentreSlots = true,
	PerimeterWall = true,
	LaserDoor = true,
}

PlotThemeConfig.ExcludedAncestorNames = {
	BuyPad = true,
	UpgradeBuyPad = true,
	WorkerBuyPad = true,
}

PlotThemeConfig.ExcludedPartNames = {
	KillZone = true,
	StatusLight = true, -- Laser Door state feedback, not a cosmetic accent
}

PlotThemeConfig.StaticColors = {
	Neutral_BasePlatform = Color3.fromRGB(68, 70, 74),
	Neutral_BaseRiser = Color3.fromRGB(35, 36, 38),
	Neutral_PostLeft = Color3.fromRGB(226, 217, 196),
	Neutral_PostRight = Color3.fromRGB(226, 217, 196),
	Neutral_SignBoard = Color3.fromRGB(44, 43, 46),
	Neutral_WallPanels = Color3.fromRGB(232, 225, 208),
	Neutral_DeskTop = Color3.fromRGB(166, 98, 33),
	Neutral_MonitorScreen = Color3.fromRGB(20, 24, 32),
	Neutral_MonitorNeck = Color3.fromRGB(40, 42, 45),
	Neutral_MonitorFoot = Color3.fromRGB(40, 42, 45),
	Neutral_Keyboard = Color3.fromRGB(28, 29, 31),
	Neutral_Lamp1 = Color3.fromRGB(255, 199, 26),
	Neutral_Lamp2 = Color3.fromRGB(255, 199, 26),
	Neutral_ChairBase = Color3.fromRGB(28, 29, 31),
	Neutral_ChairPole = Color3.fromRGB(28, 29, 31),
	Neutral_ChairFrame = Color3.fromRGB(28, 29, 31),
	Deco_PlantPot = Color3.fromRGB(235, 228, 210),
	Deco_PlantLeaves = Color3.fromRGB(39, 130, 43),
	Deco_ResumePapers = Color3.fromRGB(238, 232, 216),
	Deco_Poster = Color3.fromRGB(238, 232, 216),
	Deco_CoffeeCup = Color3.fromRGB(245, 245, 245),
	Text_NOW = Color3.fromRGB(250, 250, 250),
	Text_HIRING = Color3.fromRGB(255, 199, 26),
	Text_RESUMES = Color3.fromRGB(250, 250, 250),
}

PlotThemeConfig.NeonParts = {
	Neutral_Lamp1 = true,
	Neutral_Lamp2 = true,
}

return PlotThemeConfig
