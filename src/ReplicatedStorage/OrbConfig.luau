-- Orb Centre consumables: prices and timing are shared presentation data.
local Config = {
    Duration = 20,
    PurchaseCooldown = 300,
    EatDuration = 1.15,
    MaxStack = 9999,
    ReplaceActiveEffect = true,
    Order = {"Protection", "Speed"},
    Types = {
        Protection = {
            ItemId = "Orb_Protection",
            ToolName = "Protection Orb",
            StationName = "ProtectionOrbStation",
            Price = 10,
            Color = Color3.fromRGB(80, 190, 255),
            Description = "20s Protection",
        },
        Speed = {
            ItemId = "Orb_Speed",
            ToolName = "Speed Orb",
            StationName = "SpeedOrbStation",
            Price = 10,
            Color = Color3.fromRGB(255, 205, 70),
            Description = "+20% Speed • 20s",
            Multiplier = 1.2,
        },
    },
}
return Config
