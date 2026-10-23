# Ball Tycoon

A multiplayer conveyor-based production tycoon built for Roblox with [Rojo](https://rojo.space/). Players claim a plot, drop and route balls through droppers and conveyors, hire workers, upgrade machines, unlock themed centres on their plot, and spend earned Cash at in-world NPC shops.

## Status

Early-to-mid development. The core tycoon loop (claim a plot → buy droppers → buy conveyors → unlock centres → hire workers → upgrade machines → collect cash) is functional end-to-end, including server-authoritative saving/loading. The Worker, Home, and Avatar centres are built; the Orb and Pet centres exist on every plot but have no content yet. Robux monetization is scaffolded but not yet wired to real Developer Products. See [Known Issues](#known-issues) below and [`TODO.md`](TODO.md) for outstanding work.

## Gameplay Overview

- **10 plots (P1–P10):** first-come, first-served assignment per player, with ownership tracked via instance attributes. When a player leaves, their progress is saved and the plot is reset to a blank state for the next player.
- **Droppers & conveyors:** droppers spawn cash balls; conveyors drop crates that break into more cash balls. Slots unlock sequentially via a `Dependency` attribute chain (ghost → purchasable → purchased).
- **Centres:** each plot has five centres that unlock in order:
  - **Worker** — hire workers at the Hiring Kiosk, plus a worker speed upgrade and a once-per-day Worker Gifts Cash claim.
  - **Home** — a single pad that sells structures in a fixed order (walls, glass, laser door, roof, ceiling lights). Buying the walls turns on collision for the plot's perimeter wall.
  - **Avatar** — character upgrades: a Speed Treadmill (faster sprint), a Coil station (higher jump), and two PvP weapons, the Knockback Plank and the Throwable Ball.
  - **Orb** and **Pet** — placeholders for upcoming content.
- **Workers:** hired across six stages per plot; they path to and collect nearby cash balls automatically.
- **Machine upgrades:** five levels that scale ball value and cost.
- **Plot themes:** players choose an accent color that recolors hundreds of tagged cosmetic parts per plot, resolved and rate-limited server-side.
- **NPC shops (MiddleShops):** three walk-up shops (Creature, Ball, and Gear), each server-validated and paid for with in-game Cash.
- **Bank:** a deposit zone in the MiddleShops area. Standing in it for 5 seconds banks the Gems you are carrying. (Nothing awards Gems yet, see [Known Issues](#known-issues).)
- **First-time tutorial:** a nine-step guided onboarding with 3D arrow markers, shown once per player.
- **Persistence:** Cash, Gems, plot progression, worker hires, machine upgrade levels, centre and structure purchases, shop purchase counters, plot color, tutorial progress, and the Worker Gifts cooldown are saved per player via DataStores and restored on rejoin.

## Tech Stack

- **Engine:** Roblox (Luau)
- **Tooling:** [Rojo](https://rojo.space/) for syncing the filesystem to Roblox Studio, plus [rbxmk](https://github.com/Anaminus/rbxmk) for reading `.rbxm` files from scripts. Both are pinned and installed via [Rokit](https://github.com/rojo-rbx/rokit).
- **Architecture:** Server-authoritative economy. All Cash and Gem transactions and all progression state live on the server (`leaderstats.Cash` is the single source of truth for Cash). Clients only render visual/audio feedback via RemoteEvents.

## Project Structure

```
Ball-Tycoon/
├── default.project.json       # Rojo project definition (maps src/ into the Roblox DataModel)
├── local.project.json         # Alternate Rojo project file (not used by the commands below)
├── rokit.toml                 # Toolchain manifest (pins Rojo and rbxmk)
├── README.md                  # This file
├── CONTRIBUTING.md            # Full contributor guide: setup, Rojo workflow, git/PR rules
├── GIT_WORKFLOW.md            # One-page git cheat sheet
├── PROJECT_STATE.md           # Detailed, living architecture and system reference
├── TODO.md                    # Outstanding work, open questions, and future ideas
├── backups/                   # Local .rbxl place file backups (git-ignored)
└── src/
    ├── ReplicatedStorage/      # Shared config modules, UI theme and utilities, RemoteEvents, models
    ├── ServerScriptService/    # Server-side game logic (plots, economy, centres, shops, combat, saving)
    ├── ServerStorage/          # Worker templates, machine and station templates, tools, legacy assets
    ├── StarterGui/             # MainHUD (built in code), StatsHUD, TutorialGui
    ├── StarterPlayer/          # Client-side character and player scripts
    └── Workspace/              # Plots (P1–P10), hub, shop structures, and other place geometry
```

For a section-by-section breakdown of every system (plot/economy flow, slot unlocking, centres, worker AI, purchase effects, the NPC shops and bank, combat, plot theming, the UI and its theme system, monetization, and key architectural decisions), see [`PROJECT_STATE.md`](PROJECT_STATE.md). It's a living design document kept in sync with the codebase.

## Getting Started

### Prerequisites

- [Roblox Studio](https://create.roblox.com/)
- [Rokit](https://github.com/rojo-rbx/rokit) (toolchain manager), which installs the pinned Rojo and rbxmk versions automatically

### Setup

1. Install the pinned tools with Rokit:
   ```bash
   rokit install
   ```
2. Start the Rojo server from the project root:
   ```bash
   rojo serve
   ```
3. In Roblox Studio, install/open the [Rojo plugin](https://create.roblox.com/store/asset/13916111004/Rojo) and click **Connect** to sync `src/` into a running place. `default.project.json` only allows syncing into the place IDs listed under `servePlaceIds`. Use the team's development place (see [CONTRIBUTING.md §11](CONTRIBUTING.md#11-production-safety)).
4. Play-test in Studio (Play or Play Here) to exercise the tycoon loop locally.

### Optional: editor sourcemap

`sourcemap.json` is git-ignored and is regenerated by Rojo for editor tooling (e.g. Luau language servers). To keep it current while you work:

```bash
rojo sourcemap --output sourcemap.json --watch
```

### Building a place file

To produce a standalone `.rbxl` without a live Studio connection:

```bash
rojo build -o Ball-Tycoon.rbxl
```

## Development Notes

- **Config-driven shops:** each NPC shop's items live in a small `ReplicatedStorage` ModuleScript (`CreatureShopConfig`, `BallShopConfig`, `GearShopConfig`). Adding an item is a table edit. Adding a whole new shop takes one config module, one panel entry in `MainHUDBuilder`, one entry in `MiddleShopsController`'s `SHOP_DEFINITIONS` table, and adding the config's name to `MiddleShopPurchaseHandler`'s whitelist.
- **Server validates everything:** `MiddleShopPurchaseHandler` re-looks-up item costs from its own copy of the config rather than trusting the client, and whitelists which config modules it will load. Avatar-centre stations and weapons follow the same rule: the client only requests an action, and the server validates it.
- **The HUD is built in code:** `src/StarterGui/MainHUD/MainHUDBuilder.luau` constructs the whole HUD. Every visual value comes from a theme module. `UITheme.luau` selects between `UITheme_Prototype` (where new looks are tried) and `UITheme_Production` (the approved copy). See PROJECT_STATE §2.8.
- **DataStore key:** `PlayerCashData_v3`. Bump the version suffix if you change the save schema. Note that bumping it starts every player with a clean save.
- **Plot symmetry:** P1–P10 are structurally identical. Any change to plot layout should be applied to all ten.

## Known Issues

- Robux products (`ShopConfig`, `CashPackConfig`) use placeholder product IDs (`0`), and there is no `ProcessReceipt` handler, so nothing is purchasable with Robux yet.
- Nothing in the game awards Gems yet, so the Bank has nothing to deposit.
- Items granted into the Backpack by the Creature Shop are not saved and disappear on rejoin. (Purchase counters are saved.)
- Creature Shop items all grant the same placeholder mesh, and Gear Shop items are placeholder content.
- The Pets panel, Inventory panel, and the Orb and Pet centres are placeholders.

See [`TODO.md`](TODO.md) for the full, prioritized list and [`PROJECT_STATE.md` §4](PROJECT_STATE.md#4-known-issues--todos) for technical detail.
