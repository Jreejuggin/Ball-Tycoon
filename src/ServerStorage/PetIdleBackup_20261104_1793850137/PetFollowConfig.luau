-- Shared presentation settings. Ownership and the equipped limit are enforced on the server.
local Config = {}

Config.MaxEquippedPets = 4
Config.MaxVisualSize = 2.4
Config.BobHeight = 0.22
Config.BobSpeed = 2.4
Config.FollowResponsiveness = 12
Config.TeleportSnapDistance = 40
Config.RenderDistance = 180

-- Fixed places around/above the head, with a gentle bob rather than an orbit.
Config.Formations = {
	{ Vector3.new(0, 3, 1.2) },
	{ Vector3.new(-2.7, 1.4, 0.8), Vector3.new(2.7, 1.4, 0.8) },
	{ Vector3.new(-3, 1.4, 0.8), Vector3.new(0, 3.3, 1.2), Vector3.new(3, 1.4, 0.8) },
	{ Vector3.new(-3, 1.3, 0.8), Vector3.new(3, 1.3, 0.8), Vector3.new(-1.6, 3.6, 1.4), Vector3.new(1.6, 3.6, 1.4) },
}

return Config
