# Ball Tycoon

A multiplayer conveyor-based production tycoon built for Roblox with [Rojo](https://rojo.space/). Players claim a plot, drop and route balls through droppers and conveyors, hire workers, upgrade machines, and spend earned Cash at five in-world NPC shops.

## Status

Early-to-mid development. The core tycoon loop (claim a plot → buy droppers → buy conveyors → buy structures → hire workers → upgrade machines → collect cash) is functional end-to-end, including server-authoritative saving/loading. Robux monetization is scaffolded but not yet wired to real Developer Products. See [Known Issues & Roadmap](#known-issues--roadmap) below.

## Gameplay Overview

- **10 plots (P1–P10):** first-come, first-served assignment per player, with ownership tracked via instance attributes.
- **Droppers & conveyors:** droppers spawn cash balls; conveyors drop crates that break into more cash balls. Slots unlock sequentially via a `Dependency` attribute chain (ghost → purchasable → purchased).
- **Workers:** hired at purchase pads across six stages per plot; they path to and collect nearby cash balls automatically.
- **Machine upgrades:** five levels that scale ball value and cost.
- **Plot themes:** players choose an accent color that recolors hundreds of tagged cosmetic parts per plot, resolved and rate-limited server-side.
- **NPC shops (MiddleShops):** five walk-up shops — Creature, Ball, Trading Post, Vault, and Upgrade — each server-validated and paid for with in-game Cash.
- **Persistence:** Cash, plot progression, worker hires, machine upgrade levels, structure purchases, and plot color are saved per player via DataStores and restored on rejoin.

## Tech Stack

- **Engine:** Roblox (Luau)
- **Tooling:** [Rojo](https://rojo.space/) for syncing the filesystem to Roblox Studio, managed via [Rokit](https://github.com/rojo-rbx/rokit)
- **Architecture:** Server-authoritative economy — all Cash transactions and progression state live on the server (`leaderstats.Cash` is the single source of truth); clients only render visual/audio feedback via RemoteEvents

## Project Structure

```
Ball-Tycoon/
├── default.project.json       # Rojo project definition (maps src/ into the Roblox DataModel)
├── rokit.toml                 # Toolchain manifest (pins the Rojo version)
├── backups/                   # Local .rbxl place file backups (git-ignored)
└── src/
    ├── ReplicatedStorage/      # Shared config modules, UI utilities, RemoteEvents, models
    ├── ServerScriptService/    # Server-side game logic (plots, economy, shops, workers, saving)
    ├── ServerStorage/          # Worker templates, placeholder items, saved light designs
    ├── StarterGui/             # MainHUD, StatsHUD, and shop panel UI
    ├── StarterPlayer/          # Client-side character and player scripts
    └── Workspace/              # Plots (P1–P10), hub, shop structures, terrain, and other place geometry
```

For a deep, section-by-section breakdown of every system (plot/economy flow, slot unlocking, worker AI, purchase effects, the NPC shop system, plot theming, UI architecture, monetization, and known architectural decisions), see [`src/ReplicatedStorage/PROJECT_STATE.luau`](src/ReplicatedStorage/PROJECT_STATE.luau) — it's a living design document kept in sync with the codebase.

## Getting Started

### Prerequisites

- [Roblox Studio](https://create.roblox.com/)
- [Rokit](https://github.com/rojo-rbx/rokit) (toolchain manager) — installs the pinned Rojo version automatically

### Setup

1. Install the pinned tools with Rokit:
   ```bash
   rokit install
   ```
2. Start the Rojo server from the project root:
   ```bash
   rojo serve
   ```
3. In Roblox Studio, install/open the [Rojo plugin](https://create.roblox.com/store/asset/13916111004/Rojo) and click **Connect** to sync `src/` into a running place.
4. Play-test in Studio (Play or Play Here) to exercise the tycoon loop locally.

### Building a place file

To produce a standalone `.rbxl` without a live Studio connection:

```bash
rojo build -o Ball-Tycoon.rbxl
```

## Development Notes

- **Config-driven shops:** each NPC shop's items live in a small `ReplicatedStorage` ModuleScript (`BallShopConfig`, `CreatureShopConfig`, `TradingPostConfig`, `VaultConfig`, `UpgradeShopConfig`). Adding an item is a table edit; adding a whole new shop is one config module, one UI panel, and one entry in `MiddleShopsController`'s shop definitions table.
- **Server validates everything:** `MiddleShopPurchaseHandler` re-looks-up item costs from its own copy of the config rather than trusting the client, and whitelists which config modules it will load.
- **DataStore key:** `PlayerCashData_v2` — bump the version suffix if you change the save schema.
- **Plot symmetry:** P1–P10 are structurally identical; any change to plot layout should be applied to all ten.

## Known Issues & Roadmap

- Robux products (`ShopConfig`, `CashPackConfig`) use placeholder product IDs and are not yet purchasable.
- MiddleShops purchases (Backpack items, purchase counters) are not yet persisted across sessions.
- Creature Shop items all currently grant the same placeholder mesh; other shops have no physical item yet.
- Pets system is UI-only ("Soon" placeholders).
- UI hover/click sound IDs are unset.
- No win condition or prestige/rebirth system beyond tycoon progression yet.

See section 4 of `PROJECT_STATE.luau` for the full, current list.


