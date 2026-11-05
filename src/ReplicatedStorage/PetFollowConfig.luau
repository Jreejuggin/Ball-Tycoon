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

Config.Idle = {
	Enabled = true,
	AnimationDistance = 85,
	BlinkInterval = Vector2.new(3.5, 7.5),
	BlinkClose = 0.08,
	BlinkHold = 0.055,
	BlinkOpen = 0.11,
	DoubleBlinkChance = 0.18,
	GestureInterval = Vector2.new(7, 14),
	GestureDuration = 1.15,
	TiltDegrees = 12,
	HopHeight = 0.45,
}

return Config
