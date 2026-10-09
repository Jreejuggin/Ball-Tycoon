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
local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))

-- The MusicGUI loader supplies these client-side modules at runtime. Using its
-- shared handler ensures the MainHUD and MusicPlaylistGUI control the same song.
local clientOnlyModules = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClientOnlyModules")
local LocalMusicHandler = require(clientOnlyModules:WaitForChild("LocalMusicHandler"))
local onMusicMuteChanged = ReplicatedStorage:WaitForChild("Events")
	:WaitForChild("ClientOnlyEvents")
	:WaitForChild("OnMusicMuteChanged")

local player = game.Players.LocalPlayer
local gui = script.Parent

-- The HUD tree is constructed in code rather than hand-placed in Studio.
-- build() returns named references to every element this script drives, so
-- nothing below depends on instance names, nesting or paths -- the layout can
-- be rearranged freely inside MainHUDBuilder without touching this file.
local MainHUDBuilder = require(script.Parent:WaitForChild("MainHUDBuilder"))
local refs = MainHUDBuilder.build(gui)

local cashLabel = refs.cashLabel
local plusButton = refs.plusButton
local gemLabel = refs.gemLabel
local gemPlusButton = refs.gemPlusButton
local teleportToTycoonButton = refs.teleportButton
local teleportToTycoonEvent = ReplicatedStorage:WaitForChild("TeleportToTycoonEvent")

local settingsButton = refs.settingsButton
local settingsPanel = refs.settings.panel
local settingsCloseButton = refs.settings.closeButton
local musicToggle = refs.settings.music.track
local musicKnob = refs.settings.music.knob
local sfxToggle = refs.settings.sfx.track
local sfxKnob = refs.settings.sfx.knob

local shopButton = refs.shopButton
local shopPanel = refs.shop.panel
local shopCloseButton = refs.shop.closeButton

local petsButton = refs.petsButton
local petsPanel = refs.pets.panel
local petsCloseButton = refs.pets.closeButton

local inventoryButton = refs.inventoryButton
local inventoryPanel = refs.inventory.panel
local inventoryCloseButton = refs.inventory.closeButton

local cashPackPanel = refs.cashPack.panel
local cashPackCloseButton = refs.cashPack.closeButton

local richestLabel = refs.richestLabel

local healthFillBar = refs.healthBar.fill
local healthLabel = refs.healthBar.label

-- ===== Currency displays =====
-- Both amounts use the shared abbreviation (1,234,567 -> "1.23M"), so the bar
-- stays a fixed width as they grow.
local function formatCash(amount)
	return "$" .. CashFormat.abbreviate(amount)
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

-- The HUD shows banked gems: the safe balance, and where bought gems land.
local bankedGems = player:WaitForChild("GemData"):WaitForChild("BankedGems")

local function updateGemLabel()
	gemLabel.Text = CashFormat.abbreviate(bankedGems.Value)
end

bankedGems:GetPropertyChangedSignal("Value"):Connect(updateGemLabel)
updateGemLabel()

-- ===== Panel open/close system =====
-- Uses the shared PanelManager so newly added panels (e.g. the MiddleShops
-- shop panels) can register themselves from other scripts and participate
-- in the same single-panel-exclusive behavior without editing this script.
local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))

PanelManager.registerPanel(settingsPanel)
PanelManager.registerPanel(shopPanel)
PanelManager.registerPanel(petsPanel)
PanelManager.registerPanel(inventoryPanel)
-- Registered with its tab switcher, so it can be opened straight to a tab.
PanelManager.registerPanel(cashPackPanel, refs.cashPack.selectTab)

local function closeAllPanels()
	PanelManager.closeAll()
end

local function togglePanel(panel)
	PanelManager.toggle(panel)
end

-- ===== Cash and tycoon travel buttons =====
-- Each plus opens the purchase panel on its own tab. Pressed while the panel
-- is open on the other tab it switches tabs; on its own tab it closes it.
plusButton.MouseButton1Click:Connect(function()
	PanelManager.toggle(cashPackPanel, "cash")
end)
gemPlusButton.MouseButton1Click:Connect(function()
	PanelManager.toggle(cashPackPanel, "gems")
end)
for tabName, tabButton in pairs(refs.cashPack.tabButtons) do
	tabButton.MouseButton1Click:Connect(function()
		PanelManager.open(cashPackPanel, tabName)
	end)
end

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
inventoryButton.MouseButton1Click:Connect(function()
	togglePanel(inventoryPanel)
end)

settingsCloseButton.MouseButton1Click:Connect(closeAllPanels)
shopCloseButton.MouseButton1Click:Connect(closeAllPanels)
petsCloseButton.MouseButton1Click:Connect(closeAllPanels)
inventoryCloseButton.MouseButton1Click:Connect(closeAllPanels)
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

local function setToggleAppearance(track, knob, isOn)
	TweenService:Create(track, TOGGLE_TWEEN_INFO, {
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
	setToggleAppearance(musicToggle, musicKnob, not LocalMusicHandler.IsCurrentPlayingSongMuted())
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
	setToggleAppearance(sfxToggle, sfxKnob, not SFXSettings.IsMuted())
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
		richestLabel.Text = string.format("\226\152\133 %s rules the Tycoon Throne! (%s) \226\152\133", richestPlayer.Name, formatCash(richestCash))
	else
		richestLabel.Text = "\226\152\133 --- rules the Tycoon Throne! ($0) \226\152\133"
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
	gemPlusButton,
	teleportToTycoonButton,
	inventoryButton,
	settingsButton,
	shopButton,
	petsButton,
	settingsCloseButton,
	shopCloseButton,
	petsCloseButton,
	inventoryCloseButton,
	cashPackCloseButton,
	musicToggle,
	sfxToggle,
}

for _, button in ipairs(hoverButtons) do
	ButtonHoverEffect.apply(button)
end

-- ===== Plus button press =====
-- Each plus face sits `depth` px above a darker base (see MainHUDBuilder),
-- and that strip of base is what reads as depth. Pressing slides the face
-- down onto the base so the strip vanishes, like a key pushed in. Size goes
-- back to rest as well, so a hovered (grown) face lands exactly on the base.
--
-- Only the press is handled here. Letting go is already ButtonHoverEffect's
-- job: its MouseButton1Up eases back to the hover pose, and its MouseLeave
-- back to rest if the press is dragged off the button. Each newer tween on
-- the same properties replaces the older one, so the two never fight.
local PLUS_PRESS_TWEEN_INFO = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function wirePlusPress(button, depth)
	local restSize = button.Size
	local pressedPosition = button.Position + UDim2.fromOffset(0, depth)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, PLUS_PRESS_TWEEN_INFO, {
			Size = restSize,
			Position = pressedPosition,
		}):Play()
	end)
end

wirePlusPress(plusButton, refs.plusDepth)
wirePlusPress(gemPlusButton, refs.gemPlusDepth)

-- ===== Shop button rainbow border =====
-- One looping tween spins the stroke's gradient. Each repeat restarts from 0,
-- and 0 and 360 look identical, so the wrap is seamless. The HUD does not
-- reset on spawn, but cancel anyway if it is ever destroyed so the infinite
-- tween does not outlive it.
local shopRainbow = refs.shopRainbow
local shopRainbowTween = TweenService:Create(
	shopRainbow,
	TweenInfo.new(Theme.cashHud.shopRainbowPeriod, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
	{ Rotation = 360 }
)
shopRainbowTween:Play()
shopRainbow.Destroying:Connect(function()
	shopRainbowTween:Cancel()
end)

-- ===== Tooltips =====
-- Only the CashHUDGroup buttons get tooltips (the icon-only ones benefit
-- most, since they have no visible label of their own).
Tooltip.attach(plusButton, "Add Cash")
Tooltip.attach(gemPlusButton, "Add Gems")
Tooltip.attach(teleportToTycoonButton, "Teleport to Tycoon")
Tooltip.attach(inventoryButton, "Inventory")
Tooltip.attach(settingsButton, "Settings")
Tooltip.attach(shopButton, "Shop")
Tooltip.attach(petsButton, "Pets")

-- ===== Panel row content =====
-- Previously LocalScripts parented to their panels. The panels are now built
-- at runtime, so each is a module that takes the panel it should populate.
require(script.Parent:WaitForChild("ShopPanelController"))(refs.shop.itemList)
require(script.Parent:WaitForChild("CashPackPanelController"))(refs.cashPack.lists)


