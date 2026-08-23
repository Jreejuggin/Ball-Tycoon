-- ButtonHoverEffect
-- Adds a small "pop" animation to any GuiButton: grows slightly and lifts
-- upward on hover, and eases back down when the mouse leaves. Also plays a
-- shared hover/click sound (configured in UISoundConfig) automatically --
-- no extra wiring needed per button.
-- Usage: ButtonHoverEffect.apply(someButton) -- uses sensible defaults
--        ButtonHoverEffect.apply(someButton, { scale = 1.12, lift = 6 })

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UISoundConfig = require(ReplicatedStorage:WaitForChild("UISoundConfig"))
local SFXSettings = require(ReplicatedStorage:WaitForChild("SFXSettings"))

local ButtonHoverEffect = {}

local DEFAULT_SCALE = 1.08 -- 8% bigger on hover
local DEFAULT_LIFT = 4 -- pixels moved upward on hover
local DEFAULT_DURATION = 0.12

-- ===== Shared sound instances =====
-- One Sound per effect, reused across every button, instead of creating a
-- new Sound instance on every single hover (cheaper, avoids instance churn).
local function createSharedSound(name, soundId, volume)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	SFXSettings.ApplyToSound(sound)
	sound.Parent = SoundService
	return sound
end

local hoverSound = createSharedSound("UIHoverSound", UISoundConfig.hoverSoundId, UISoundConfig.hoverVolume)
local clickSound = createSharedSound("UIClickSound", UISoundConfig.clickSoundId, UISoundConfig.clickVolume)

local function playSound(sound)
	-- Placeholder IDs are left as an empty string in UISoundConfig -- skip
	-- silently instead of trying to play nothing.
	if sound.SoundId == "" then
		return
	end
	sound.TimePosition = 0
	sound:Play()
end

function ButtonHoverEffect.apply(button, options)
	options = options or {}
	local scaleMultiplier = options.scale or DEFAULT_SCALE
	local liftPixels = options.lift or DEFAULT_LIFT
	local duration = options.duration or DEFAULT_DURATION

	-- Capture the button's resting Size/Position once, so this works no
	-- matter what AnchorPoint or base size the button already has.
	local restSize = button.Size
	local restPosition = button.Position

	local hoverSize = UDim2.new(
		restSize.X.Scale * scaleMultiplier,
		restSize.X.Offset * scaleMultiplier,
		restSize.Y.Scale * scaleMultiplier,
		restSize.Y.Offset * scaleMultiplier
	)
	local hoverPosition = UDim2.new(
		restPosition.X.Scale,
		restPosition.X.Offset,
		restPosition.Y.Scale,
		restPosition.Y.Offset - liftPixels
	)

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, tweenInfo, {
			Size = hoverSize,
			Position = hoverPosition,
		}):Play()
		playSound(hoverSound)
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, tweenInfo, {
			Size = restSize,
			Position = restPosition,
		}):Play()
	end)

	-- Also ease back down on click-release in case the mouse is held and
	-- dragged off the button without a clean MouseLeave firing first.
	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, tweenInfo, {
			Size = hoverSize,
			Position = hoverPosition,
		}):Play()
	end)

	button.MouseButton1Click:Connect(function()
		playSound(clickSound)
	end)
end

return ButtonHoverEffect
