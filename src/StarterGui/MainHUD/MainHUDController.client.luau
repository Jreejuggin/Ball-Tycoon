-- MainHUDController
-- Drives the Cash Display, and the Settings / Shop / Pets panels.
-- Cash is read from player.leaderstats.Cash (an IntValue, already wired
-- server-side by DataSaveScript) -- no RemoteEvent needed for this feature.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonHoverEffect = require(ReplicatedStorage:WaitForChild("ButtonHoverEffect"))
local Tooltip = require(ReplicatedStorage:WaitForChild("Tooltip"))
local SFXSettings = require(ReplicatedStorage:WaitForChild("SFXSettings"))
local Theme = require(ReplicatedStorage:WaitForChild("UITheme"))

-- The MusicGUI loader supplies these client-side modules at runtime. Using its
-- shared handler ensures the MainHUD and MusicPlaylistGUI control the same song.
local clientOnlyModules = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClientOnlyModules")
local LocalMusicHandler = require(clientOnlyModules:WaitForChild("LocalMusicHandler"))
local onMusicMuteChanged = ReplicatedStorage:WaitForChild("Events")
	:WaitForChild("ClientOnlyEvents")
	:WaitForChild("OnMusicMuteChanged")

local player = game.Players.LocalPlayer
local gui = script.Parent

-- The HUD tree is constructed in code rather than hand-placed in Studio, so it
-- must be built before the lookups below -- several of them dot-index the panel
-- instances and would error if they did not exist yet.
local MainHUDBuilder = require(script.Parent:WaitForChild("MainHUDBuilder"))
MainHUDBuilder.build(gui)

-- Cash, travel, and quick-action buttons live in one container so their
-- spacing remains fixed relative to the cash panel at every screen size.
local cashHUDGroup = gui:WaitForChild("CashHUDGroup")
local cashPanel = cashHUDGroup:WaitForChild("CashPanel")
local cashLabel = cashPanel.CashLabel
local plusButton = cashPanel.PlusButton
local teleportToTycoonButton = cashHUDGroup:WaitForChild("TeleportToTycoonButton")
local teleportToTycoonEvent = ReplicatedStorage:WaitForChild("TeleportToTycoonEvent")

local settingsButton = cashHUDGroup:WaitForChild("SettingsButton")
local settingsPanel = gui.SettingsPanel
local settingsCloseButton = settingsPanel.TitleBar.CloseButton
local musicToggle = settingsPanel.MusicRow.ToggleButton
local sfxToggle = settingsPanel.SFXRow.ToggleButton

local shopButton = cashHUDGroup:WaitForChild("ShopButton")
local shopPanel = gui.ShopPanel
local shopCloseButton = shopPanel.TitleBar.CloseButton

local petsButton = cashHUDGroup:WaitForChild("PetsButton")
local petsPanel = gui.PetsPanel
local petsCloseButton = petsPanel.TitleBar.CloseButton

local cashPackPanel = gui.CashPackPanel
local cashPackCloseButton = cashPackPanel.TitleBar.CloseButton

local richestLabel = gui.RichestBanner.RichestLabel

local healthBar = gui.HealthBar
local healthFillBar = healthBar.FillBar
local healthLabel = healthBar.HealthLabel

-- ===== Cash formatting =====
-- Abbreviates large numbers (1,234,567 -> "1.23M") so the panel stays a
-- fixed width even as Cash grows. Falls back to plain commas under 1,000.
local SUFFIXES = { "K", "M", "B" }

local function formatCash(amount)
	if amount < 1000 then
		return "$" .. amount
	end

	local value = amount
	local suffixIndex = 0
	while value >= 1000 and suffixIndex < #SUFFIXES do
		value = value / 1000
		suffixIndex += 1
	end

	return string.format("$%.2f%s", value, SUFFIXES[suffixIndex])
end

local function updateCashLabel(cashValue)
	cashLabel.Text = formatCash(cashValue)
end

local leaderstats = player:WaitForChild("leaderstats")
local cash = leaderstats:WaitForChild("Cash")

cash:GetPropertyChangedSignal("Value"):Connect(function()
	updateCashLabel(cash.Value)
end)
updateCashLabel(cash.Value)

-- ===== Panel open/close system =====
-- Uses the shared PanelManager so newly added panels (e.g. the MiddleShops
-- shop panels) can register themselves from other scripts and participate
-- in the same single-panel-exclusive behavior without editing this script.
local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))

PanelManager.registerPanel(settingsPanel)
PanelManager.registerPanel(shopPanel)
PanelManager.registerPanel(petsPanel)
PanelManager.registerPanel(cashPackPanel)

local function closeAllPanels()
	PanelManager.closeAll()
end

local function togglePanel(panel)
	PanelManager.toggle(panel)
end

-- ===== Cash and tycoon travel buttons =====
plusButton.MouseButton1Click:Connect(function()
	togglePanel(cashPackPanel)
end)

teleportToTycoonButton.Activated:Connect(function()
	teleportToTycoonEvent:FireServer()
end)

settingsButton.MouseButton1Click:Connect(function()
	togglePanel(settingsPanel)
end)
shopButton.MouseButton1Click:Connect(function()
	togglePanel(shopPanel)

end)
petsButton.MouseButton1Click:Connect(function()
	togglePanel(petsPanel)
end)

settingsCloseButton.MouseButton1Click:Connect(closeAllPanels)
shopCloseButton.MouseButton1Click:Connect(closeAllPanels)
petsCloseButton.MouseButton1Click:Connect(closeAllPanels)
cashPackCloseButton.MouseButton1Click:Connect(closeAllPanels)

-- ===== Settings toggles =====
-- Each ToggleButton is a pill-shaped track with a circular Knob child (see
-- MainHUDBuilder) that slides between the two ends, iOS-switch style.
local TOGGLE_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- trackOnColorLegacy, not trackOnColor: this script's "on" green has always
-- been one step redder than the one MainHUDBuilder paints the track with, so
-- the switch shifted by 1/255 the first time it was toggled. Kept distinct to
-- preserve the current look exactly; see the note in UITheme.
local TOGGLE_ON_COLOR = Theme.toggle.trackOnColorLegacy
local TOGGLE_OFF_COLOR = Theme.toggle.trackOffColor
local TOGGLE_KNOB_ON_POSITION = Theme.toggle.knobOnPosition
local TOGGLE_KNOB_OFF_POSITION = Theme.toggle.knobOffPosition

local function setToggleAppearance(button, isOn)
	local knob = button:WaitForChild("Knob")
	TweenService:Create(button, TOGGLE_TWEEN_INFO, {
		BackgroundColor3 = isOn and TOGGLE_ON_COLOR or TOGGLE_OFF_COLOR,
	}):Play()
	TweenService:Create(knob, TOGGLE_TWEEN_INFO, {
		Position = isOn and TOGGLE_KNOB_ON_POSITION or TOGGLE_KNOB_OFF_POSITION,
	}):Play()
end

-- MusicGUI owns the actual mute state and the Sound instance. This HUD only
-- changes that shared state, then emits its existing BindableEvent so the
-- audio engine immediately applies the new volume.
local function updateMusicToggle()
	setToggleAppearance(musicToggle, not LocalMusicHandler.IsCurrentPlayingSongMuted())
end

musicToggle.Activated:Connect(function()
	LocalMusicHandler.SetCurrentPlayingSongMute(not LocalMusicHandler.IsCurrentPlayingSongMuted())
	onMusicMuteChanged:Fire()
	updateMusicToggle()
end)

-- The MusicPlaylistGUI also changes this state, so reflect those changes here.
onMusicMuteChanged.Event:Connect(updateMusicToggle)
updateMusicToggle()

-- Every non-music effect is routed through SoundService.SFX. Its volume is
-- changed locally, so this setting affects only the current player.
local function updateSFXToggle()
	setToggleAppearance(sfxToggle, not SFXSettings.IsMuted())
end

sfxToggle.Activated:Connect(function()
	SFXSettings.SetMuted(not SFXSettings.IsMuted())
	updateSFXToggle()
end)

updateSFXToggle()

-- ===== Richest Player Banner =====
-- leaderstats are replicated to every client by default (it's the same data
-- that powers the built-in Players/Cash leaderboard), so this reads every
-- player's Cash directly -- no RemoteEvent needed.
local Players = game:GetService("Players")

local function getRichestPlayer()
	local richestPlayer, richestCash = nil, -1
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		local otherStats = otherPlayer:FindFirstChild("leaderstats")
		local otherCash = otherStats and otherStats:FindFirstChild("Cash")
		if otherCash and otherCash.Value > richestCash then
			richestPlayer = otherPlayer
			richestCash = otherCash.Value
		end
	end
	return richestPlayer, richestCash
end

local function updateRichestBanner()
	local richestPlayer, richestCash = getRichestPlayer()
	if richestPlayer then
		richestLabel.Text = string.format("\226\152\133 Richest: %s (%s)", richestPlayer.Name, formatCash(richestCash))
	else
		richestLabel.Text = "\226\152\133 Richest: --- ($0)"
	end
end

-- Hook a player's Cash so any change re-checks who's in the lead.
local function hookPlayerForRichest(newPlayer)
	local newStats = newPlayer:WaitForChild("leaderstats", 10)
	if not newStats then
		return
	end
	local newCash = newStats:WaitForChild("Cash", 10)
	if not newCash then
		return
	end
	newCash:GetPropertyChangedSignal("Value"):Connect(updateRichestBanner)
	updateRichestBanner()
end

for _, existingPlayer in ipairs(Players:GetPlayers()) do
	task.spawn(hookPlayerForRichest, existingPlayer)
end
Players.PlayerAdded:Connect(hookPlayerForRichest)
Players.PlayerRemoving:Connect(function()
	-- PlayerRemoving fires just before the player actually leaves the
	-- Players list, so defer one tick to recompute against the final roster.
	task.defer(updateRichestBanner)
end)

updateRichestBanner()

-- ===== Health Bar =====
-- Re-hooks to the Humanoid on every spawn (character, and therefore the
-- Humanoid, is destroyed and recreated on each respawn).
local HEALTH_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")

	local function updateHealthBar()
		local health = math.max(humanoid.Health, 0)
		local maxHealth = humanoid.MaxHealth
		local fraction = maxHealth > 0 and (health / maxHealth) or 0

		TweenService:Create(healthFillBar, HEALTH_TWEEN_INFO, {
			Size = UDim2.new(fraction, 0, 1, 0),
		}):Play()

		healthLabel.Text = string.format("%d/%d", math.floor(health + 0.5), math.floor(maxHealth + 0.5))
	end

	humanoid.HealthChanged:Connect(updateHealthBar)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealthBar)
	updateHealthBar()
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- ===== Hover animations =====
-- Every clickable button in the HUD gets the same subtle "pop" on hover.
local hoverButtons = {
	plusButton,
	teleportToTycoonButton,
	settingsButton,
	shopButton,
	petsButton,
	settingsCloseButton,
	shopCloseButton,
	petsCloseButton,
	cashPackCloseButton,
	musicToggle,
	sfxToggle,
}

for _, button in ipairs(hoverButtons) do
	ButtonHoverEffect.apply(button)
end

-- ===== Tooltips =====
-- Only the CashHUDGroup buttons get tooltips (the icon-only ones benefit
-- most, since they have no visible label of their own).
Tooltip.attach(plusButton, "Add Cash")
Tooltip.attach(teleportToTycoonButton, "Teleport to Tycoon")
Tooltip.attach(settingsButton, "Settings")
Tooltip.attach(shopButton, "Shop")
Tooltip.attach(petsButton, "Pets")

-- ===== Panel row content =====
-- Previously LocalScripts parented to their panels. The panels are now built
-- at runtime, so each is a module that takes the panel it should populate.
require(script.Parent:WaitForChild("ShopPanelController"))(shopPanel)
require(script.Parent:WaitForChild("CashPackPanelController"))(cashPackPanel)


