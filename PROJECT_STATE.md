# PROJECT_STATE.md

## Game Overview

**Genre:** Tycoon (conveyor-based production tycoon)
**Players:** 10 plots (P1–P10), multiplayer capable
**Build Status:** Early-to-mid development. Core tycoon loop is functional. Three of five plot centres (Worker, Home, Avatar) are built; Orb and Pet are empty placeholders. The NPC shops, a Gem bank, PvP weapons, the first-time tutorial, and the code-built, themeable MainHUD all work. Robux monetization placeholders exist but are not wired to real products.

**Last audited:** 2026-10-08, against `main` at `bb7e5ac` (after PRs #15 Bank, #16 Plot fixes, #17 Small UI fix, #18 UI redesign). Outstanding work is tracked in [`TODO.md`](TODO.md).

---

## 1. Complete Architecture

### 1.1 DataModel Hierarchy

This reflects the Rojo-managed content under `src/`. Every service in `default.project.json` sets `$ignoreUnknownInstances`, so the Studio place can also contain instances that are not in the repo.

```
game/
├── Workspace/
│   ├── Baseplate, SpawnLocation, Terrain, Camera, SurfaceGui
│   ├── Hub (Part)
│   ├── BallShop, CreatureShop, GearShop, Bank (single Parts; GearShop and Bank
│   │   added and the other two changed in PR #15; purpose undocumented -- see TODO.md)
│   ├── Roblox_Coil (Model with one CoilMesh, added in c57c46c; not referenced
│   │   by name in any script)
│   ├── MiddleShops/ (Folder)
│   │   ├── BallShopStructure, CreatureShopStructure, GearShopStructure -- each
│   │   │   with a <Name>ShopKeeper/Body/InteractPrompt (ProximityPrompt)
│   │   └── BankStructure -- BankZone (two parts share this name, see section
│   │       2.16), DepositPad, BankSign, Fence1-4. No ProximityPrompt or panel.
│   ├── P1–P10 (10 Plot Models, identical structure)
│   │   ├── Floor, PerimeterWall (Model; collision driven by PlotWallCollisionService)
│   │   ├── HiringKiosk (tagged ThemedModel; 13 themed parts + 4 collision boxes)
│   │   ├── LaserDoor (Model) + LaserDoorToggleScript
│   │   ├── CeilingLights (Model) + CeilingLightsController
│   │   ├── VoicelineStation (Model, see section 2.17)
│   │   ├── CentreSlots/ — five sequential centres (see section 2.14):
│   │   │   ├── Centre01_Worker — Upgrades/WorkerSpeedUpgrade, WorkerNotesGiftsStation
│   │   │   │   (section 2.13), WorkerActivations/ (6 BoolValues, one per worker)
│   │   │   ├── Centre02_Home — StructureSlots/ Slot_Walls, Slot_Glass,
│   │   │   │   Slot_LaserDoor, Slot_Roof, Slot_CeilingLights (section 2.15)
│   │   │   ├── Centre03_Avatar — Upgrades/ KnockbackPlankStation, CoilStation,
│   │   │   │   SpeedUpgradeTreadmill, ThrowableBallStation (section 2.18)
│   │   │   ├── Centre04_Orb — Upgrades/ is empty (planned)
│   │   │   └── Centre05_Pet — Upgrades/ is empty (planned)
│   │   ├── DropperSlots/ (Folder) — Slot1-5 (BuyPadScript, BallDropperScript)
│   │   ├── DropperSlots2/ (Folder) — Slot1-5 + DropperSlots2UnlockController
│   │   ├── ConveyorSlots/ (Folder) — Conveyor1-3
│   │   ├── ConveyorBeltBig/ (Folder) — Conveyor4-6
│   │   ├── ConveyorBeltSuper/ (Folder) — Conveyor7
│   │   ├── ultra_conveyor/ (Folder)
│   │   ├── BallPressMachines/ (Folder)
│   │   └── OrbitalReactorMachines/ (Folder)
│   ├── TycoonDropper (model with scripts)
│   ├── Tycoon Walls Grass (model)
│   └── MusicGUI/ (Folder — third-party music asset)
│       ├── MusicGUI_Loader (Script — auto-moves content to proper services)
│       │   ├── StarterGUI/MusicPlaylistGUI (ScreenGui + scripts)
│       │   ├── StarterPlayer/StarterPlayerScripts/MusicChangeHandler
│       │   └── ReplicatedStorage/Modules/ClientOnlyModules/ + Events/
│       └── README (LocalScript — documentation + examples)
│
├── ReplicatedStorage/
│   ├── UI shared modules: ButtonHoverEffect, UISoundConfig, PanelManager,
│   │            ShopRowBuilder, CashFormat, Tooltip, SFXSettings
│   ├── HUD theme (see section 2.8): UITheme (selector), UITheme_Production,
│   │            UITheme_Prototype, UISurface (textured-surface helper)
│   ├── Shop item configs (Robux): ShopConfig, CashPackConfig
│   ├── Shop item configs (in-game Cash, MiddleShops): CreatureShopConfig,
│   │            BallShopConfig, GearShopConfig; plus dormant TradingPostConfig,
│   │            VaultConfig, UpgradeShopConfig (see section 2.4b)
│   ├── Other modules: PurchaseEffectModule, PurchaseSoundModule,
│   │            MachineUpgradeConfig, PlotThemeConfig, PlotTheme,
│   │            WorkerSpeedConfig, TreadmillTheme, ThrowableBallConfig,
│   │            VoicelineCatalog
│   ├── First-time tutorial (see section 2.12): TutorialConfig (step list),
│   │            ArrowIndicator + ArrowTrail (3D world markers)
│   ├── Apparently unused (no script references found, see section 4):
│   │            PurchaseEffectModule_FreshTest6, BouncePlatformTheme
│   ├── Design/ (StyleSheet, BaseStyleSheet — excluded from sync by
│   │            globIgnorePaths; not applied to MainHUD)
│   ├── Ghosts/: SpeedUpgrade_Treadmill_Ghost (used by TreadmillGhostPreview),
│   │            JumpUpgrade_ArrowBouncePlatform_Ghost (apparently unused)
│   ├── Models: ConveyorCrate, LaserDoorTemplate
│   ├── RemoteEvents: MachineUpgradeSparkleEvent, PurchaseSoundEvent,
│   │                 MiddleShopPurchaseEvent, BankDepositEvent (section 2.16),
│   │                 VoicelineMenuEvent (section 2.17),
│   │                 ThemeRemotes/RequestPlotColor,
│   │                 TutorialStepEvent, TutorialCompleteEvent (section 2.12),
│   │                 WorkerGiftsInteractionEvent (section 2.13)
│   │   (TeleportToTycoonEvent also lives here at runtime, but is created
│   │   dynamically by PlotAssignmentScript on server start -- not a static
│   │   template object. See section 2.1.)
│   └── StringValue: CashRainImageId
│
├── ServerStorage/
│   ├── CreatureShopPlaceholderItem (Tool) — placeholder item granted by
│   │   every Creature Shop purchase; wraps a cloned CreatureBall_Slimey
│   │   MeshPart as its Handle. Same visual for all 4 creature tiers for now.
│   ├── Machines/: SpeedUpgrade_Treadmill (used), JumpUpgrade_ArrowBouncePlatform
│   │   (apparently unused -- the Coil station replaced the jump upgrade)
│   ├── Templates/: VoicelineStation, VoicelineMicrophone_Roblox,
│   │   WorkerNotesGiftsStation
│   ├── Tools/: KnockbackPlank, ThrowableBall (each a Tool with a
│   │   ToolClient LocalScript and a Swing/Throw RemoteEvent; section 2.18)
│   ├── SavedLightDesigns/CeilingLights_Orbs (Model + controller)
│   ├── Modules/: WorkerNotesGiftsStationTheme (color/material contract for the
│   │   station's 42 meshes, section 2.13), VoicelineStationTheme,
│   │   VoicelineBuyPadLayout (section 2.17)
│   ├── LegacyAssets/ — pre-migration backups (e.g. a P1-only treadmill
│   │   service backup, imported station models). Historical, not active.
│   └── WorkerTemplates/ (Worker1, ConveyorWorker, BigConveyorWorker — all with WorkerScript)
│
├── ServerScriptService/
│   ├── PlotAssignmentScript (also creates TeleportToTycoonEvent at runtime if
│   │   missing, and resets a plot when its owner leaves -- section 2.1)
│   ├── DataSaveScript
│   ├── WorkerVoiceLineController
│   ├── WorkerCountDisplayService — worker count billboard in each HiringKiosk
│   ├── MachineUpgradeFeedbackService
│   ├── MachineSectionCompletionSoundService
│   ├── MiddleShopPurchaseHandler — server-authoritative Cash purchases for
│   │   the MiddleShops NPCs (see section 2.4b)
│   ├── BankZoneHandler — Gem deposits at the Bank (section 2.16)
│   ├── DropperBuyPadNameGuard
│   ├── CentreZoneService — centre unlock order and gating (section 2.14)
│   ├── StructureSequenceService — Home Centre structure pad (section 2.15)
│   ├── PlotWallCollisionService — perimeter wall collision (section 2.15)
│   ├── PlotThemeService
│   ├── WorkerSpeedService
│   ├── VoicelineStationService (section 2.17)
│   ├── SpeedUpgradeTreadmillService, CoilStationService,
│   │   KnockbackPlankService, ThrowableBallStationService — Avatar Centre
│   │   stations (section 2.18)
│   ├── TutorialProgressHandler — network wiring for the two tutorial
│   │   RemoteEvents (see section 2.12)
│   ├── WorkerNotesGiftsStationService — Daily Worker Gifts station wiring,
│   │   claim flow, and cooldown status display (see section 2.13)
│   └── ModuleScripts:
│       ├── TycoonProgressService — captures/applies/resets plot progress
│       ├── TutorialProgressService
│       ├── WorkerGiftCooldownService — owns the 24h Daily Worker Gifts claim
│       │   cooldown (see section 2.13)
│       ├── CombatDamageService — shared PvP damage, knockback and ragdoll
│       ├── ThrowableBallCombatService — server-side projectile simulation
│       └── StructurePurchaseService — only required by the per-slot
│           StructureBuyPadScripts, which are saved Disabled (section 2.15)
│
├── StarterGui/
│   ├── StatsHUD (ScreenGui) + StatsHUDUpdater (LocalScript)
│   ├── MainHUD (ScreenGui, built in code -- see section 2.8)
│   │   ├── MainHUDBuilder (ModuleScript) — constructs the whole tree
│   │   ├── MainHUDController (LocalScript) — main orchestrator
│   │   ├── MiddleShopsController (LocalScript) — wires the MiddleShops panels
│   │   ├── ShopPanelController, CashPackPanelController (ModuleScripts)
│   │   ├── Tooltip (TextLabel) — single shared hover-tooltip element
│   │   ├── CashHUDGroup — CashPanel (+ PlusButton), the house-icon
│   │   │   TeleportToTycoonButton, and a ButtonRow of four icon buttons:
│   │   │   Shop, Pets, Inventory, Settings. All six buttons have tooltips.
│   │   ├── SettingsPanel — Music toggle (real, wired to MusicGUI's
│   │   │   LocalMusicHandler), SFX toggle (real, wired to SFXSettings)
│   │   ├── ShopPanel — Robux shop (ShopConfig items), rows via ShopRowBuilder
│   │   ├── CashPackPanel — Cash purchase packs (CashPackConfig, Robux),
│   │   │   custom row styling (not ShopRowBuilder)
│   │   ├── PetsPanel — placeholder (still "Soon" pills, not functional)
│   │   ├── InventoryPanel — placeholder (empty content area)
│   │   ├── CreatureShopPanel, BallShopPanel, GearShopPanel — the MiddleShops
│   │   │   panels, rows built via shared ShopRowBuilder (section 2.4b)
│   │   └── RichestBanner, HealthBar
│   ├── MainHUD_VisualReference (disabled .rbxm copy of the old hand-placed
│   │   HUD, Studio-only reference -- see section 2.8)
│   ├── TutorialGui (ScreenGui, ResetOnSpawn=false) — the first-time
│   │   tutorial's client UI; separate from MainHUD so it survives respawn
│   │   and so none of it lives in an .rbxm (see section 2.12)
│   │   ├── TutorialGuiLoader (LocalScript) — waits for DataLoaded, hands off
│   │   ├── TutorialController (ModuleScript) — the state machine
│   │   ├── WelcomePanel (ModuleScript) — modal opt-in/skip card
│   │   ├── StepPanel (ModuleScript) — non-modal bottom step banner
│   │   └── CompletionPanel (ModuleScript) — modal "you're all set" card
│   └── ScreenGui (empty)
│
├── StarterPlayer/
│   ├── StarterCharacterScripts/
│   │   └── SprintSystem (LocalScript)
│   └── StarterPlayerScripts/ (loose .client.luau files)
│       ├── StructureGhostPreviewScript (LocalScript)
│       ├── PreviewController — floating emoji preview over the Home Centre
│       │   structure pad (section 2.15)
│       ├── TreadmillGhostPreview — owner-only ghost of the unbought treadmill
│       ├── PurchaseSoundClient (LocalScript)
│       ├── MachineIncomeCashRainClient (LocalScript)
│       ├── MachineUpgradeSparkleClient (LocalScript)
│       ├── BankFeedbackClient — Bank deposit countdown and toast (section 2.16)
│       ├── ToolInventoryClient — custom 10-slot tool hotbar; hides Roblox's
│       │   default Backpack UI while active (section 2.18)
│       ├── VoicelineMenuClient — voiceline preview menu (section 2.17)
│       └── WorkerGiftsPopupClient (LocalScript) — Daily Worker Gifts
│           claim/cooldown toast popup (see section 2.13)
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
- On player leave: captures the plot's progress for DataSaveScript
  (`TycoonProgressService.SetDepartureProgress`), then fully resets the plot
  (`TycoonProgressService.ResetPlot`) while a `RestoringProgress` attribute
  keeps cleanup quiet, sets `UpgradeLevel` back to 1, and clears `Owner` last
  so the blank plot is immediately available. `ResetPlot` restores every plot
  script's original enabled/disabled state (some legacy purchase scripts stop
  listening after a purchase, so resetting `Activated` alone was not enough)
  and destroys the plot's loose balls/crates by their `SourcePlot` attribute.
  Added in PR #16 to fix plots not fully reverting.
- Waits for DataLoaded attribute before applying saved upgrade level
- Also creates ReplicatedStorage.TeleportToTycoonEvent at runtime if it
  doesn't already exist (FindFirstChild-then-Instance.new fallback). Works,
  but is a fragile pattern -- consider converting to a static RemoteEvent
  in the template instead of relying on script-order bootstrapping.

**DataSaveScript** (ServerScriptService)
- DataStore key: **PlayerCashData_v3** (bumped from v2 on 2026-10-08 in PR #16).
  The bump intentionally started every player with a clean save; the v2 store is
  left untouched for rollback.
- Saves Cash, Gems and BankedGems (section 2.16), upgrade level, centre level,
  plot progression (every `Activated`/worker BoolValue via TycoonProgressService,
  which covers centres, structures and Avatar Centre stations), the
  PurchasedItems counters, the player's selected plot color, tutorial progress,
  and the Daily Worker Gifts cooldown timestamp (see section 2.13)
- Loads on join; saves on leave, on server close (BindToClose), and on a 60s
  autosave loop. Each save retries up to 3 times with exponential backoff.
- If the load fails, sets `DataLoadFailed` and refuses to save for that session,
  so a failed load can never overwrite real data
- Sets player:SetAttribute("DataLoaded", true) to signal completion
- PurchasedItems counters ARE saved and restored (this has been true since the
  Rojo migration; earlier versions of this doc said otherwise). The Creature
  Shop's Backpack Tool is NOT saved and is not re-granted on rejoin.

**Economy Flow:**
- Server-authoritative. leaderstats.Cash (IntValue) is the single source of truth
- BallDropperScript spawns cash balls every 1.5s with Value and SourcePlot attributes
- Balls collected by player touch or worker touch
- ConveyorScript drops crates every 4s → crates break on floor → release 5 cash balls
- BuyPadScript (droppers/conveyors) and StructureSequenceService (Home Centre structures, section 2.15) validate ownership, deduct cash, and activate slots on the server
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

NPC shops in Workspace.MiddleShops, each with a ProximityPrompt that opens a
matching UI panel. Fully functional end-to-end (built + verified in a live
playtest, including insufficient-funds and invalid-item/invalid-shop
rejection paths).

**Current shop lineup (reduced from the original five):** Creature Shop,
Gear Shop, Ball Shop, and the Bank. Trading Post, Vault and Upgrade Shop were
cut -- their structures are gone from Workspace.MiddleShops and their entries
removed from SHOP_DEFINITIONS.

**Deliberately kept for a possible future re-add:** TradingPostConfig,
VaultConfig and UpgradeShopConfig still exist in ReplicatedStorage and are
still listed in MiddleShopPurchaseHandler's ALLOWED_CONFIG_NAMES. They are
unreachable from the client (no panel, no prompt, no SHOP_DEFINITIONS entry),
so this is dormant rather than broken. To bring one of those shops back:
re-add its structure to Workspace.MiddleShops, add a panel in MainHUDBuilder,
and add one SHOP_DEFINITIONS entry. Delete all three if the shops are gone
for good.

**The Bank is not a shop panel.** BankStructure has no ProximityPrompt and no
SHOP_DEFINITIONS entry; it is a walk-in Gem deposit zone instead. See section
2.16.

**GearShopConfig is placeholder content** (Grip Gloves / Speed Boots / Magnet
Glove / Power Gauntlet, 900-18000 Cash) -- invented to match the other shop
configs' shape, not designed. Swap in real gear before shipping.

**Client (StarterGui.MainHUD.MiddleShopsController):**
- Loops over a SHOP_DEFINITIONS table (`panelKey`, config module name,
  ProximityPrompt path, action/object text) -- adding a shop is one table
  entry plus a matching panel and config module, no other code changes.
  `panelKey` indexes `refs.middleShops` from MainHUDBuilder, whose own
  `MIDDLE_SHOPS` list (key, instance name, title) builds the panels.
- CAUTION: the config is resolved with a no-timeout WaitForChild, so an entry
  naming a config that does not exist stalls the loop forever and silently
  leaves every later shop in the table unwired. A `panelKey` missing from
  MainHUDBuilder's `MIDDLE_SHOPS` errors immediately instead. The
  ProximityPrompt path has a 5s timeout and only warns. Always add the panel
  and config before the table entry.
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
  - The PurchasedItems counters are saved to DataStore. The Creature Shop's
    Tool is cloned into the Backpack only (not StarterGear) and is not saved,
    so it is lost on respawn and on rejoin (see DataSaveScript note above).
    MiddleShopPurchaseHandler's header comment still describes "the 5
    MiddleShops NPCs" including Trading Post/Vault/Upgrade -- that part of the
    comment is out of date.

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
  e.g. 50000 -> "$50,000". Used by every MiddleShops config module.

**Item prices are all placeholders and will change once the economy is
tuned** -- CreatureShopConfig/BallShopConfig/GearShopConfig (and the dormant
TradingPostConfig/VaultConfig/UpgradeShopConfig) all have a `cost` (in-game
Cash) field per item with
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
  and a ButtonRow of Shop/Pets/Inventory/Settings icon buttons, so their
  spacing stays fixed together
- SettingsPanel: Music toggle -- REAL, wired to MusicGUI's LocalMusicHandler
  (shared mute state with MusicPlaylistGUI via the OnMusicMuteChanged
  BindableEvent). SFX toggle -- REAL, wired to SFXSettings.
- ShopPanel + ShopPanelController: Robux shop (ShopConfig items), rows via
  shared ShopRowBuilder
- CashPackPanel + CashPackPanelController: Cash purchase packs
  (CashPackConfig, Robux), custom row styling with a "50% OFF!" badge
- PetsPanel: placeholder with "Soon" pills — still not functional
- InventoryPanel: placeholder with an empty content area (added in PR #18)
- CreatureShopPanel / BallShopPanel / GearShopPanel: the MiddleShops panels
  — see section 2.4b
- RichestBanner, HealthBar

**HUD theme system (PR #18).** Every visual value MainHUDBuilder,
ShopRowBuilder, CashPackPanelController and MainHUDController use (colours,
gradients, fonts, sizes, positions, corner radii, asset ids) comes from a theme
table, not from the controllers. Structure (instance names, hierarchy, ZIndex,
text content) deliberately stays out of the theme.
- `ReplicatedStorage.UITheme` is a one-line selector: its `ACTIVE_THEME`
  string names which module to return. It currently names
  `UITheme_Prototype`.
- `UITheme_Production` and `UITheme_Prototype` are full copies, not an
  override layer. As of PR #18 they are **byte-identical**.
- **Workflow (decided 2026-10-08):** try new looks in
  `UITheme_Prototype`; once approved, copy the changed blocks into
  `UITheme_Production`. Keep both files; don't collapse them into one.
- Keep the two files' key sets in step. A required key missing from the
  active theme reads as `nil` and errors. A few keys are deliberately
  optional (`header`, `titleBarSurface`, `closeSurface`, `buySurface`, and
  the `itemList` padding keys): the builders check for them and fall back to
  the plain look when absent.
- `ReplicatedStorage.UISurface.applyTexturedSurface(obj, spec)` builds the
  textured "3D slab" look (gradient, tiled stripe pattern, outline, extruded
  lip) from a surface spec in the theme.
- To switch themes: edit `ACTIVE_THEME`, re-sync, then **Stop and Play
  again**. The HUD is built at runtime, so a running playtest won't change.

**MainHUD is now built in code, not hand-placed.** `src/StarterGui/MainHUD/`
is a directory, not an .rbxm: an init.meta.json defining the ScreenGui, a
MainHUDBuilder ModuleScript that constructs the whole tree with Instance.new,
and the four controllers as loose .luau files (ShopPanelController and
CashPackPanelController are ModuleScripts taking the panel to populate, since
their panels no longer exist at sync time -- MainHUDController calls both).

Confirmed working in Studio, and every component is verified
property-by-property against the original hand-placed layout via rbxmk. To
re-check after editing the builder, build the tree in-process with
`rbxmk.loadFile` and diff it against
src/StarterGui/MainHUD_VisualReference.rbxm (see below); the one property that
cannot be verified this way is FontFace, since rbxmk silently drops FontFace
when it reads an .rbxm -- never round-trip either .rbxm in this section
through rbxmk, only read from it.

**`src/StarterGui/MainHUD_VisualReference.rbxm` is the original hand-placed
UI, kept on purpose as a Studio-only visual reference.** MainHUDBuilder has no
visual editor -- to preview or tweak a size/position/color by eye rather than
by reasoning about numbers, open this instead. It syncs into StarterGui as
`MainHUD_VisualReference` (a ScreenGui, `Enabled = false`, both LocalScripts
inside it `Disabled = true`), so Studio's edit-mode viewport still renders it
for inspection, but it never appears at runtime and never executes a
controller. It is NOT kept in sync with MainHUDCode changes going forward --
edit it in Studio if you want an updated reference, or delete it if it's no
longer useful.

To change it: edit live in Studio (drag/resize/whatever), then right-click the
top-level `MainHUD_VisualReference` instance -> **Save to File** -> overwrite
this same path. That round-trip goes through Studio's own serializer, not
rbxmk, so fonts are safe. Do not rename the live instance back to `MainHUD` --
that's the name the real, code-driven ScreenGui (`src/StarterGui/MainHUD/`)
needs for `ReplicatedStorage.Tooltip`'s `PlayerGui:WaitForChild("MainHUD")`
lookup to keep working, and Roblox allows two siblings with the same name
without erroring, which just means whichever the client finds first wins.

GOTCHA if you're re-adding an exclusion or otherwise editing
`globIgnorePaths`: `rojo serve` loads `default.project.json` once at startup
and does not appear to hot-reload changes to the project file's own
structure. If a change like this doesn't seem to take effect in Studio after
reconnecting, restart the `rojo serve` process itself, not just the Studio
plugin connection.

Two things to keep in mind when editing this UI:
- `ReplicatedStorage.Tooltip` resolves its label via
  `PlayerGui:WaitForChild("MainHUD")` by name, so the ScreenGui must keep the
  name MainHUD -- i.e. do not rename that directory.
- Fonts are the one property rbxmk cannot read out of an .rbxm (it silently
  drops FontFace), so the builder's Font values came from a written spec and
  are the one thing unverified against the original. Never round-trip an
  .rbxm through rbxmk -- it would wipe every font in the file.
- **Unverified font claim:** the `Theme.font` comments in both theme files
  state that this Studio build ships no Gotham font files, so
  `Enum.Font.GothamBlack`/`GothamBold` (used for headings and body text)
  probably render as Montserrat. Nobody has confirmed this. A visual check in
  Studio is pending (see TODO.md).

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
  reused). hoverSoundId and clickSoundId in UISoundConfig now hold real
  uploaded asset IDs, so both sounds do play -- the file's comment block still
  describes them as empty placeholders and is out of date. Hover animation
  works independently of the sounds either way.
- **Tooltip** (ReplicatedStorage): `Tooltip.attach(button, text, options?)`.
  Uses ONE reusable label (StarterGui.MainHUD.Tooltip, AutomaticSize.X,
  ZIndex 100) instead of creating an instance per button. Shows on
  MouseEnter, follows the cursor via MouseMoved (screen-space coords,
  default offset +16/-10 so it doesn't sit under the cursor), hides on
  MouseLeave. Attached to all 6 CashHUDGroup buttons in MainHUDController:
  PlusButton -> "Add Cash", TeleportToTycoonButton -> "Teleport to Tycoon",
  InventoryButton -> "Inventory", SettingsButton -> "Settings",
  ShopButton -> "Shop", PetsButton -> "Pets".
  Verified structurally (loads with no errors, correct initial state) but
  NOT visually confirmed live -- available tooling can only simulate clicks,
  not real mouse movement, so the actual on-screen feel (timing/offset) is
  unverified. Worth a manual look in Studio.
- PanelManager, ShopRowBuilder: see section 2.4b

**Icon Assets (CashHUDGroup buttons):**
- As of PR #18 every CashHUDGroup button except PlusButton uses an image icon,
  and all the asset ids live in `Theme.asset` (teleportIcon, shopIcon,
  petsIcon, inventoryIcon, settingsIcon). The notes below are the history of
  the first two icons.
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
- There is no `MarketplaceService.ProcessReceipt` handler anywhere in `src/` yet, so even with real IDs, purchases would not grant anything until one is written.

**In-game Cash (functional, MiddleShops):**
- CreatureShopConfig, BallShopConfig, GearShopConfig, and the dormant
  TradingPostConfig/VaultConfig/UpgradeShopConfig -- each item has a real
  `cost` in Cash, deducted
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
- **CompletionPanel** -- modal "You're All Set!" card shown once, when
  `finish()` runs on the `wasSkipped == false` path (every step actually
  completed, including the degenerate case where every step's target failed
  to resolve and the controller cascaded straight through -- it doesn't
  distinguish the two). Never shown on a Skip -- congratulating an opt-out
  doesn't make sense. Registers with PanelManager like WelcomePanel, but
  needs no DismissedExternally escape hatch: by the time it's shown the
  tutorial has already ended and nothing is waiting on its outcome, so
  PanelManager silently closing it for another panel is harmless rather than
  a deadlock.
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

### 2.13 Daily Worker Gifts

A once-per-24-hours Cash claim at the existing Worker Notes & Gifts station
(`Plot/CentreSlots/Centre01_Worker/WorkerNotesGiftsStation`), unlocked after
the station's own one-time $5 purchase (`PurchaseState/Activated`). Interact
via the station's `WorkerGiftsPrompt` ProximityPrompt (E / gamepad X).

**Server (ServerScriptService.WorkerGiftCooldownService, ModuleScript):**
Owns the cooldown only -- not the reward, not the interaction. Mirrors
TutorialProgressService's tri-state DataStore resolution (see decision 14 in
section 3): a failed load must never look like "no cooldown active," so
`IsAvailable` and `GetRemainingSeconds` both refuse outright while
`DataLoadFailed` is set, regardless of the timestamp. Public API:
`Resolve(player, loadSucceeded, savedData)` (called on join, mirrors
`TutorialProgressService.Resolve`), `Serialize(player)` (feeds
`DataSaveScript`'s save payload), `IsAvailable`, `GetRemainingSeconds`,
`MarkClaimed`, and a dev-only `Reset(player)` callable from the Studio command
bar. `COOLDOWN_SECONDS` (24h) is exported so nothing else hardcodes it. The
timestamp persists as `LastWorkerGiftClaim` in the same save payload
DataSaveScript already writes (`getPlayerData`), and is mirrored onto the
Player as an attribute of the same name.

**Claim flow (ServerScriptService.WorkerNotesGiftsStationService):** the
station's `ProximityPrompt.Triggered` already only fires server-side with a
trusted `player` argument, so no RemoteEvent round-trip was needed for the
request leg -- ownership and purchase state are re-validated the same way the
station's existing buy-pad already does. A short `os.clock()` debounce (1s,
pre-existing) blocks rapid double-fires; the real gate is
`WorkerGiftCooldownService.IsAvailable`. On success: grants a **placeholder**
`PLACEHOLDER_GIFT_REWARD_CASH = 150` (flagged in-code; swapping in the real
reward is a one-line change), calls `MarkClaimed`, no yield between the two.
The result fires back over the pre-existing `WorkerGiftsInteractionEvent`
RemoteEvent (previously used only for cosmetic flavor text) with an `outcome`
of `"Claimed"` or `"OnCooldown"`.

**Countdown UI:** two pieces, both driven off the server-persisted timestamp
rather than a free-running client clock:
- World-space: the station's existing persistent `GiftStatusLabel`
  BillboardGui (previously a static "🎁 1 gift/day") now shows "🎁 Ready to
  claim!" or "🎁 Ready in Xh Ym" for the plot **owner's** cooldown, refreshed
  by the same 0.5s loop that already drives the buy-pad's affordability color.
- Toast: `WorkerGiftsPopupClient` (StarterPlayerScripts) live-ticks the
  remaining time at second precision for its own ~3.25s visible window via
  `RunService.Heartbeat`, anchored to elapsed client time since that specific
  toast appeared -- cosmetic only; the 24h gate is enforced server-side on the
  next interact regardless of what the toast displays.

> **Opening animation (originally planned as a follow-up milestone) is
> undecided.** The station discovery, cooldown foundation, claim +
> placeholder reward, and countdown UI are complete and the claim flow works
> correctly today with an instant reward grant and no animation. Whether to
> add a lid rotation/scale tween (or similar) on claim is still being
> weighed -- it's a presentation layer on top of an already-functional
> feature, not a blocker for anything else built on top of it. Revisit this
> section once that's decided.

**Dev hooks.** `require(game.ServerScriptService.WorkerGiftCooldownService)`
from the Studio command bar: `.Reset(player)` re-tests the claim repeatedly
without waiting 24h or touching any other saved field (unlike wiping the
whole DataStore entry, which resets Cash/plot color/tutorial progress too).
`.IsAvailable(player)` / `.GetRemainingSeconds(player)` for direct inspection.

### 2.14 Plot Centres (CentreZoneService)

Every plot has five open-plan centre areas under `CentreSlots`, unlocked in a
fixed order by **CentreZoneService**: `Centre01_Worker` → `Centre02_Home` →
`Centre03_Avatar` → `Centre04_Orb` → `Centre05_Pet`. Each centre model holds
`Price`, `Dependency`, `Activated`, `Status`, `LockedReason`, `DisplayName`
and `Order` values, plus `ZoneMarkers` (floor, lock overlay, and name/price
billboards). The Worker centre additionally requires the whole first dropper
row (`FIRST_DROPPER_COUNT = 5`, see section 2.12). The player's highest
unlocked centre is mirrored to the `CentreLevel` attribute and saved.

| Centre | Contents |
| --- | --- |
| Worker | Hiring Kiosk workers, WorkerSpeedUpgrade, Worker Notes & Gifts station (2.13) |
| Home | Structure sequence pad (2.15) |
| Avatar | Treadmill, Coil, Knockback Plank, Throwable Ball stations (2.18) |
| Orb | Empty `Upgrades` folder — planned |
| Pet | Empty `Upgrades` folder — planned |

The Orb and Pet centres can be unlocked but contain nothing yet. The commit
message on `767b4e8` (PR #16) states the plan: "work on the orb centre … then
work on pet centre, and then work on actual pets."

**Prices in the plot files.** Every centre costs 5 Cash, every Home structure
costs 1, and the Coil costs 1. These are the same on all ten plots (checked
with rbxmk on 2026-10-08), but they look like test values. Confirm before
release (see TODO.md).

### 2.15 Home Centre Structures and Plot Walls

**StructureSequenceService** replaced the old one-pad-per-structure model.
Each plot has a single pad, `Centre02_Home/StructureBuyPad`, that sells the
structures in a fixed order: Walls → Glass → Laser Door → Roof → Ceiling
Lights. The pad is driven by `Touched` on the server; the client never sends a
purchase request. The service writes a `CurrentStructure` attribute to the
pad, which the client-side **PreviewController** reads to float an emoji
preview of the next structure above it.

The per-slot `Slot_*/BuyPad` objects still exist because their `Activated`
BoolValues are the paths TycoonProgressService saves. Their
`StructureBuyPadScript`s are saved **Disabled** in the plot files. Those
disabled scripts are the only code that requires `StructurePurchaseService`,
so that module is dormant (see section 4).

**PlotWallCollisionService** keeps each plot's `PerimeterWall` non-collidable
(and untouchable/unqueryable) until the plot's
`Centre02_Home/StructureSlots/Slot_Walls/BuyPad/Activated` is true, so empty,
unowned, and pre-purchase plots stay walkable.

### 2.16 Bank and Gems

A second currency, **Gems**, was added in PR #15. DataSaveScript creates a
`GemData` folder on each player with two IntValues, `Gems` (carried) and
`BankedGems` (safe), and saves both.

**BankZoneHandler** (server) polls every 0.25s for living players standing
inside `Workspace.MiddleShops.BankStructure.BankZone`. A player carrying at
least one Gem who stays in the zone for 5 seconds has all carried Gems moved
into `BankedGems`, with no yield between the subtraction and the addition.
The countdown is mirrored on the `BankDepositSecondsLeft` player attribute,
and `BankDepositEvent` fires the result to the client. The client never
requests a deposit. **BankFeedbackClient** shows the countdown and a toast,
in its own code-built ScreenGui.

Known gaps:
- **Nothing awards Gems yet.** `Gems` is only ever written by DataSaveScript
  (load) and BankZoneHandler (deposit). The comment beside it says "Earned
  through gameplay, not yet safe", but no earning mechanic exists. It is also
  not documented what "not yet safe" protects against (e.g. losing carried
  Gems on death), and nothing implements such a loss.
- **Two parts are named `BankZone`** inside `BankStructure.rbxm`.
  BankZoneHandler uses `WaitForChild("BankZone")`, which returns whichever one
  it finds first, so only one of the two zones is guaranteed to work.
- PR #15 removed `BankTransactionHandler` and a `BankTestScript`, which
  existed briefly before this design.

### 2.17 Voiceline Station and Worker Count Display

**VoicelineStationService** manages a `VoicelineStation` model at each plot's
root. It is hidden until the plot's first worker (`WorkerActivations/Worker1`)
is hired, then shows as a 0.6-transparency ghost with a buy pad (2,500 Cash).
Once bought, interacting opens a menu via `VoicelineMenuEvent`, and
**VoicelineMenuClient** plays local-only previews from
`ReplicatedStorage.VoicelineCatalog` (currently three worker voicelines).
Station visuals come from `ServerStorage.Modules.VoicelineStationTheme` and
`VoicelineBuyPadLayout`.

**WorkerCountDisplayService** adds a billboard inside each HiringKiosk showing
saved worker progress. It stays hidden until Worker1 is hired.

### 2.18 Avatar Centre: Movement Upgrades and PvP Weapons

All four stations live under `Centre03_Avatar/Upgrades`. Each one is only
purchasable by the plot owner once `Centre03_Avatar` is activated. Each saves
through its own plot-relative `Activated` BoolValue (so TycoonProgressService
covers it), and each uses the shared PlotTheme / PurchaseEffect /
PurchaseSound modules.

| Station | Service | Price | Reward |
| --- | --- | --- | --- |
| SpeedUpgradeTreadmill | SpeedUpgradeTreadmillService | 2,500 | `SprintSpeedMultiplier` = 1.5 on the owner (Shift sprint) |
| CoilStation | CoilStationService | 1 | `PlayerJumpUpgradeMultiplier`, a permanent +20% jump height; no Tool. Removes any legacy `Coil` Tool. |
| KnockbackPlankStation | KnockbackPlankService | 10 | `KnockbackPlank` Tool (melee) |
| ThrowableBallStation | ThrowableBallStationService | 10 | `ThrowableBall` Tool (projectile) |

The treadmill also has an owner-only ghost preview,
**TreadmillGhostPreview**, from `ReplicatedStorage.Ghosts`.

**Weapons and combat.** Both weapon Tools are granted into the Backpack *and*
StarterGear, so they survive respawn, and they are re-granted from the saved
station state after `DataLoaded` and on every respawn. The client only
requests an action (`SwingEvent` / `ThrowEvent`); the server picks and
validates targets.
- **CombatDamageService** (ModuleScript) is the shared damage path:
  `ValidateTarget` only accepts *another player's* living character that has
  no ForceField, and `ApplyHit` applies damage, knockback, and a 1.25s
  ragdoll. This makes both weapons PvP-only.
- **ThrowableBallCombatService** simulates the thrown ball on the server
  (speed, gravity, radius, lifetime, max distance, cooldown).
  `ReplicatedStorage.ThrowableBallConfig` defines only Level 1 (10 damage,
  1.2s cooldown).
- KnockbackPlankService keeps its own copies of the ragdoll and knockback
  constants alongside CombatDamageService's.

**ToolInventoryClient** replaces Roblox's default Backpack UI with a custom
10-slot hotbar (number keys 1–0) for owned tools. If it can't disable the
default UI within about 4 seconds it leaves the default UI in place, and it
restores the default UI if the script is destroyed. It is presentation only.

---

## 3. Key Architectural Decisions

1. **Server-authoritative economy:** All cash transactions happen server-side. leaderstats.Cash is the single source of truth. Clients only see visual effects.
2. **Plot-based ownership:** Plots P1–P10 use Owner/OwnerName attributes. First-come-first-served assignment.
3. **Sequential slot unlocking:** Dependency attributes create purchase chains. Visual states (GHOST/HIDDEN/PURCHASED) communicate availability.
4. **BoolValue "Activated" pattern:** Universal flag across all purchasable slots to mark completion. Checked by section completion, worker spawners, and unlock controllers.
5. **RemoteEvent client-effects pattern:** Server fires events to specific players for sounds/particles. Client scripts handle rendering only.
6. **Music system is fully client-side:** Uses BindableEvents (not RemoteEvents). No server involvement. Third-party asset that self-deploys via loader script. MainHUD integrates with it rather than duplicating mute state.
7. **DataStore versioning:** Key "PlayerCashData_v3" — versioned for future schema migrations. Bumping the suffix starts everyone with a clean save and leaves the previous store untouched for rollback (v2 → v3 happened on 2026-10-08).
8. **UI styling system:** MainHUD's look comes from the `UITheme` modules (decision 18), not from the StyleSheet + BaseStyleSheet in ReplicatedStorage.Design. Those still exist but are excluded from sync by `globIgnorePaths` and are unused.
9. **Worker AI via Humanoid:MoveTo():** Simple pathfinding to nearest cash ball. Stuck detection with position reset.
10. **Player-owned plot themes:** Cosmetic accent membership is persistent CollectionService metadata; clients request a color, while the server resolves ownership, applies it, and saves it per player.
11. **Shared, pluggable shop UI:** ShopRowBuilder builds every shop-style panel's rows (main Shop, every MiddleShops panel) from the same code, with the purchase flow (Robux vs in-game Cash) swapped via an optional callback rather than duplicated per shop. PanelManager gives every panel the same single-panel-exclusive open/close behavior without each script needing its own copy of that logic.
12. **Config-driven shop content:** Every shop's items live in a small ReplicatedStorage ModuleScript (id/name/cost-or-productId/icon). Adding an item is a table edit; adding a whole new NPC shop is one config module + one panel entry in MainHUDBuilder + one entry in MiddleShopsController's SHOP_DEFINITIONS + the config's name in MiddleShopPurchaseHandler's ALLOWED_CONFIG_NAMES.
13. **Config-driven onboarding:** The first-time tutorial's step list is one ReplicatedStorage ModuleScript (TutorialConfig), and each step describes its target and its completion condition as a `{root, path}` spec resolved at runtime rather than as a hardcoded Instance reference. Both the client state machine and the server's persistence drive themselves off that one list, so adding, reordering, or removing a step is a table edit. Same shape as the shop configs (decision 12).
14. **Tutorial state resolved from a tri-state DataStore result:** GetAsync collapses "brand-new player" and "load failed" into the same empty result, so TutorialProgressService takes the success flag separately and resolves failure FIRST, always to "already completed". A failed load must never look like a new player, or returning players replay onboarding over their real save. See section 2.12.
15. **Tutorial UI lives outside MainHUD:** TutorialGui is its own ScreenGui with `ResetOnSpawn = false`, rather than more frames inside MainHUD (which was still an .rbxm at the time). That keeps the controller and its connections alive across respawns, and keeps every part of the feature as loose `.luau` files that sync cleanly through Rojo instead of being buried in a binary model file.
16. **Shared UI utility modules over per-button duplication:** ButtonHoverEffect and Tooltip both follow the same pattern -- one shared module, `Module.apply(button, ...)` / `Module.attach(button, ...)`, rather than copy-pasting tween/event-wiring code per button.
17. **Daily Worker Gifts cooldown reuses the tutorial's tri-state DataStore pattern:** WorkerGiftCooldownService resolves failure first (never available) exactly like TutorialProgressService (decision 14), so a transient DataStore failure can never be read as "no cooldown active." Countdown UI (world billboard + claim toast) is driven off the persisted server timestamp, not a free-running client clock, so it can't drift or be reset by rejoining. See section 2.13.
18. **Swappable HUD theme with a sandbox copy:** every MainHUD visual value lives in a theme table, and `UITheme` selects which table is active. `UITheme_Prototype` is where new looks are tried; approved changes are copied into `UITheme_Production`. Both files are kept, with matching key sets. See section 2.8.
19. **Plots are reset to blank when their owner leaves:** PlotAssignmentScript snapshots the departing player's progress first, then resets every purchase, restores each plot script's original enabled state, and destroys that plot's loose balls/crates before releasing ownership. The next player always gets a clean plot. See section 2.1.
20. **Avatar weapons are server-authoritative PvP:** the client only requests a swing or throw. The server chooses and validates targets through CombatDamageService, and only other players' unshielded characters can be hit. See section 2.18.

---

## 4. Known Issues & TODOs

The actionable, prioritized list lives in [`TODO.md`](TODO.md). This section
keeps the technical detail behind each item. Items are grouped by how sure we
are about them.

### 4.1 Confirmed gaps (verified in code)

- **ShopConfig & CashPackConfig productIds:** all set to 0, and there is no `ProcessReceipt` handler anywhere in `src/`. Nothing can be bought with Robux yet; Buy warns instead of prompting.
- **Nothing awards Gems:** the Bank works, but `Gems` is never incremented by any gameplay script (section 2.16).
- **Creature Shop Backpack item is not persisted:** it is cloned into the Backpack only, so it is lost on respawn and on rejoin. The PurchasedItems counters *are* saved.
- **Creature Shop items:** all 4 tiers grant the same placeholder visual (CreatureBall_Slimey mesh) and need real per-tier models.
- **Ball and Gear Shop items:** only increment the PurchasedItems counter; no physical item is granted. GearShopConfig's items themselves are placeholder content, not just their prices.
- **MiddleShops item prices:** placeholder Cash costs in CreatureShopConfig/BallShopConfig/GearShopConfig (and the dormant TradingPost/Vault/UpgradeShop configs).
- **Very low in-plot prices:** centres cost 5, Home structures 1, the Coil 1, and the Knockback Plank and Throwable Ball 10 (identical on all ten plots). They look like test values (section 2.14).
- **PetsPanel and InventoryPanel:** placeholders. The Pets panel shows "Soon" pills; the Inventory panel is empty.
- **Orb and Pet centres:** unlockable but empty (section 2.14).
- **Daily Worker Gifts reward is a placeholder:** `PLACEHOLDER_GIFT_REWARD_CASH = 150` in WorkerNotesGiftsStationService. Swapping in the real reward is a one-line change.
- **Daily Worker Gifts opening animation:** not built, and it's still undecided whether to build it. The claim flow is complete and functional without it (section 2.13).
- **Tutorial has no mid-run skip:** the only exits are the welcome panel's Skip button or completing all nine steps. Because an externally dismissed welcome card auto-starts the tutorial (section 2.12), a player who opened a shop instead of choosing can end up in a tutorial they didn't pick, with no way out. Low impact, since StepPanel is a non-modal banner and the steps are normal progression, but a small close control on StepPanel would remove it.
- **Tutorial step targets assume the standard plot layout:** a step whose path can't be resolved is warned about and skipped, not retried, so a plot layout change silently shortens the tutorial rather than erroring.
- **TeleportToTycoonEvent:** created at runtime by PlotAssignmentScript rather than existing as a static RemoteEvent. It works but is fragile; consider making it a normal `.model.json`.

### 4.2 Needs investigation

- **Duplicate `BankZone` parts** in `BankStructure.rbxm`. BankZoneHandler uses whichever `WaitForChild` returns first, so only one zone is guaranteed to deposit (section 2.16).
- **Unverified font rendering:** whether `Enum.Font.Gotham*` actually renders as Montserrat in this Studio build (section 2.8).
- **Tooltip feel:** wired up and structurally verified, but positioning and timing have never been confirmed by eye in a live session.
- **Possibly unused assets:** no script reference was found (loose `.luau` files, plus a scan of P1, Hub, StatsHUD, StarterCharacterScripts and TycoonDropper with rbxmk) for `PurchaseEffectModule_FreshTest6`, `BouncePlatformTheme`, `Ghosts/JumpUpgrade_ArrowBouncePlatform_Ghost`, or `ServerStorage/Machines/JumpUpgrade_ArrowBouncePlatform`. The jump assets look superseded by the Coil station. Other `.rbxm` files (e.g. MusicGUI, MiddleShops) were not scanned.
- **Dormant `StructurePurchaseService`:** only the saved-Disabled per-slot `StructureBuyPadScript`s require it (section 2.15). It could be removed together with those scripts, but that means editing all ten plot `.rbxm` files.
- **Top-level `BallShop`, `CreatureShop`, `GearShop`, `Bank` Parts in Workspace and `Roblox_Coil`:** added or changed in PR #15 and commit `c57c46c`. No script references them by name and their purpose isn't documented. Ask their authors.
- **Empty `ScreenGui.rbxm`** in StarterGui: contains nothing; purpose unknown.
- **Studio-only Workspace items:** earlier versions of this doc listed `Irwin Vernon`, `Tycoon Wall` and `Tycoon Dropper` models. They are not in `src/`, so whether they still exist can only be checked in the Studio place. `Sketchfab_Scene` was deleted in PR #16.
- **Music system playlist switching:** MusicGUI's own README (v1.2.0 changelog) notes "CURRENTLY SWITCHING PLAYLISTS NEEDS TO BE WORKED OUT IN THE NEXT UPDATE".
- **Music system SoundInfo module:** exists but appears unused, likely a generic utility from the vendored asset.
- **Plot 10 / avatar upgrade alignment:** the PR #16 commit message reports avatar-upgrade buy buttons and sizing differing from Plot 1 on some plots. That PR shipped fixes, but nobody has recorded whether all of them are resolved. Station prices do match across all ten plots.

### 4.3 Out-of-date code comments

These are documentation-only mismatches inside source files. They are listed
here because doc passes must not edit code:
- `UISoundConfig/init.luau`'s comment block says `hoverSoundId` is an empty placeholder, but both hover and click IDs are set to real assets.
- `MiddleShopPurchaseHandler`'s header describes "the 5 MiddleShops NPCs" and lists Trading Post/Vault/Upgrade among live shops.

### 4.4 Environment notes

- **`upload_asset` / `get_asset_thumbnail` / `search_assets` MCP tools:** all fail or hang due to a missing ROBLOX_OPEN_CLOUD_API_KEY in this environment. Don't rely on them; see the Icon Assets note in section 2.8 for the working manual-handoff workflow.

### 4.5 Resolved since the previous version of this doc

- Row-stroke clipping fix (2px `itemList` padding) and the full textured restyle were ported into `UITheme_Production` (PR #18); both theme files are now identical.
- `WorldShopConfig`, `WorldShopNPCScript`, `WorldShopPanel.rbxm` and `OpenWorldShopEvent` were deleted (PR #17).
- `Sketchfab_Scene` was deleted (PR #16).
- Plots now fully reset when their owner leaves (PR #16).
- UI hover/click sound IDs are set to real assets (earlier versions of this list said they were empty).
- PurchasedItems counters are saved (earlier versions said they weren't).

---

## 5. Current State Summary

Working today:
- Players join → assigned a plot → buy droppers → buy conveyors → unlock centres → hire workers → buy structures and Avatar upgrades → upgrade machines → collect cash. Plots are reset to blank when their owner leaves.
- Data persists across sessions under `PlayerCashData_v3`: Cash, Gems, plot progression (centres, structures, stations, workers), upgrade level, PurchasedItems counters, plot color, tutorial progress, and the Daily Worker Gifts cooldown. Saving uses a 60s autosave with retries and is disabled for a session whose load failed.
- All plot machine/structure/wall/glass accents and HiringKiosks respond to server-authoritative player color choices.
- Workers auto-collect cash balls; a kiosk billboard shows worker progress.
- Visual/audio feedback for purchases, upgrades, and section completions, including working UI hover/click sounds.
- Music plays in the background with GUI controls, and MainHUD's Settings panel controls it.
- Three NPC shops (Creature, Ball, Gear) work end-to-end with in-game Cash and server-side validation; Creature Shop purchases grant a placeholder Backpack item.
- A Bank deposit zone moves carried Gems into a saved bank balance (but nothing awards Gems yet).
- The Home Centre sells its five structures through one sequenced pad, and buying the walls enables perimeter collision.
- The Avatar Centre sells a sprint treadmill, a jump Coil, and two server-authoritative PvP weapons with knockback and ragdoll, shown in a custom tool hotbar.
- A Voiceline Station (unlocked by hiring the first worker) plays worker voiceline previews.
- MainHUD is built in code with a swappable theme. Every CashHUDGroup button has an image icon (except "+") and a hover tooltip.
- First-time players get a nine-step guided tutorial with 3D arrow markers; progress saves per step (section 2.12).
- Daily Worker Gifts: a 24-hour Cash claim with a server-enforced cooldown that survives rejoin (section 2.13).

Not yet built:
- Orb centre, Pet centre, and the pets system (Pets panel is a placeholder)
- Inventory panel content
- A way to earn Gems
- Real Robux monetization (product IDs and receipt processing)
- Real per-item assets for the MiddleShops, and persistence of granted shop items
- A game loop or win condition beyond tycoon progression
- A mid-tutorial skip control
- Admin tools or moderation systems
- The Daily Worker Gifts real reward, and possibly its opening animation

---

## 6. Next Steps

Moved to [`TODO.md`](TODO.md), which is the single place outstanding work is
tracked. Keep this file describing how things *are*; put what still needs
doing in TODO.md.

---

## 7. Important Notes for Future Sessions

- **Editing the music script:** Edit Workspace.MusicGUI.MusicGUI_Loader.StarterGUI.MusicPlaylistGUI.MusicPlaylistGUIScript (the template). Do NOT edit the runtime copy in StarterGui.MusicPlaylistGUI or Players.<n>.PlayerGui — those are deployed clones.
- **MusicGUI_Loader** auto-deploys at runtime. If you manually move folders to their proper services, the loader is no longer needed and can be deleted.
- **All server scripts** are in ServerScriptService (game logic) and ServerStorage.WorkerTemplates (worker AI). No server scripts in Workspace — all Workspace scripts are per-plot clones of template scripts.
- **DataStore key** is PlayerCashData_v3 — if you change the schema, bump the version. Bumping wipes every player's progress (the old store is only kept for rollback), so treat it as a deliberate, announced decision.
- **Changing the HUD's look:** edit `UITheme_Prototype`, test, then copy the approved blocks into `UITheme_Production` so the two stay key-identical. Don't put visual values in MainHUDBuilder or the controllers, and don't delete either theme file. See section 2.8.
- **Searching for script references:** scripts stored inside `.rbxm` files (every plot has ~79) are invisible to a text search of `src/`. To check whether something is really unused, also scan the relevant `.rbxm` files with an rbxmk script. In rbxmk scripts without a class database, `Instance:IsA()` does not work; compare `ClassName` instead (`"Script"`, `"LocalScript"`, `"ModuleScript"`), and read script text from `.Source`. Only *read* `.rbxm` files with rbxmk, never write them (see the FontFace warning in section 2.8).
- **Plot models** P1–P10 are identical in structure. Changes to plot structure should be applied to all 10.
- **Dependency attribute** on slots controls unlock order — modifying this chain affects gameplay flow.
- **CorePackages is empty** — there is no AppMusicPlayer package despite earlier references. The only music system is the third-party MusicGUI.
- **Adding a new MiddleShops-style shop:** create a ReplicatedStorage config ModuleScript (see CreatureShopConfig for the shape), add a panel by adding one entry to MainHUDBuilder's `MIDDLE_SHOPS` list (built by its buildMiddleShopPanel helper, styled by `Theme.middleShopPanel`), add one entry to MiddleShopsController's SHOP_DEFINITIONS table whose `panelKey` matches (panel and config must exist first — see the caution in section 2.4b), and add the config name to MiddleShopPurchaseHandler's `ALLOWED_CONFIG_NAMES`. No other changes are needed to ShopRowBuilder, PanelManager, or MiddleShopPurchaseHandler unless the new shop needs a different purchase flow (e.g. Robux instead of Cash) or its own item-granting logic (add another `if configName == "..."` branch in MiddleShopPurchaseHandler, following the Creature Shop example).
- **Testing Cash-balance-dependent logic:** this economy's passive income is fast (tens of thousands/sec on active accounts). Don't set Cash low from a client script and wait before checking -- that write doesn't even replicate to the server's authoritative value. Use eval_server_runtime with a zero-yield check for real insufficient-funds testing.
- **Adding hover tooltips to a new button:** `require(ReplicatedStorage.Tooltip).attach(button, "Label Text")` -- that's it, no per-button UI to build.
- **Fixing a transparent-PNG-that-isn't-actually-transparent icon:** check alpha channel mode first (PIL: `img.mode`). If it's RGB with no alpha, don't assume a simple color threshold will work -- check whether the icon's own fill color is close to the background color first (sample a few pixels). If they're close, use the texture-variance-per-connected-region method described in section 2.8's Icon Assets note, not a plain threshold.
- **Adding or reordering a tutorial step:** edit the TutorialConfig table, nothing else. Each entry needs `id`, `title`, `dialog`, a `target` `{root, path}` (something with a world position -- Model or BasePart) and a `completion` `{type, root, path}` (`ValueTrue` for a BoolValue, `ValueIncreased` for an Int/NumberValue). A step whose path doesn't resolve is warned about and skipped rather than hanging the sequence -- so if a step silently never appears, check the path against the real plot hierarchy first.
- **Testing the tutorial without a fresh account:** set the Workspace attribute `StudioResetTutorial` to true in Edit mode (Studio-only, ignored when published) to make every joining player eligible again, or reset one player mid-session from the command bar with `require(game.ServerScriptService.TutorialProgressService).Reset(player)`. The tutorial's Player attributes (`TutorialEligible`, `TutorialStepIndex`, ...) only show up in the Properties window while Play-testing, under the collapsed "Attributes" section.
- **Don't conflate unlocking the worker centre with hiring a worker.** `CentreSlots/Centre01_Worker/Activated` is the zone unlock (CentreZoneService); `CentreSlots/Centre01_Worker/WorkerActivations/Worker1` is an actual hired worker (WorkerSpawnerController at `Plot/HiringKiosk`). They're separate purchases. WorkerSpawnerController and the P1–P10 plots are Studio-native and not in the Rojo source tree, so section 2.3 is the best available description of them.
- **Roblox asset upload/search tools are broken in this environment** (missing API key) — go straight to the manual Asset-Manager-import + asset-ID handoff workflow, don't waste a turn retrying `upload_asset` first.
- **Testing the Daily Worker Gifts cooldown without waiting 24h:** run `require(game.ServerScriptService.WorkerGiftCooldownService).Reset(player)` from the Studio command bar (Server context) while play-testing -- resets just the gift timestamp, leaves Cash/plot color/tutorial progress untouched. Manually poking `player:SetAttribute("LastWorkerGiftClaim", ...)` and/or toggling `DataLoadFailed` is useful for exercising the boundary/guard cases directly. See section 2.13.

---

This document reflects the state of the game as of the current session. It should be updated whenever major systems are added, changed, or removed.
