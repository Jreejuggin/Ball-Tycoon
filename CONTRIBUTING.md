# Contributing to Ball Tycoon

Welcome! This document explains how the Ball Tycoon repository is organized and how to work on it day to day. It's written for teammates who are new to this project's Roblox + Rojo + Git workflow — no prior experience with Rojo is assumed.

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Prerequisites](#2-prerequisites)
3. [First-Time Setup](#3-first-time-setup)
4. [Project Structure](#4-project-structure)
5. [Rojo Development Workflow](#5-rojo-development-workflow)
6. [Git Branching Strategy](#6-git-branching-strategy)
7. [Daily Workflow](#7-daily-workflow)
8. [Pull Request Guidelines](#8-pull-request-guidelines)
9. [Merge Conflicts](#9-merge-conflicts)
10. [Roblox/Rojo-Specific Rules](#10-robloxrojo-specific-rules)
11. [Production Safety](#11-production-safety)
12. [Common Git Commands](#12-common-git-commands)
13. [Common Rojo Commands](#13-common-rojo-commands)
14. [Troubleshooting](#14-troubleshooting)
15. [Rules of Thumb](#15-rules-of-thumb)

---

## 1. Project Overview

Ball Tycoon is a multiplayer conveyor-based production tycoon built for Roblox. Players claim one of ten plots, route balls through droppers and conveyors, hire workers, upgrade machines, and spend earned Cash at in-world NPC shops. See [README.md](README.md) for the full gameplay overview and [`src/ReplicatedStorage/PROJECT_STATE.luau`](src/ReplicatedStorage/PROJECT_STATE.luau) for a detailed, living architecture document.

This repository is **the source-controlled version of the Roblox project**. The game was originally built directly in Roblox Studio and was migrated into this repo using Rojo's syncback feature (a one-time import, not a routine tool — see [Section 10](#10-robloxrojo-specific-rules)). From this point forward, the files under [`src/`](src) are the source of truth for all scripts, configs, and Rojo-managed instances.

The four pieces fit together like this:

- **GitHub** hosts the canonical history of the project and is where Pull Requests are reviewed and merged.
- **The local filesystem** (this cloned repo) is where you actually edit files — Luau scripts in a code editor like VS Code, JSON configs, etc.
- **Rojo** is the bridge: it watches the files under `src/` and, via the [`default.project.json`](default.project.json) mapping, syncs them live into a running Roblox Studio session.
- **Roblox Studio** is where you run and play-test the game. It should be treated as a "viewer/runner" for Rojo-managed code, not as the primary place to author scripts (see [Section 5](#5-rojo-development-workflow)).

In short: **edit on disk → Rojo syncs it → Studio reflects it → test in Studio → commit on disk → push to GitHub.**

## 2. Prerequisites

Before contributing, install:

- **[Git](https://git-scm.com/)** — for version control.
- **[GitHub access](https://github.com/Jreejuggin/Ball-Tycoon)** — you need to be added as a collaborator (or have fork/PR access) on the `Jreejuggin/Ball-Tycoon` repository.
- **[Roblox Studio](https://create.roblox.com/)** — for running and play-testing the game.
- **[Rokit](https://github.com/rojo-rbx/rokit)** — the toolchain manager this project uses to install and pin developer tools (currently just Rojo). Install Rokit itself following the instructions in its README; there's no repo-specific Rokit version to install first.
- **Rojo** — you do *not* need to install Rojo yourself. Rokit installs the exact pinned version (currently **`7.7.0`**, per [`rokit.toml`](rokit.toml)) for you.
- **[Rojo Studio plugin](https://create.roblox.com/store/asset/13916111004/Rojo)** — installed from the Roblox library into Studio. This is what lets Studio connect to your local `rojo serve` session.
- **A code editor** — VS Code is recommended for editing `.luau` files (syntax highlighting, and pairs well with the Rojo workflow described below). Nothing in the repo hard-requires VS Code specifically, but Rojo-managed scripts should be edited on disk rather than in Studio's built-in script editor (see [Section 5](#5-rojo-development-workflow)).

There is no `.luaurc`, linter config (e.g. Selene), or formatter config (e.g. StyLua) checked into the repo at this time. If the team wants to standardize linting/formatting, that should be proposed and added deliberately rather than assumed.

## 3. First-Time Setup

Run these from a terminal:

```bash
# 1. Clone the repository
git clone https://github.com/Jreejuggin/Ball-Tycoon.git

# 2. Enter the project directory
cd Ball-Tycoon

# 3. Install the pinned tools (currently just Rojo 7.7.0) with Rokit
rokit install

# 4. Verify the installation
rojo --version
# Expect: Rojo 7.7.0
```

What each step does:

1. **Clone** downloads the repo's full Git history to your machine.
2. **`cd Ball-Tycoon`** puts you in the project root — this matters because `rojo serve` and `rokit install` both look for `default.project.json` / `rokit.toml` in the current directory.
3. **`rokit install`** reads `rokit.toml` and downloads the exact Rojo version the project is pinned to, so everyone on the team is running the same Rojo. Rokit adds its shims to your `PATH`; if `rojo --version` isn't found afterward, make sure Rokit's bin directory (typically `~/.rokit/bin`) is on your `PATH` (Rokit's own install instructions cover this).
4. **`rojo --version`** confirms the tool actually resolved to the pinned version.

Then, to start developing:

```bash
# 5. Start the Rojo server from the project root
rojo serve
```

This starts a local server (by default at `localhost:34872`) that watches `src/` and serves the project tree defined in `default.project.json`.

6. **Connect Roblox Studio to the Rojo server.** Open Roblox Studio, open the Rojo plugin panel (installed in the Prerequisites step), and click **Connect** (it should find the locally running `rojo serve` automatically at the default port).

7. **Open the correct development Roblox experience.** Connect the Rojo plugin to a Studio session for the team's **development** place — not the live production Ball Tycoon experience (see [Section 11](#11-production-safety)). Which exact place/experience is the designated development environment is not recorded in this repository; confirm the place URL or place ID with the project maintainer before your first sync.

Once connected, the Studio Explorer should populate under `ReplicatedStorage`, `ServerScriptService`, `ServerStorage`, `StarterGui`, `StarterPlayer`, and `Workspace` with the contents of `src/`.

## 4. Project Structure

```
Ball-Tycoon/
├── default.project.json   # Rojo project definition — maps src/ into the Roblox DataModel
├── rokit.toml              # Toolchain manifest — pins the Rojo version (7.7.0)
├── .gitignore               # Ignores backups/ and .DS_Store
├── backups/                 # Local .rbxl place file backups — git-ignored, not synced by Rojo
└── src/
    ├── ReplicatedStorage/    # → game.ReplicatedStorage
    ├── ServerScriptService/  # → game.ServerScriptService
    ├── ServerStorage/        # → game.ServerStorage
    ├── StarterGui/           # → game.StarterGui
    ├── StarterPlayer/        # → game.StarterPlayer
    └── Workspace/            # → game.Workspace
```

`default.project.json` is what defines this mapping — each top-level key under `"tree"` corresponds to a Roblox service, and its `"$path"` points at the matching folder under `src/`. It also sets a handful of service-level properties (e.g. `StarterGui.ScreenOrientation`, several `StarterPlayer` character properties, and `Workspace` streaming/terrain settings) — see the file itself for the current values. If you need to change one of these DataModel-level properties, edit `default.project.json`; don't just change it in Studio and forget about it, or the change will be lost/overwritten on the next sync.

### What's in each service folder

- **`src/ReplicatedStorage/`** — Shared modules used by both client and server: shop configs (`BallShopConfig`, `CreatureShopConfig`, `TradingPostConfig`, `VaultConfig`, `UpgradeShopConfig`, plus Robux-based `ShopConfig`/`CashPackConfig`), UI helper modules (`ButtonHoverEffect`, `Tooltip`, `PanelManager`, `ShopRowBuilder`, `CashFormat`), RemoteEvents (as `.model.json` files, e.g. `MiddleShopPurchaseEvent.model.json`), shared models (`ConveyorCrate.rbxm`, `LaserDoorTemplate.rbxm`), and `PROJECT_STATE.luau` — the living design-doc module described in the README. Subfolders include `Design/` (UI stylesheets), `Ghosts/`, `ThemeRemotes/`, and `UISoundConfig/`.
- **`src/ServerScriptService/`** — Server-only game logic: plot assignment, the economy/purchase handlers, worker services, machine upgrades, and save/load logic (`DataSaveScript.server.luau`). This is server-authoritative code — see the README's note that `leaderstats.Cash` and related progression state live here, not on the client.
- **`src/ServerStorage/`** — Server-only asset storage: worker templates (`WorkerTemplates/`), machine models (`Machines/`), reusable prefabs (`Templates/`), tools (`Tools/`), saved lighting presets (`SavedLightDesigns/`), and `LegacyAssets/` (scripts/models preserved from before the migration — treat as historical reference, not an active development area, unless you know why you're touching it).
- **`src/StarterGui/`** — Client UI: `MainHUD.rbxm`, `StatsHUD.rbxm`, `WorldShopPanel.rbxm`, and the base `ScreenGui.rbxm`, stored as binary `.rbxm` models (see extensions note below).
- **`src/StarterPlayer/`** — `StarterCharacterScripts.rbxm` and `StarterPlayerScripts.rbxm`, each a binary model containing the client-side character/player script trees.
- **`src/Workspace/`** — Place geometry and world objects: the ten plots (`P1.rbxm`–`P10.rbxm`, structurally identical — see [Section 10](#10-robloxrojo-specific-rules)), the `Hub`, the five `MiddleShops/` NPC shop structures, terrain/baseplate/spawn/camera, and the vendored `MusicGUI/` asset (see below).

### File extensions you'll see

- **`.server.luau`** — a Script (runs only on the server). Example: `src/ServerScriptService/DataSaveScript.server.luau`.
- **`.client.luau`** — a LocalScript (runs only on the client). Example: `src/Workspace/MusicGUI/MusicGUI_Loader/StarterPlayer/StarterPlayerScripts/MusicChangeHandler/init.client.luau`.
- **`.luau`** (no `.server`/`.client` suffix) — a ModuleScript, e.g. `src/ReplicatedStorage/CashFormat.luau`, or in a couple of cases (`StructurePurchaseService.luau`, `TycoonProgressService.luau`) a plain Script without the suffix convention applied — check the corresponding `.meta.json` if one exists, since Rojo can override the inferred class there.
- **`.rbxm`** — a binary Roblox model file. Rojo syncs these as opaque instance trees; you cannot meaningfully diff their contents in a text-based code review, so treat changes to `.rbxm` files as "replace the whole object" rather than an editable diff. Most of `StarterGui/`, `StarterPlayer/`, and `Workspace/`'s geometry/UI is stored this way because it was migrated in via syncback rather than authored as loose scripts.
- **`.meta.json`** — sidecar metadata for a script or a folder. It can set instance `attributes`/`properties` (e.g. `SpeedUpgradeTreadmillService.meta.json` sets `RolloutScope` and `SprintSpeedIncreasePercent` attributes) or override the instance's Roblox class entirely (e.g. `CreatureShopPlaceholderItem/init.meta.json` sets `"className": "Tool"` so that folder syncs in as a `Tool` instance rather than a `Folder`). Always check for a sibling `.meta.json` before assuming a script or folder syncs in with default properties.
- **`.model.json`** — used here for RemoteEvents (e.g. `MiddleShopPurchaseEvent.model.json`), a lightweight JSON way to declare a simple instance without a binary model.

## 5. Rojo Development Workflow

The data flow is one-directional for day-to-day work:

```
filesystem (src/, edited in your code editor)
      │  rojo serve watches for changes
      ▼
Rojo server (localhost)
      │  live sync over the Rojo Studio plugin connection
      ▼
Roblox Studio (DataModel updates in real time)
```

**Edit Rojo-managed scripts on disk (in VS Code or similar), not directly in Studio's script editor.** Studio is connected as a *sync target*: as long as it's connected to `rojo serve`, any script or property Rojo manages will get overwritten by the filesystem version on the next sync. Editing directly in Studio will either be silently discarded on the next sync, or (worse) get out of sync in a confusing way. If you need to change a script's behavior, change the `.luau` file in the repo — that's the change that actually persists and gets reviewed/merged.

Steps to develop and test:

1. From the project root, run:
   ```bash
   rojo serve
   ```
2. In Studio, open the Rojo plugin panel and click **Connect** (see [Section 3](#3-first-time-setup) for first-time setup). Make sure you're connected to the correct **development** experience, not production.
3. Edit files under `src/` in your editor. Saved changes sync to the connected Studio session automatically — you'll see the Explorer update live.
4. Test by pressing **Play** (or **Play Here**) in Studio to run the game with your changes.
5. When you're done for the session, you can disconnect the Rojo plugin and stop `rojo serve` (`Ctrl+C` in the terminal).

Caveats specific to this project:

- **`.rbxm` files won't show diffs in your editor.** If you need to change something inside one of the pre-migration models (e.g. a plot's geometry, `MainHUD.rbxm`), you'll generally need to make the change in Studio, then re-export just that model — see [Editing `.rbxm` files](#editing-rbxm-files-ui-plot-geometry-etc) below. Don't do this casually; understand what you're touching first, and prefer editing loose `.luau` files whenever the thing you're changing is a script rather than the model itself.
- **DataStores are live even in Studio testing.** Per the README's dev notes, player progress (Cash, plot ownership, worker hires, upgrades, plot color) is saved via DataStores under the key `PlayerCashData_v2`. If "Enable Studio Access to API Services" is turned on for the place you're testing in, Studio play-sessions will read/write real DataStore data for that place. Make sure you're testing against the designated **development** experience (which should have its own separate DataStore namespace from production) — see [Section 11](#11-production-safety).
- **Plot symmetry:** P1–P10 are meant to be structurally identical. If your change affects plot layout or plot-scoped scripts, it generally needs to be applied consistently across all ten plots, not just the one you were testing in.

### Editing `.rbxm` files (UI, plot geometry, etc.)

Everything under `src/StarterGui/`, `src/StarterPlayer/`, and most of `src/Workspace/` is stored as binary `.rbxm` files rather than loose scripts (see [Section 4](#4-project-structure)). Each file is one **top-level** instance under its service — e.g. `src/StarterGui/MainHUD.rbxm` becomes `StarterGui.MainHUD`, and anything nested inside it (a button, a frame, a group) lives *inside that same file*, not as its own file. This matters because it changes how you save an edit back to disk.

Tested, working workflow:

1. Run `rojo serve` and connect Studio to it as usual (Section 5).
2. Make your edit live in Studio — move a UI element, change a property, tweak geometry, etc. (This is the one case where editing directly in Studio is expected and fine, since the whole point is to capture that edit.)
3. Figure out which **top-level file** actually owns the thing you changed. If you edited something nested (e.g. `PetsButton` inside `MainHUD > CashHUDGroup`), you need the top-level owner — `MainHUD` — not the nested instance itself.
4. In the Studio Explorer, right-click that top-level instance → **Save to File** → overwrite the matching file under `src/` (e.g. save `MainHUD` over `src/StarterGui/MainHUD.rbxm`).
   - **Don't** export just the nested sub-instance to its own new file — Rojo would sync it in as a new top-level sibling instance instead of putting it back where it belongs, which silently changes the DataModel hierarchy (and can break script references that expect the old path).
5. Since `rojo serve` is still watching `src/`, it will immediately try to resync the file you just overwrote back into Studio. Check the Rojo plugin's **View Changes** / sync panel — it should show only the property/instance changes you expect. If it does, the file and Studio now agree and the round-trip worked.
6. Commit the modified `.rbxm` as usual. Because the diff is opaque, describe what you changed inside it in your commit message and PR description (see [Section 8](#8-pull-request-guidelines)).

## 6. Git Branching Strategy

`main` must remain stable and deployable at all times. **Do not commit or push directly to `main`.** All work happens on a feature branch and lands via a reviewed Pull Request.

Use a `<type>/<short-description>` naming convention, for example:

- `feature/new-map`
- `feature/spectator-mode`
- `bugfix/timer`
- `refactor/round-system`

### Branch lifecycle

```bash
# Update your local main
git switch main
git pull

# Create a feature branch off of main
git switch -c feature/spectator-mode

# ... make changes, testing via Rojo/Studio as you go ...

# Check what changed
git status
git diff

# Stage and commit
git add <files>
git commit -m "Add spectator mode toggle to StatsHUD"

# Push the branch (first push needs -u to set the upstream)
git push -u origin feature/spectator-mode
```

Then:

1. **Open a Pull Request** on GitHub from your branch into `main` (see [Section 8](#8-pull-request-guidelines) for what to include).
2. **Respond to review feedback** by making additional commits on the same branch and pushing again (`git push`) — the PR updates automatically. Avoid force-pushing over a branch others may have already pulled or commented against specific lines of, unless you're cleaning up before the first review.
3. **Merge the Pull Request** once it's approved and any required checks pass. Use GitHub's merge button (squash or regular merge, per team preference — nothing in the repo currently mandates one).
4. **Delete the branch** after merging (GitHub offers a "Delete branch" button on the merged PR; or locally: `git push origin --delete feature/spectator-mode`).
5. **Update your local `main`** afterward:
   ```bash
   git switch main
   git pull
   git branch -d feature/spectator-mode   # delete your local copy of the merged branch
   ```

## 7. Daily Workflow

A quick checklist to run through each time you sit down to work:

1. `git switch main`
2. `git pull`
3. `git switch -c feature/your-thing` (new work) or `git switch feature/your-thing` (resuming existing work — consider rebasing/merging in the latest `main` first, see [Section 9](#9-merge-conflicts))
4. `rojo serve` (project root)
5. Connect Studio's Rojo plugin to the local server, pointed at the development experience
6. Develop — edit files under `src/` in your editor
7. Test in Studio (Play/Play Here)
8. `git add` / `git commit` your changes
9. `git push`
10. Open a PR (first time) or let the existing PR update (subsequent pushes)

## 8. Pull Request Guidelines

**What should go into a PR:**
- A focused, reviewable set of changes — one feature, fix, or refactor per PR rather than several unrelated changes bundled together.
- Only the files that are actually part of the change. Double-check `git status` before committing so you don't accidentally include `backups/` output, `.DS_Store`, or unrelated local edits.

**PR title:** Short and descriptive of the *change*, not the branch name — e.g. "Add spectator mode toggle to StatsHUD" rather than "updates" or the raw branch name.

**Description:** Explain what changed and why, and call out anything a reviewer should pay special attention to — e.g. "touches `default.project.json`," "modifies a `.rbxm`, so the diff won't show the actual content," or "changes the DataStore schema." If the PR affects gameplay/economy balance, plot layout, or persistence, say so explicitly.

**Testing:** Describe what you actually tested in Studio (which plot(s), which flow, single-player vs. multiple test accounts if relevant) before opening the PR. Rojo-managed Luau has no automated test suite in this repo currently, so manual Studio testing in the development experience is the primary verification step — do it before opening the PR, not after.

**Review:** Teammates should review the actual diff (not just trust the description), because:
- Server-authoritative economy code (shop purchase handlers, save/load logic) is easy to get subtly wrong in ways that are exploitable or that corrupt saved data.
- `.rbxm`/`.rbxmx` changes are opaque in diffs, so the PR description is the *only* place a reviewer can learn what actually changed inside them — if that's missing, ask.

**Ready to merge when:** the PR has at least one approval, review feedback has been addressed, and the change has been tested in the development experience per the description above.

## 9. Merge Conflicts

A merge conflict happens when Git can't automatically combine two sets of changes to the same part of a file — for example, if your branch and `main` both changed the same lines of the same script in different ways. Git stops and asks you to decide what the final result should be.

To bring your feature branch up to date with `main` and resolve any conflicts:

```bash
git switch main
git pull
git switch feature/your-thing
git merge main
```

(A `git rebase main` is an alternative to `git merge main` if the team prefers a linear history — either is fine as long as you understand what changed.)

If Git reports conflicts, it will mark the conflicting sections directly in the affected files with `<<<<<<<`, `=======`, and `>>>>>>>` markers. Open each conflicted file and **read both versions carefully** — understand what each side was trying to do — before deciding what the merged code should look like. This might mean keeping one side, keeping the other, or writing something that combines both intents correctly. **Do not blindly take "ours" or "theirs"** (e.g. via `git checkout --ours`/`--theirs`) without understanding the conflict; that can silently discard a teammate's fix or reintroduce a bug you were trying to solve.

Once resolved:

```bash
git add <the files you resolved>
git commit   # completes the merge
git push
```

For binary `.rbxm` files, Git cannot show you a textual conflict to resolve line-by-line — if both sides changed the same `.rbxm`, you'll need to coordinate with whoever made the other change to figure out which version (or a manually re-merged one built in Studio) should win.

## 10. Roblox/Rojo-Specific Rules

- **Don't use Rojo's syncback as part of normal daily development.** Syncback was used once to migrate the original Roblox place into this repository. Routine day-to-day changes should be made by editing files under `src/` directly and letting `rojo serve` push them *into* Studio — not by pulling Studio content back out.
- **Don't connect Rojo to the production game for ordinary development.** Always point your local `rojo serve` / Studio session at the designated development experience (see [Section 11](#11-production-safety)).
- **Use the designated development Roblox experience for testing**, not the live production place.
- **Don't commit backups or other git-ignored files.** `backups/` (local `.rbxl` place file backups) and `.DS_Store` are in `.gitignore` for a reason — they're large, machine-local, and not meaningful to review. Check `git status` before committing if you're not sure something is excluded.
- **Don't modify `default.project.json` or `rokit.toml` without understanding the effect.** `default.project.json` controls how `src/` maps onto the Roblox DataModel (including service-level properties like `StreamingEnabled` and `CameraMaxZoomDistance`) — an unreviewed change here can silently break the sync for everyone. `rokit.toml` pins the team's Rojo version — bumping it affects what every contributor installs via `rokit install`.
- **Don't manually reorganize Rojo-managed files/folders without understanding the hierarchy impact.** Moving a file under `src/` moves the corresponding instance in the Roblox DataModel. Renaming or relocating something like a plot folder, a shop config module, or a service script can break references elsewhere (RemoteEvent lookups, `require()` paths, tag-based lookups) that aren't visible from the file move alone.
- **Respect plot symmetry.** P1–P10 are intentionally structurally identical; changes to plot layout or plot-scoped logic should be applied consistently across all ten unless you have a specific reason not to.
- **Treat `src/ServerStorage/LegacyAssets/` as historical, not active.** These are scripts/models preserved from before the Rojo migration; don't build new features on top of them without checking whether they're still in use.
- **`MusicGUI/` under `Workspace/` is a vendored third-party asset** (per its own `README/` instance and `PROJECT_STATE.luau`). Prefer not to restructure it; if you need to change its behavior, check its own documentation first.
- **Server-validate everything involving Cash/purchases**, consistent with the existing pattern (e.g. `MiddleShopPurchaseHandler` re-looks-up item costs server-side rather than trusting the client). Don't introduce client-trusting shortcuts even for "just testing" purposes.

## 11. Production Safety

Development and testing should always happen in the **development** Roblox experience — a separate place from the live production game that real players are on. This keeps in-progress, potentially broken, or exploit-prone code away from live players and their real save data, and keeps you from accidentally overwriting real player data with test data (see the DataStore caveat in [Section 5](#5-rojo-development-workflow)).

> **This repository does not currently document the specific development experience's place URL/ID, or how/when production is updated.** That information isn't recorded anywhere in the repo as of this writing. Confirm with the project maintainer:
> - which Roblox experience is the designated development place to connect Rojo/Studio to, and
> - how and by whom the production game is actually updated/published.
>
> Until that's documented here, treat production deployment as controlled solely by the project owner/maintainer, and do not attempt to publish or connect development tooling to the production place yourself.

## 12. Common Git Commands

| Command | What it does |
|---|---|
| `git status` | Show which files are modified/staged/untracked |
| `git pull` | Fetch and merge the latest changes from the remote into your current branch |
| `git switch main` | Switch to the `main` branch |
| `git switch -c feature/name` | Create and switch to a new branch |
| `git add <files>` | Stage changes for the next commit |
| `git commit -m "message"` | Record staged changes as a commit |
| `git push` | Upload your commits to GitHub |
| `git log` | View commit history |
| `git diff` | Show unstaged changes since the last commit |

## 13. Common Rojo Commands

| Command | What it does |
|---|---|
| `rojo serve` | Start the Rojo server from the project root, watching `src/` and serving `default.project.json` for Studio to connect to |
| `rojo --version` | Confirm which Rojo version is active (should match `rokit.toml`, currently `7.7.0`) |
| `rojo build -o Ball-Tycoon.rbxl` | Build a standalone `.rbxl` place file from the current `src/` tree, without a live Studio connection (useful for producing a one-off snapshot, e.g. for a manual backup) |

`rokit install` (covered in [Section 3](#3-first-time-setup)) isn't a Rojo command itself, but it's what installs the pinned `rojo` binary these commands rely on.

## 14. Troubleshooting

- **Rojo server not appearing in Studio / plugin won't connect:**
  - Confirm `rojo serve` is actually running in a terminal and didn't error out or exit.
  - Confirm you ran `rojo serve` from the project root (where `default.project.json` lives) — running it from the wrong directory, or a directory with no project file, will fail or serve the wrong tree.
  - Confirm the Rojo Studio plugin is installed and up to date, and that you're clicking Connect in the correct Studio session (the one for the development place, not another place open in a different tab/window).
  - Check that nothing else is using the default Rojo port; restart `rojo serve` if needed.
- **Wrong project directory:** If `rojo --version`, `rojo serve`, or `rokit install` behave unexpectedly (e.g. "no project file found"), run `pwd` and confirm you're inside the cloned `Ball-Tycoon` directory, at its root (next to `default.project.json` and `rokit.toml`).
- **Tools not installed / `rojo: command not found`:** Run `rokit install` from the project root. If the command still isn't found, make sure Rokit's shim directory (typically `~/.rokit/bin`) is on your shell's `PATH`.
- **Git branch is behind `main`:** Run `git switch main && git pull`, then from your feature branch run `git merge main` (or `git rebase main`) to bring the latest changes in. See [Section 9](#9-merge-conflicts) if this produces conflicts.
- **Merge conflicts:** See [Section 9](#9-merge-conflicts) — resolve by understanding both sides of the conflict, never by blindly accepting one side.
- **Unexpected changes appearing in Studio after connecting Rojo:** This usually means the filesystem (`src/`) differs from what was previously in that Studio place — e.g. you pulled new commits, or someone else's changes are now syncing in. Run `git status`/`git log` to confirm what actually changed on disk before assuming something is wrong; if the Studio place itself had manual, un-synced edits, those will be overwritten by whatever's on disk once Rojo syncs (this is expected — see [Section 5](#5-rojo-development-workflow)).
- **Accidentally made changes/commits directly on `main`:** Don't push. Create a feature branch from your current state (`git switch -c feature/rescue-my-work`), which carries your commits/changes with it, then reset `main` back to match the remote:
  ```bash
  git switch main
  git reset --hard origin/main
  ```
  Then continue your work on `feature/rescue-my-work` and open a PR as usual. (If you already pushed to `main`, stop and coordinate with the team before doing anything further — don't force-push over shared history on your own.)

## 15. Rules of Thumb

- `main` should stay stable — never commit or push directly to it.
- Work in feature branches, one focused change per branch/PR.
- Test in Roblox Studio (development experience) before opening a PR.
- Use the designated **development** Roblox experience, never production, for day-to-day work.
- Git — specifically the files under `src/` — is the source of truth for Rojo-managed code and content, not whatever's currently loaded in a Studio session.
- Don't use production as a development or testing environment.
- Ask the maintainer before making structural changes to the Rojo project (`default.project.json`, `rokit.toml`, moving/renaming things under `src/`) or before using syncback for anything beyond its original migration purpose.
