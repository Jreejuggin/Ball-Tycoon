-- Level data is shared for presentation; the server owns all combat decisions.
local ThrowableBallConfig = {
	ToolName = "ThrowableBall",
	StationName = "ThrowableBallStation",
	Levels = {
		[1] = {
			DisplayName = "Level 1 Throwable Ball",
			Icon = "rbxassetid://88293931604253",
			Price = 10,
			Damage = 10,
			Cooldown = 1.2,
			Speed = 95,
			Lifetime = 3,
			MaxDistance = 200,
			Radius = 0.7,
			GravityScale = 0.35,
			HorizontalKnockback = 184,
			VerticalKnockback = 52,
			AngularKnockback = 28,
			RagdollSeconds = 1.25,
		},
	},
}
return ThrowableBallConfig

