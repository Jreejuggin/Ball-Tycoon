--[[
# PROJECT_STATE.md

## Game Overview

**Genre:** Tycoon (conveyor-based production tycoon)
**Players:** 10 plots (P1–P10), multiplayer capable
**Build Status:** Early-to-mid development. Core tycoon loop is functional. UI systems mostly built, including a working NPC shop system and hover tooltips. Robux monetization placeholders exist but are not wired to real products.

---

## 1. Complete Architecture

### 1.1 DataModel Hierarchy

```
game/
├── Workspace/
│   ├── Baseplate, SpawnLocation, Terrain, Camera, SurfaceGui
│   ├── Hub (Part)
│   ├── MiddleShops/ (Folder)
│   │   └── 5 shop structures + NPCs, each with a Body/InteractPrompt (ProximityPrompt):
│   │       BallShopStructure, CreatureShopStructure, TradingPostStructure,
│   │       VaultStructure, UpgradeShopStructure
│   ├── P1–P10 (10 Plot Models, identical structure)
│   │   ├── Floor, PerimeterWall (Model)
│   │   ├── HiringKiosk (tagged ThemedModel; 13 themed parts + 4 collision boxes)
│   │   ├── LaserDoor (Model) + LaserDoorToggleScript
│   │   ├── CeilingLights (Model) + CeilingLightsController
│   │   ├── CentreSlots/ — five sequential centres; Centre01_Worker contains worker upgrades; Centre02_Home contains StructureSlots
│   │   ├── ConveyorBeltBig/ (Folder) — Conveyor4-6
│   │   ├── ConveyorBeltSuper/ (Folder) — Conveyor7
│   │   ├── ConveyorSlots/ (Folder) — Conveyor1-3
│   │   ├── DropperSlots/ (Folder) — Slot1-5 (BuyPadScript, BallDropperScript)
│   │   └── DropperSlots2/ (Folder) — Slot1-5 + DropperSlots2UnlockController
│   ├── Tycoon Dropper, TycoonDropper (models with scripts)
│   ├── Tycoon Wall, Tycoon Walls Grass (models)
│   ├── Sketchfab_Scene (imported model)
│   ├── Irwin Vernon (character model)
│   └── MusicGUI/ (Folder — third-party music asset)
│       ├── MusicGUI_Loader (Script — auto-moves content to proper services)
│       │   ├── StarterGUI/MusicPlaylistGUI (ScreenGui + scripts)
│       │   ├── StarterPlayer/StarterPlayerScripts/MusicChangeHandler
│       │   └── ReplicatedStorage/Modules/ClientOnlyModules/ + Events/
│       └── README (LocalScript — documentation + examples)
│
├── ReplicatedStorage/
│   ├── UI shared modules: ButtonHoverEffect, UISoundConfig, PanelManager,
│   │            ShopRowBuilder, CashFormat, Tooltip
│   ├── Shop item configs (Robux): ShopConfig, CashPackConfig
│   ├── Shop item configs (in-game Cash, MiddleShops): CreatureShopConfig,
│   │            BallShopConfig, TradingPostConfig, VaultConfig, UpgradeShopConfig
│   ├── Other modules: PurchaseEffectModule, PurchaseSoundModule,
│   │            MachineUpgradeConfig, PlotThemeConfig, PlotTheme,
│   │            WorkerSpeedConfig, PROJECT_STATE (this file)
│   ├── First-time tutorial (see section 2.12): TutorialConfig (step list),
│   │            ArrowIndicator + ArrowTrail (3D world markers)
│   ├── Dead/unused: WorldShopConfig (empty stub), PurchaseEffectModule_FreshTest6
│   ├── Design/ (StyleSheet, BaseStyleSheet — UI styling system, not yet applied to MainHUD)
│   ├── Models: ConveyorCrate, LaserDoorTemplate
│   ├── RemoteEvents: MachineUpgradeSparkleEvent, PurchaseSoundEvent,
│   │                 MiddleShopPurchaseEvent, OpenWorldShopEvent (dead, unused),
│   │                 ThemeRemotes/RequestPlotColor,
│   │                 TutorialStepEvent, TutorialCompleteEvent (section 2.12)
│   │   (TeleportToTycoonEvent also lives here at runtime, but is created
│   │   dynamically by PlotAssignmentScript on server start -- not a static
│   │   template object. See section 2.8.)
│   └── StringValue: CashRainImageId
│
├── ServerStorage/
│   ├── CreatureShopPlaceholderItem (Tool) — placeholder item granted by
│   │   every Creature Shop purchase; wraps a cloned CreatureBall_Slimey
│   │   MeshPart as its Handle. Same visual for all 4 creature tiers for now.
│   ├── SavedLightDesigns/CeilingLights_Orbs (Model + controller)
│   └── WorkerTemplates/ (Worker1, ConveyorWorker, BigConveyorWorker — all with WorkerScript)
│
├── ServerScriptService/
│   ├── PlotAssignmentScript (also creates TeleportToTycoonEvent at runtime if missing)
│   ├── DataSaveScript
│   ├── WorkerVoiceLineController
│   ├── MachineUpgradeFeedbackService
│   ├── MachineSectionCompletionSoundService
│   ├── MiddleShopPurchaseHandler — server-authoritative Cash purchases for
│   │   the 5 MiddleShops NPCs (see section 2.4b)
│   ├── DropperBuyPadNameGuard
│   ├── CentreZoneService
│   ├── PlotThemeService
│   ├── WorkerSpeedService
│   ├── TutorialProgressHandler — network wiring for the two tutorial
│   │   RemoteEvents (see section 2.12)
│   └── StructurePurchaseService (ModuleScript)
│   └── TycoonProgressService (ModuleScript)
│   └── TutorialProgressService (ModuleScript)
│
├── StarterGui/
│   ├── StatsHUD (ScreenGui) + StatsHUDUpdater (LocalScript)
│   ├── MainHUD (ScreenGui)
│   │   ├── MainHUDController (LocalScript) — main orchestrator
│   │   ├── MiddleShopsController (LocalScript) — builds/wires the 5 MiddleShops panels
│   │   ├── Tooltip (TextLabel) — single shared hover-tooltip element, see section 2.8
│   │   ├── CashHUDGroup (Frame) — groups CashPanel (+ PlusButton),
│   │   │   TeleportToTycoonButton (square icon button, house icon), SettingsButton
│   │   │   (square icon button, gear icon), ShopButton, PetsButton. All 5 have
│   │   │   hover tooltips (see section 2.8).
│   │   ├── SettingsPanel — Music toggle (real, wired to MusicGUI's
│   │   │   LocalMusicHandler), SFX toggle (real, wired to SFXSettings)
│   │   ├── ShopPanel + ShopPanelController — Robux shop (ShopConfig items),
│   │   │   rows built via shared ShopRowBuilder
│   │   ├── CashPackPanel + CashPackPanelController — Cash purchase packs
│   │   │   (CashPackConfig, Robux), custom row styling (not ShopRowBuilder)
│   │   ├── PetsPanel — placeholder (still "Soon" pills, not functional)
│   │   ├── CreatureShopPanel, BallShopPanel, TradingPostPanel, VaultPanel,
│   │   │   UpgradeShopPanel — the 5 MiddleShops panels, same visual chrome
│   │   │   as ShopPanel, rows built via shared ShopRowBuilder
│   │   ├── RichestBanner, HealthBar
│   ├── TutorialGui (ScreenGui, ResetOnSpawn=false) — the first-time
│   │   tutorial's client UI; separate from MainHUD so it survives respawn
│   │   and so none of it lives in an .rbxm (see section 2.12)
│   │   ├── TutorialGuiLoader (LocalScript) — waits for DataLoaded, hands off
│   │   ├── TutorialController (ModuleScript) — the state machine
│   │   ├── WelcomePanel (ModuleScript) — modal opt-in/skip card
│   │   └── StepPanel (ModuleScript) — non-modal bottom step banner
│   └── ScreenGui (empty)
│
├── StarterPlayer/
│   ├── StarterCharacterScripts/
│   │   └── SprintSystem (LocalScript)
│   └── StarterPlayerScripts/
│       ├── StructureGhostPreviewScript (LocalScript)
│       ├── PurchaseSoundClient (LocalScript)
│       ├── MachineIncomeCashRainClient (LocalScript)
│       └── MachineUpgradeSparkleClient (LocalScript)
│
└── StarterPack/ (empty)
```

---

## 2. System Details

### 2.1 Plot & Economy System (Server)

**PlotAssignmentScript** (ServerScriptService)
- Assigns plots P1–P10 to joining players (first unowned plot)
- Sets Owner (UserId) and OwnerName attributes on the plot model
- Teleports player character to plot door on assignment
- Clears ownership on player leave
- Waits for DataLoaded attribute before applying saved upgrade level
- Also creates ReplicatedStorage.TeleportToTycoonEvent at runtime if it
  doesn't already exist (FindFirstChild-then-Instance.new fallback). Works,
  but is a fragile pattern -- consider converting to a static RemoteEvent
  in the template instead of relying on script-order bootstrapping.

**DataSaveScript** (ServerScriptService)
- DataStore key: PlayerCashData_v2
- Saves cash, centre level, plot progression, worker hires, machine upgrades, structures, purchased items, and the player's selected plot color
- Loads on join, saves on leave and on server close (BindToClose)
- Sets player:SetAttribute("DataLoaded", true) to signal completion
- Does NOT yet save MiddleShops Backpack items (the CreatureShopPlaceholderItem
  Tool) or the PurchasedItems IntValue counters -- these currently reset on
  respawn/rejoin. Needs to be added once real inventory persistence matters.

**Economy Flow:**
- Server-authoritative. leaderstats.Cash (IntValue) is the single source of truth
- BallDropperScript spawns cash balls every 1.5s with Value and SourcePlot attributes
- Balls collected by player touch or worker touch
- ConveyorScript drops crates every 4s → crates break on floor → release 5 cash balls
- BuyPadScript and StructurePurchaseService validate ownership, deduct cash, and activate slots on the server
- MachineUpgradeConfig: 5 levels — ball values 5/10/20/40/80, upgrade costs 0/2500/10000/35000/100000
- Passive income from droppers/workers is fast enough (tens of thousands per
  second on active accounts) that any test which briefly sets Cash to a low
  value and waits >0.1s before checking can get an inflated result. Test
  funds-related logic with a zero-yield check immediately after setting the
  value, or via eval_server_runtime, not through a client round-trip.

### 2.2 Slot & Unlock System

**Sequential Unlocking:**
- Each slot has a Dependency attribute pointing to the slot that must be purchased first
- Visual states: GHOST (semi-transparent, purchasable), HIDDEN (locked), PURCHASED
- Activated BoolValue on each slot marks purchase completion

**Section Completion:**
- MachineSectionCompletionSoundService checks if all slots in a section are Activated
- Sections: DropperSlots, ConveyorSlots, ConveyorBeltBig, etc.
- On completion: plays area-unlock sound to plot owner, sets MachineSectionComplete attribute

**DropperSlots2 Unlock:**
- Secondary dropper row hidden until primary DropperSlots fully purchased
- DropperSlots2UnlockController manages hiding/enabling

### 2.3 Worker System

**Worker Templates** (ServerStorage.WorkerTemplates/)
- 3 types: Worker1, ConveyorWorker, BigConveyorWorker
- All use identical WorkerScript
- Each is a full character rig with Humanoid, HardHat, clothing

**WorkerScript (per worker):**
- Waits for Activated BoolValue (set by WorkerSpawnerController on purchase)
- On activation: becomes transparent, un-anchors, starts collecting cash balls
- Uses Humanoid:MoveTo() to navigate to nearest CashBall with matching SourcePlot
- Stuck detection: resets to original position after 10s of no movement
- Ball despawn: 30s timeout or roll-off-floor detection

**WorkerSpawnerController** (per plot):
- 6 stages covering both dropper rows and the normal, mega, super, and ultra conveyor sections
- Touch-based purchase pad, deducts cash, clones worker template, sets activation
- 3-second cooldown between purchases

**WorkerVoiceLineController** (ServerScriptService):
- Server-wide loop, plays random voice lines every 35–60 seconds
- 120-second cooldown per worker (weak-key metatable)
- Creates Sound instances on worker heads with inverse-tapered roll-off

**WorkerSpeedService / WorkerSpeedConfig** (ServerScriptService / ReplicatedStorage):
- Wires 10 worker speed upgrades (one per plot)

### 2.4 Purchase Effects & Sounds

**PurchaseSoundModule** (ReplicatedStorage)
- Server-to-client sound router using PurchaseSoundEvent RemoteEvent
- Functions: PlayPurchaseForTarget, PlayWorkerSpawn, PlayBallPickup, PlayAreaUnlocked, PlayMachineUpgrade
- All fire (soundId, position) to specific player's client

**PurchaseEffectModule** (ReplicatedStorage)
- Gold sparkle particle burst: Play(position) and PlayAcrossParts(parts)
- Texture: rbxassetid://81738678082113

**Client-side receivers** (StarterPlayerScripts/):
- PurchaseSoundClient: plays 3D positional audio from server-fired events
- MachineUpgradeSparkleClient: renders sparkle particles on upgrade
- MachineIncomeCashRainClient: cash rain visual effect

**MachineUpgradeFeedbackService** (ServerScriptService):
- Watches for "UpgradeFeedbackRequest" attribute changes on machine slots
- Fires MachineUpgradeSparkleEvent to buyer's client
- Plays purchase/upgrade sounds via PurchaseSoundModule

### 2.4b MiddleShops NPC Shop System (Server-Authoritative Cash Purchases)

Five NPC shops in Workspace.MiddleShops (Creature, Ball, Trading Post, Vault,
Upgrade), each with a ProximityPrompt that opens a matching UI panel. Fully
functional end-to-end (built + verified in a live playtest, including
insufficient-funds and invalid-item/invalid-shop rejection paths).

**Client (StarterGui.MainHUD.MiddleShopsController):**
- Loops over a SHOP_DEFINITIONS table (panel name, config module name,
  ProximityPrompt path, action/object text) -- adding a 6th shop is one
  table entry plus a matching panel and config module, no other code changes
- For each shop: builds its item rows via the shared ShopRowBuilder, sets the
  ProximityPrompt's ActionText/ObjectText, registers the panel with
  PanelManager, and wires Triggered -> PanelManager.open(panel)
- Buy buttons fire ReplicatedStorage.MiddleShopPurchaseEvent:FireServer(configName, itemId)
  -- only the shop name and item id are sent, never a price
- Listens for the server's (success, message) response and print/warns it

**Server (ServerScriptService.MiddleShopPurchaseHandler):**
- Whitelists which config module names it will require() (prevents a client
  from asking it to require() something else)
- Re-looks-up the item's real cost from its own copy of the config -- never
  trusts anything the client says about price
- Validates player has a leaderstats.Cash and enough of it, deducts, then grants
- Item granting:
  - Creature Shop: clones ServerStorage.CreatureShopPlaceholderItem (a Tool)
    into the player's Backpack, renamed to the specific creature purchased
    (e.g. "Rare Creature"). All 4 creature tiers currently share the same
    placeholder visual (the CreatureBall_Slimey mesh) -- swap the clone
    source for real per-tier models whenever those exist.
  - Every shop (including Creature): also increments a lightweight IntValue
    counter under player.PurchasedItems, keyed by item id
  - Neither the Backpack Tool nor the PurchasedItems counters are saved to
    DataStore yet -- both reset on respawn/rejoin (see DataSaveScript note above)

**Shared modules powering both this and the main Shop panel:**
- **PanelManager** (ReplicatedStorage) — single-panel-exclusive open/close.
  Any panel can call PanelManager.registerPanel(panel); opening one closes
  all others. MainHUDController and MiddleShopsController both register
  their panels into the same manager.
- **ShopRowBuilder** (ReplicatedStorage) — builds one row (icon/name/price/Buy
  button + hover animation) per config entry. Purchase flow is pluggable via
  an optional 4th `onBuy(item)` argument to buildRows -- omit it for the
  default Robux MarketplaceService flow (used by ShopPanel), or pass a
  custom function for something else (used by MiddleShopsController for the
  Cash-based flow). This is the mechanism that keeps Robux and Cash shops
  sharing the same UI code without duplicating it.
- **CashFormat** (ReplicatedStorage) — comma-formats Cash amounts for display,
  e.g. 50000 -> "$50,000". Used by all 5 MiddleShops config modules.

**Item prices are all placeholders and will change once the economy is
tuned** -- CreatureShopConfig/BallShopConfig/TradingPostConfig/VaultConfig/
UpgradeShopConfig all have a `cost` (in-game Cash) field per item with
reasonable-but-arbitrary placeholder values; update those numbers directly
in each config, no other code changes needed.

### 2.5 Laser Door System

**LaserDoorToggleScript** (per plot):
- ProximityPrompt on control panel to toggle
- Animates laser beams top-to-bottom with fade
- KillZone: sets Humanoid.Health = 0 for non-owners on touch
- Owner always passes through

### 2.6 Ceiling Lights

**CeilingLightsController** (per plot + ServerStorage saved design):
- Syncs PointLight.Enabled with CeilingLights slot purchase state
- SavedLightDesigns/CeilingLights_Orbs: 14 fixtures, each with 2 parts

### 2.7 Plot Theme System

**PlotThemeConfig + PlotTheme + PlotThemeService:**
- Each plot has 270 tagged cosmetic accent parts across droppers, conveyors, machines, centre borders, structures, perimeter neon/glass, and Laser Door visuals
- Each HiringKiosk contributes 13 additional themed parts, for 283 themed parts per plot and 2,830 across P1-P10
- Repeated PlotColor changes recolor registered accents exactly; buy-pad colors, Laser Door KillZone, and StatusLight remain controlled by gameplay
- ThemeRemotes/RequestPlotColor accepts only a color; the server resolves the player's owned plot, rate-limits requests, and prevents cross-plot recoloring
- SavedPlotColor follows the player to any randomly assigned plot and is persisted by DataSaveScript

### 2.8 UI System

**MainHUD** (StarterGui.MainHUD):
- MainHUDController (LocalScript) — main orchestrator: cash display, panel
  open/close (via PanelManager), Settings toggles, Richest Player Banner,
  Health Bar, hover animations + tooltips for every CashHUDGroup button
- MiddleShopsController (LocalScript) — see section 2.4b
- CashHUDGroup (Frame): groups CashPanel (with "+" button opening
  CashPackPanel), TeleportToTycoonButton (fires TeleportToTycoonEvent),
  and the Settings/Shop/Pets buttons, so their spacing stays fixed together
- SettingsPanel: Music toggle -- REAL, wired to MusicGUI's LocalMusicHandler
  (shared mute state with MusicPlaylistGUI via the OnMusicMuteChanged
  BindableEvent). SFX toggle -- REAL, wired to SFXSettings.
- ShopPanel + ShopPanelController: Robux shop (ShopConfig items), rows via
  shared ShopRowBuilder
- CashPackPanel + CashPackPanelController: Cash purchase packs
  (CashPackConfig, Robux), custom row styling with a "50% OFF!" badge
- PetsPanel: placeholder with "Soon" pills — still not functional
- CreatureShopPanel / BallShopPanel / TradingPostPanel / VaultPanel /
  UpgradeShopPanel: the 5 MiddleShops panels — see section 2.4b
- RichestBanner, HealthBar

**StatsHUD** (StarterGui.StatsHUD):
- StatsHUDUpdater (LocalScript)
- Displays Cash and Level labels

**Design System** (ReplicatedStorage.Design/):
- StyleSheet and BaseStyleSheet for consistent UI theming
- Covers: Frame, ScrollingFrame, TextLabel, TextButton, TextBox, ImageButton, ImageLabel, CanvasGroup, ViewportFrame, VideoFrame, UI layouts
- Not yet applied to MainHUD -- MainHUD currently styles everything with
  hardcoded per-instance properties instead of this StyleSheet system

**UI Effects & Shared Modules:**
- **ButtonHoverEffect** (ReplicatedStorage): scale + lift tween on hover,
  shared hover/click sounds (Sound instances created once in SoundService,
  reused). hoverSoundId/clickSoundId in UISoundConfig are currently EMPTY
  placeholders -- verified that Roblox's built-in rbxasset:// sound paths
  don't resolve in this project, so a real uploaded/Marketplace sound ID is
  needed before any sound actually plays. Hover animation itself works
  regardless.
- **Tooltip** (ReplicatedStorage): `Tooltip.attach(button, text, options?)`.
  Uses ONE reusable label (StarterGui.MainHUD.Tooltip, AutomaticSize.X,
  ZIndex 100) instead of creating an instance per button. Shows on
  MouseEnter, follows the cursor via MouseMoved (screen-space coords,
  default offset +16/-10 so it doesn't sit under the cursor), hides on
  MouseLeave. Attached to all 5 CashHUDGroup buttons in MainHUDController:
  PlusButton -> "Add Cash", TeleportToTycoonButton -> "Teleport to Tycoon",
  SettingsButton -> "Settings", ShopButton -> "Shop", PetsButton -> "Pets".
  Verified structurally (loads with no errors, correct initial state) but
  NOT visually confirmed live -- available tooling can only simulate clicks,
  not real mouse movement, so the actual on-screen feel (timing/offset) is
  unverified. Worth a manual look in Studio.
- PanelManager, ShopRowBuilder: see section 2.4b

**Icon Assets (CashHUDGroup buttons):**
- SettingsButton and TeleportToTycoonButton use real image icons (gear and
  house respectively) instead of text/emoji, via an ImageLabel child
  (BackgroundTransparency 1, ScaleType.Fit) on each button:
  - SettingsButton.ImageLabel.Image = rbxassetid://86564279252401 (gear)
  - TeleportToTycoonButton.ImageLabel.Image = rbxassetid://79152891526373 (house)
- TeleportToTycoonButton was converted from a wide rectangle (156x48, two-line
  text "Teleport To / Tycoon") to a square icon button (44x44, matching
  SettingsButton's height), text cleared -- the icon now represents it.
- **Background-removal note for future icon work:** the user's source PNGs
  (both originally uploaded) were plain RGB with NO real alpha channel --
  what looked like a transparent checkerboard in preview was actually baked
  directly into the pixels. A plain color threshold doesn't work when the
  icon's own fill color is nearly identical to the checkerboard (true here
  for the gear's white body). The working fix: classify each enclosed
  same-color connected region by its LOCAL TEXTURE VARIANCE (median, not
  mean, since boundary pixels skew the mean) using a window sized larger
  than the checkerboard's cell period -- checkerboard-textured regions
  (background, and any enclosed "holes" like the gear's centre) get alpha=0;
  smooth low-variance regions (the icon's real fill) stay opaque. This
  correctly handled both the outer background AND an enclosed hole that a
  simple border-connectivity approach missed. Processed with Python
  (PIL + numpy + scipy.ndimage), not a Roblox-side fix.
- **Asset upload note:** direct upload via the `upload_asset` MCP tool timed
  out completely (4 min, no response) -- looks like missing Roblox Open
  Cloud credentials in this environment (same root cause as
  get_asset_thumbnail / search_assets failing with a missing
  ROBLOX_OPEN_CLOUD_API_KEY error). Working workflow instead: process the
  image locally, hand the user the fixed file, they import it via Studio's
  Asset Manager themselves and copy the resulting asset ID back. Don't
  re-attempt `upload_asset` first -- go straight to this manual handoff.

### 2.9 Client Gameplay Scripts

**SprintSystem** (StarterCharacterScripts/):
- Sprint mechanic (LocalScript in StarterCharacterScripts)

**StructureGhostPreviewScript** (StarterPlayerScripts/):
- Ghost preview when placing/buying structures

### 2.10 Music System (Third-Party)

**Asset:** MusicGUI v1.2.4 by L_Moments
**Location:** Workspace.MusicGUI/ (source) → auto-deployed to proper services by MusicGUI_Loader
**Architecture:** Entirely client-side (all modules in ClientOnlyModules, all scripts are LocalScripts)

**Modules** (ReplicatedStorage.Modules.ClientOnlyModules/):
- LocalMusicHandler — central state manager (playlist, song index, mute, loop, shuffle). MainHUD's Settings music toggle calls this directly.
- Playlists — defines DefaultMusicPlaylist (auto-populated with all 20 songs) + MyMusicPlaylist (3 custom songs)
- Songs — 20 songs with audio IDs and per-song volumes
- PlaylistSettings — config: default playlist, shuffle, fade time (1.5s), global volume (1.0), log level
- PlaylistInfo — type: {playlistName, musicTable}
- MusicInfo — type: {musicID, musicName, musicVolume}
- SoundInfo — type: {soundID, soundName} (not used by music system; generic utility)
- DebugHelper — logging with 5 levels (Error=0 → Debug=4), current level = 2 (Important)

**Scripts:**
- MusicChangeHandler (StarterPlayerScripts/) — audio engine, Sound instance, fade-out, auto-advance, looping
- MusicPlaylistGUIScript (StarterGui.MusicPlaylistGUI/) — GUI display, next/prev buttons, updates on OnMusicChanged
- SettingsGUIScript (StarterGui.MusicPlaylistGUI/) — mute/loop toggles, animated settings popup

**Events** (ReplicatedStorage.Events.ClientOnlyEvents/):
- OnMusicChanged (BindableEvent) — fired on song change
- OnMusicMuteChanged (BindableEvent) — fired on mute toggle. MainHUD's music
  toggle both listens to and fires this, so MainHUD and MusicPlaylistGUI stay
  in sync with whichever one the player used last.

**LocalMusicHandler Public API:**
- ChangeMusicToNextSongInPlaylist()
- ChangeMusicToPreviousSongInPlaylist()
- ChangeCurrentPlaylistInfo(newPlaylistInfo)
- GetCurrentPlaylistInfo() → PlaylistInfo or nil
- GetCurrentPlayingSongInfo() → MusicInfo or nil
- SetCurrentPlayingSongMute(isMuted)
- IsCurrentPlayingSongMuted() → boolean
- SetCurrentPlayingSongLooping(setLooping)
- IsCurrentPlayingSongLooping() → boolean

**Key Architecture Note:** The MusicGUI_Loader script in Workspace.MusicGUI automatically moves its nested StarterGui, StarterPlayer, and ReplicatedStorage folders to the correct services at runtime. After deployment, the loader can be removed. The editable template scripts are in Workspace.MusicGUI.MusicGUI_Loader (not the runtime copies in Players.PlayerGui or StarterGui root — those are deployed clones).

### 2.11 Monetization

**Robux (placeholder, not configured):**
- ShopConfig (ReplicatedStorage): 5 Robux items — AutoCollect (R$149), 2X Cash (R$349), Infinite Cash (R$1499), Mega Dropper (R$249), Golden Dropper (R$599). All productIds = 0.
- CashPackConfig (ReplicatedStorage): 8 cash packs from 5K (R$15) to 5M (R$1999). All productIds = 0.
- Both need real Developer Product IDs from Creator Dashboard before they can sell anything -- Buy currently warns instead of prompting.

**In-game Cash (functional, MiddleShops):**
- CreatureShopConfig, BallShopConfig, TradingPostConfig, VaultConfig,
  UpgradeShopConfig -- each item has a real `cost` in Cash, deducted
  server-side on purchase. This system works end-to-end today. Prices are
  placeholder values and will be retuned once the economy is balanced.

### 2.12 First-Time Tutorial

A nine-step guided onboarding run once per player, the first time they ever
join. Config-driven the same way the shops are: the step list is a single
ReplicatedStorage ModuleScript, and both the client state machine and the
server's persistence drive themselves off it.

**Config (ReplicatedStorage.TutorialConfig):**
Ordered list of steps. Each step is `{ id, title, dialog, target, completion }`.
`target` (what the 3D markers point at) and `completion` (what decides the
step is done) are both `{ root, path }` specs resolved at runtime rather than
hardcoded Instance references -- `root` is `"Plot"` (the player's assigned
plot in Workspace) or `"Player"` (the Player instance, e.g. leaderstats), and
`path` is a "/"-separated child chain walked from there, the same relative-path
convention TycoonProgressService and DataSaveScript already use. Two completion
shapes cover every step: `ValueTrue` (a BoolValue turning true) and
`ValueIncreased` (an Int/NumberValue rising above its value at step start --
deliberately not "changed", since spending Cash lowers it and that must never
read as progress).

The nine steps: BuyFirstDropper, CollectCash, UpgradeFirstDropper,
BuySecondDropper, BuyThirdDropper, BuyFourthDropper, BuyFifthDropper,
UnlockWorkerCentre, HireFirstWorker. Adding or reordering steps is a table
edit -- no code changes.

> **The worker centre requires the WHOLE first row of droppers, not just
> one.** CentreZoneService.luau gates Centre01_Worker's BuyPad behind
> `firstDroppersComplete()`, which requires Slot1 through Slot5's `Activated`
> to ALL be true (`FIRST_DROPPER_COUNT = 5`) before the pad's `CanTouch` even
> turns on -- until then it's a greyed-out "LOCKED" pad. An earlier version of
> this tutorial jumped from Slot1 straight to "unlock the worker centre" and
> pointed the arrow at a pad the player couldn't actually buy yet, because
> Slots 2-5 were still untouched. BuySecondDropper through BuyFifthDropper
> close that gap. If FIRST_DROPPER_COUNT or the row's slot count ever
> changes, this step list needs to change with it.

> **Unlocking the worker centre is not the same as hiring a worker.** The
> centre's BuyPad unlocks the *zone* and sets
> `CentreSlots/Centre01_Worker/Activated` (CentreZoneService). Hiring happens
> separately at `Plot/HiringKiosk` and sets
> `CentreSlots/Centre01_Worker/WorkerActivations/Worker1` (the Studio-native
> WorkerSpawnerController, see section 2.3). They are two real purchases and
> therefore two real steps; conflating them made the step complete the moment
> the zone unlocked, before any worker existed.

**Persistence (ServerScriptService.TutorialProgressService + DataSaveScript):**
TutorialProgressService owns the state; DataSaveScript calls `.Resolve()` on
join with the raw DataStore result and `.Serialize()` at save time, writing an
additive `Tutorial` field into the existing save payload. The job that matters
is telling three DataStore outcomes apart, because GetAsync collapses two of
them into "no saved table":

| Load result | Meaning | Tutorial |
| --- | --- | --- |
| success, no data | genuine first visit | run it |
| success, data | returning player | resume at saved step, or skip if done |
| failure | transient load error | **never** run it |

Treating a failed load as "new player" would replay the tutorial for existing
players, so the failure case resolves first and always resolves to "already
completed". A save written before the `Tutorial` field existed is grandfathered
in as finished for the same reason. Resolved state is mirrored onto the Player
as attributes (`TutorialEligible`, `TutorialCompleted`, `TutorialStepIndex`,
`TutorialSkipped`) so the client reads it straight off replication with no
remote round-trip on join. `.SetStepIndex()` is forward-only and refuses to
touch an ineligible player, so the client driving step advancement can't push
saved progress backward or reopen a finished tutorial.

**Client (StarterGui.TutorialGui):**
Its own ScreenGui with `ResetOnSpawn = false`, deliberately not part of
MainHUD -- that keeps it alive across respawns and keeps every piece of it as
a loose `.luau` file rather than inside an .rbxm. TutorialGuiLoader waits for
the player's `DataLoaded` attribute, then hands off to TutorialController,
which walks the config, points the markers, drives StepPanel, and reports each
completed step to the server.

- **WelcomePanel** -- modal opt-in card, registered with PanelManager like
  every MainHUD panel. Reports three outcomes, not two: Start, Skip, and
  DismissedExternally. The third exists because PanelManager.closeAll() sets a
  registered panel's `.Visible` false *directly*, so any other panel opening (a
  MiddleShops prompt, Settings, Shop, Pets) hid the card with neither button
  pressed and left the controller waiting forever on a decision that could
  never arrive. That is treated as Start, not Skip -- the player never chose to
  opt out.
- **StepPanel** -- non-modal bottom banner showing the current step's title and
  dialog. Deliberately does *not* register with PanelManager, so it stays up
  while the player opens a shop mid-step. There is currently no mid-tutorial
  skip control; the only exits are the welcome panel's Skip or finishing all
  nine steps.
- **ArrowIndicator / ArrowTrail** (ReplicatedStorage) -- the 3D markers: a
  single blue chevron bobbing over the destination, and a flowing yellow
  chevron path from the player to it. Both are client-only, parts-only (no
  WedgePart/SpecialMesh -- built from `CFrame.lookAt` math), and every part is
  `CanCollide/CanTouch/CanQuery = false`, so they can't block a MiddleShops
  ProximityPrompt's line-of-sight raycast or intercept clicks. ArrowTrail reads
  the plot's own floor height (`plot.PrimaryPart` or a `Floor` child, matching
  PlotAssignmentScript) rather than raycasting -- raycasts hit invisible
  collision volumes too, which had the trail climbing onto droppers and pads.

**Respawn and rejoin.** Both work without any explicit pause/resume machinery.
ArrowTrail re-resolves the player's HumanoidRootPart every frame rather than
caching it, so it blanks itself while there is no character and picks up the
replacement on its own; ArrowIndicator never touches the character; and
`ResetOnSpawn = false` keeps the controller and its connections alive. Rejoin
resumes from the saved step index and skips the welcome panel, because progress
is persisted per step rather than only at the end.

**Dev hooks.** Set the Workspace attribute `StudioResetTutorial` to true in Edit
mode to make every joining player eligible again (Studio only, ignored in
published servers -- mirrors PlotAssignmentScript's StudioForcedPlotName). To
reset one player mid-session, run
`require(game.ServerScriptService.TutorialProgressService).Reset(player)` from
the command bar. Note that player attributes only appear in the Properties
window while Play-testing, under the collapsed "Attributes" section.

---

## 3. Key Architectural Decisions

1. **Server-authoritative economy:** All cash transactions happen server-side. leaderstats.Cash is the single source of truth. Clients only see visual effects.
2. **Plot-based ownership:** Plots P1–P10 use Owner/OwnerName attributes. First-come-first-served assignment.
3. **Sequential slot unlocking:** Dependency attributes create purchase chains. Visual states (GHOST/HIDDEN/PURCHASED) communicate availability.
4. **BoolValue "Activated" pattern:** Universal flag across all purchasable slots to mark completion. Checked by section completion, worker spawners, and unlock controllers.
5. **RemoteEvent client-effects pattern:** Server fires events to specific players for sounds/particles. Client scripts handle rendering only.
6. **Music system is fully client-side:** Uses BindableEvents (not RemoteEvents). No server involvement. Third-party asset that self-deploys via loader script. MainHUD integrates with it rather than duplicating mute state.
7. **DataStore versioning:** Key "PlayerCashData_v2" — versioned for future schema migrations.
8. **UI styling system:** StyleSheet + BaseStyleSheet in ReplicatedStorage.Design exist for consistent theming, but MainHUD doesn't use them yet (hardcoded per-instance styling instead).
9. **Worker AI via Humanoid:MoveTo():** Simple pathfinding to nearest cash ball. Stuck detection with position reset.
10. **Player-owned plot themes:** Cosmetic accent membership is persistent CollectionService metadata; clients request a color, while the server resolves ownership, applies it, and saves it per player.
11. **Shared, pluggable shop UI:** ShopRowBuilder builds every shop-style panel's rows (main Shop, all 5 MiddleShops) from the same code, with the purchase flow (Robux vs in-game Cash) swapped via an optional callback rather than duplicated per shop. PanelManager gives every panel the same single-panel-exclusive open/close behavior without each script needing its own copy of that logic.
12. **Config-driven shop content:** Every shop's items live in a small ReplicatedStorage ModuleScript (id/name/cost-or-productId/icon). Adding an item is a table edit; adding a whole new NPC shop is one config module + one panel + one entry in MiddleShopsController's SHOP_DEFINITIONS.
13. **Config-driven onboarding:** The first-time tutorial's step list is one ReplicatedStorage ModuleScript (TutorialConfig), and each step describes its target and its completion condition as a `{root, path}` spec resolved at runtime rather than as a hardcoded Instance reference. Both the client state machine and the server's persistence drive themselves off that one list, so adding, reordering, or removing a step is a table edit. Same shape as the shop configs (decision 12).
14. **Tutorial state resolved from a tri-state DataStore result:** GetAsync collapses "brand-new player" and "load failed" into the same empty result, so TutorialProgressService takes the success flag separately and resolves failure FIRST, always to "already completed". A failed load must never look like a new player, or returning players replay onboarding over their real save. See section 2.12.
15. **Tutorial UI lives outside MainHUD:** TutorialGui is its own ScreenGui with `ResetOnSpawn = false`, rather than more frames inside MainHUD.rbxm. That keeps the controller and its connections alive across respawns, and keeps every part of the feature as loose `.luau` files that sync cleanly through Rojo instead of being buried in a binary model file.
16. **Shared UI utility modules over per-button duplication:** ButtonHoverEffect and Tooltip both follow the same pattern -- one shared module, `Module.apply(button, ...)` / `Module.attach(button, ...)`, rather than copy-pasting tween/event-wiring code per button.

---

## 4. Known Issues & TODOs

- **ShopConfig & CashPackConfig productIds:** All set to 0 — need real Roblox product IDs before publishing
- **MiddleShops item prices:** Placeholder Cash costs in all 5 configs — will change once the economy is tuned
- **MiddleShops item persistence:** Backpack Tools and PurchasedItems counters are NOT saved to DataStore yet — reset on respawn/rejoin
- **Creature Shop items:** All 4 tiers currently grant the same placeholder visual (CreatureBall_Slimey mesh) — needs real per-tier models
- **Ball/TradingPost/Vault/UpgradeShop items:** Only get the generic PurchasedItems counter, no physical item yet (unlike Creature Shop)
- **PetsPanel:** Placeholder only — shows "Soon" pills, not functional
- **Tutorial has no mid-run skip:** The only exits are the welcome panel's Skip button or completing all nine steps. Because an externally-dismissed welcome card now auto-starts the tutorial (section 2.12), a player who opened a shop instead of choosing can end up in a tutorial they didn't pick, with no way out. Low impact -- StepPanel is a non-modal banner and the nine steps are normal progression -- but a small close control on StepPanel would remove it entirely.
- **Tutorial step targets assume the standard plot layout:** Steps resolve paths like `DropperSlots/Slot1/BuyPad` and `HiringKiosk` against the player's plot. P1–P10 are structurally identical today (see CONTRIBUTING's plot-symmetry rule), so this holds -- but a step whose path can't be resolved is warned about and skipped, not retried, so a layout change silently shortens the tutorial rather than erroring.
- **UISoundConfig hover/click sounds:** IDs are empty placeholders — confirmed Roblox's built-in rbxasset:// sounds don't resolve here, so a real uploaded sound is needed
- **Tooltip system:** Wired up and structurally verified (no errors), but never visually confirmed live -- worth a manual check that positioning/timing feels right
- **Music system playlist switching:** README v1.2.0 changelog notes "CURRENTLY SWITCHING PLAYLISTS NEEDS TO BE WORKED OUT IN THE NEXT UPDATE"
- **Music system SoundInfo module:** Exists but unused — appears to be a leftover/generic utility
- **Dead code:** WorldShopConfig (empty stub) and OpenWorldShopEvent are unreferenced anywhere in the codebase — safe to delete, or leave if planned for future use
- **TeleportToTycoonEvent:** Created dynamically at server runtime by PlotAssignmentScript rather than existing as a static RemoteEvent — works but fragile; consider making it a normal template object
- **Empty ScreenGui** in StarterGui — purpose unknown, may be leftover
- **Sketchfab_Scene and Irwin Vernon models** in Workspace — appear to be imported test/reference assets, may need cleanup
- **Design StyleSheet system:** Built but not yet applied to MainHUD
- **`upload_asset` / `get_asset_thumbnail` / `search_assets` MCP tools:** All fail or hang due to a missing ROBLOX_OPEN_CLOUD_API_KEY in this environment. Don't rely on them -- see the Icon Assets note in section 2.8 for the working manual-handoff workflow instead.

---

## 5. Current State Summary

The core tycoon gameplay loop is functional:
- Players join → assigned a plot → buy droppers → buy conveyors → buy structures → buy workers → upgrade machines → collect cash
- Data persists across sessions (cash, plot progression, centre level, upgrades, workers, purchased items, and the selected plot color) -- MiddleShops purchases are the exception, not yet persisted
- All plot machine/structure/wall/glass accents and HiringKiosks respond to server-authoritative player color choices
- Workers auto-collect cash balls
- Visual/audio feedback for purchases, upgrades, and section completions
- Music plays in background with GUI controls, and MainHUD's Settings panel now actually controls it
- 5 NPC shops (MiddleShops) are fully functional: walk up, interact, browse items, buy with in-game Cash, server validates and deducts, Creature Shop purchases grant a real (placeholder) Backpack item
- CashHUDGroup icon buttons (Settings, Teleport to Tycoon) use real image icons with genuine transparency, and every CashHUDGroup button shows a hover tooltip naming itself
- First-time players get a nine-step guided tutorial (dropper → cash → upgrade → 4 more droppers to finish the first row → worker centre → hire), with 3D arrow markers pointing at each target. Progress saves per step, so rejoining partway resumes where they left off; respawning mid-step is handled; and returning players never see it again (see section 2.12)

What's NOT yet built:
- Pets system (placeholder only)
- Real Robux monetization (product IDs not configured for ShopConfig/CashPackConfig)
- Real per-item assets for MiddleShops (all Creature Shop tiers share one placeholder mesh; other 4 shops have no physical item at all yet)
- MiddleShops purchase persistence across sessions
- Real hover/click UI sounds (architecture is there, sound IDs are empty)
- No game loop/win condition beyond tycoon progression
- No mid-tutorial skip control -- once started, the only exit is finishing all nine steps (see section 2.12)
- No admin tools or moderation systems

---

## 6. Next Steps (Suggested)

1. **Manually verify tooltips in Studio** — confirm positioning/offset/timing feels right for all 5 CashHUDGroup buttons (couldn't be verified live by tooling, only structurally)
2. **MiddleShops economy tuning** — replace placeholder Cash costs in the 5 shop configs once the tycoon economy is balanced
3. **MiddleShops persistence** — save Backpack items / PurchasedItems counters in DataSaveScript so purchases survive rejoining
4. **Real MiddleShops assets** — replace the shared CreatureBall_Slimey placeholder with distinct per-tier creature models, and add real items for Ball/TradingPost/Vault/UpgradeShop
5. **Configure Robux products** — replace placeholder productIds in ShopConfig and CashPackConfig with real Roblox product IDs, implement ProcessReceipt handler
6. **Real UI sounds** — upload or source real hover/click sound assets and set hoverSoundId/clickSoundId in UISoundConfig
7. **Build pets system** — replace "Soon" placeholders with actual pet collection/equipping (likely reuses the Creature Shop item-granting pattern)
8. **Apply Design StyleSheet to MainHUD** — currently hardcoded per-instance styling instead of the built StyleSheet system
9. **Add game progression** — consider prestige system, rebirth, or end-game goals
10. **Clean up Workspace** — remove unused models (Sketchfab_Scene, Irwin Vernon, empty ScreenGui), and decide on WorldShopConfig/OpenWorldShopEvent (delete or build out)
11. **Add admin/bug reporting** — consider adding admin commands or bug report UI for development
12. **Performance optimization** — profile with 10 simultaneous players, optimize worker AI and ball spawning
13. **Testing & QA** — full playtest with edge cases (rejoining, plot stealing prevention, DataStore failure handling)

---

## 7. Important Notes for Future Sessions

- **Editing the music script:** Edit Workspace.MusicGUI.MusicGUI_Loader.StarterGUI.MusicPlaylistGUI.MusicPlaylistGUIScript (the template). Do NOT edit the runtime copy in StarterGui.MusicPlaylistGUI or Players.<n>.PlayerGui — those are deployed clones.
- **MusicGUI_Loader** auto-deploys at runtime. If you manually move folders to their proper services, the loader is no longer needed and can be deleted.
- **All server scripts** are in ServerScriptService (game logic) and ServerStorage.WorkerTemplates (worker AI). No server scripts in Workspace — all Workspace scripts are per-plot clones of template scripts.
- **DataStore key** is PlayerCashData_v2 — if you change the schema, bump the version.
- **Plot models** P1–P10 are identical in structure. Changes to plot structure should be applied to all 10.
- **Dependency attribute** on slots controls unlock order — modifying this chain affects gameplay flow.
- **CorePackages is empty** — there is no AppMusicPlayer package despite earlier references. The only music system is the third-party MusicGUI.
- **Adding a new MiddleShops-style shop:** create a ReplicatedStorage config ModuleScript (see CreatureShopConfig for the shape), clone one of the 5 existing panel Frames' chrome, add one entry to MiddleShopsController's SHOP_DEFINITIONS table. No changes needed to ShopRowBuilder, PanelManager, or MiddleShopPurchaseHandler unless the new shop needs a different purchase flow (e.g. Robux instead of Cash) or its own item-granting logic (add another `if configName == "..."` branch in MiddleShopPurchaseHandler, following the Creature Shop example).
- **Testing Cash-balance-dependent logic:** this economy's passive income is fast (tens of thousands/sec on active accounts). Don't set Cash low from a client script and wait before checking -- that write doesn't even replicate to the server's authoritative value. Use eval_server_runtime with a zero-yield check for real insufficient-funds testing.
- **Adding hover tooltips to a new button:** `require(ReplicatedStorage.Tooltip).attach(button, "Label Text")` -- that's it, no per-button UI to build.
- **Fixing a transparent-PNG-that-isn't-actually-transparent icon:** check alpha channel mode first (PIL: `img.mode`). If it's RGB with no alpha, don't assume a simple color threshold will work -- check whether the icon's own fill color is close to the background color first (sample a few pixels). If they're close, use the texture-variance-per-connected-region method described in section 2.8's Icon Assets note, not a plain threshold.
- **Adding or reordering a tutorial step:** edit the TutorialConfig table, nothing else. Each entry needs `id`, `title`, `dialog`, a `target` `{root, path}` (something with a world position -- Model or BasePart) and a `completion` `{type, root, path}` (`ValueTrue` for a BoolValue, `ValueIncreased` for an Int/NumberValue). A step whose path doesn't resolve is warned about and skipped rather than hanging the sequence -- so if a step silently never appears, check the path against the real plot hierarchy first.
- **Testing the tutorial without a fresh account:** set the Workspace attribute `StudioResetTutorial` to true in Edit mode (Studio-only, ignored when published) to make every joining player eligible again, or reset one player mid-session from the command bar with `require(game.ServerScriptService.TutorialProgressService).Reset(player)`. The tutorial's Player attributes (`TutorialEligible`, `TutorialStepIndex`, ...) only show up in the Properties window while Play-testing, under the collapsed "Attributes" section.
- **Don't conflate unlocking the worker centre with hiring a worker.** `CentreSlots/Centre01_Worker/Activated` is the zone unlock (CentreZoneService); `CentreSlots/Centre01_Worker/WorkerActivations/Worker1` is an actual hired worker (WorkerSpawnerController at `Plot/HiringKiosk`). They're separate purchases. WorkerSpawnerController and the P1–P10 plots are Studio-native and not in the Rojo source tree, so section 2.3 is the best available description of them.
- **Roblox asset upload/search tools are broken in this environment** (missing API key) — go straight to the manual Asset-Manager-import + asset-ID handoff workflow, don't waste a turn retrying `upload_asset` first.

---

This document reflects the state of the game as of the current session. It should be updated whenever major systems are added, changed, or removed.
]]

return nil
