# TODO

Outstanding work for Ball Tycoon. Technical background for most items is in [`PROJECT_STATE.md` §4](PROJECT_STATE.md#4-known-issues--todos).

Last reviewed: 2026-10-08, against `main` at `bb7e5ac`.

**How to use this file:** tick items off as they land and delete them in the same PR, or move them to PROJECT_STATE §4.5 if the history is worth keeping. Add new work here rather than in PROJECT_STATE.

---

## 1. High Priority

Needed before the game can be released publicly, or blocking a feature that already shipped.

- [ ] **Add a way to earn Gems.** (High) The Bank (PR #15) works, but no gameplay script ever increments `GemData.Gems`, so there is nothing to deposit. The design for where Gems come from has not been written down yet.
  - Files: `src/ServerScriptService/DataSaveScript.server.luau` (creates `Gems`), `src/ServerScriptService/BankZoneHandler.server.luau`
  - Also decide what "not yet safe" means for carried Gems (the comment beside `Gems` in DataSaveScript), e.g. whether they are lost on death. Nothing implements that yet.
- [ ] **Wire up Robux purchases.** (High, before release) Replace every `productId = 0` in `ShopConfig` and `CashPackConfig` with real Developer Product IDs, and write a `MarketplaceService.ProcessReceipt` handler on the server. None exists today, so real IDs alone would take players' Robux without granting anything.
  - Files: `src/ReplicatedStorage/ShopConfig.luau`, `src/ReplicatedStorage/CashPackConfig.luau`, new server script
- [ ] **Set real prices for plot purchases.** (High, before release) Every centre costs 5 Cash, every Home structure 1, the Coil 1, and the Knockback Plank and Throwable Ball 10. They look like test values. They live as `Price` IntValues inside all ten plot `.rbxm` files (identical across plots today), so any change must be made to P1–P10.
  - Prerequisite: confirm with the team that these are test values.

## 2. Features and Improvements

Planned or partly built work.

- [ ] **Build the Orb centre.** (Medium) `Centre04_Orb/Upgrades` is empty on every plot. The team's stated order (commit `767b4e8`) is Orb centre → Pet centre → pets.
- [ ] **Build the Pet centre and the pets system.** (Medium) `Centre05_Pet/Upgrades` is empty, and the Pets panel still shows "Soon" placeholders.
  - Depends on: the Orb centre, per the order above.
  - Files: `Centre05_Pet` in each plot, the Pets panel in `src/StarterGui/MainHUD/MainHUDBuilder.luau`
- [ ] **Give the Inventory panel content.** (Medium) The button and panel exist (PR #18), but the panel is an empty placeholder. What it should show (e.g. owned tools, shop items, Gems) has not been decided.
  - Files: `src/StarterGui/MainHUD/MainHUDBuilder.luau` (`Theme.inventoryPanel`), `MainHUDController.client.luau`
- [ ] **Persist MiddleShops items.** (Medium) The Creature Shop clones its Tool into the Backpack only, so it disappears on respawn and on rejoin. The `PurchasedItems` counters are already saved, so the fix is to re-grant from those counters (and/or use StarterGear), not to add new save data.
  - Files: `src/ServerScriptService/MiddleShopPurchaseHandler.server.luau`
- [ ] **Replace placeholder MiddleShops content.** (Medium) All four Creature tiers grant the same `CreatureBall_Slimey` placeholder. Ball and Gear Shop purchases grant no item at all, only a counter. `GearShopConfig`'s items are invented placeholders.
  - Files: `src/ServerStorage/CreatureShopPlaceholderItem/`, `src/ReplicatedStorage/*ShopConfig.luau`
- [ ] **Set the real Daily Worker Gifts reward.** (Medium) `PLACEHOLDER_GIFT_REWARD_CASH = 150` in `src/ServerScriptService/WorkerNotesGiftsStationService.server.luau`. It's a one-line change once the amount is decided.
- [ ] **Tune MiddleShops prices.** (Low) Every `cost` in the shop configs is a placeholder.
  - Depends on: overall economy balancing.
- [ ] **Add a close/skip control to the tutorial's StepPanel.** (Low) Today the only exits are the welcome card's Skip or finishing all nine steps, and a player who opens a shop instead of answering the welcome card is auto-started. See PROJECT_STATE §2.12.
  - Files: `src/StarterGui/TutorialGui/StepPanel.luau`, `TutorialController.luau`
- [ ] **Decide on the Daily Worker Gifts opening animation.** (Low) Still undecided whether a lid tween on claim is worth building; the feature works without it.

## 3. Needs Investigation

Possible problems or open questions. Each needs checking before it becomes a fix.

- [ ] **Duplicate `BankZone` parts.** (High) `src/Workspace/MiddleShops/BankStructure.rbxm` contains two parts both named `BankZone`. `BankZoneHandler` uses `WaitForChild("BankZone")`, so only one of them is guaranteed to accept deposits. Check in Studio which one is used, then rename or remove the other.
- [ ] **Check plot-to-plot consistency of the Avatar Centre.** (Medium) The PR #16 commit message reports avatar-upgrade buy buttons and sizing on some plots differing from Plot 1, and odd structures on Plot 10. That PR fixed things, but nobody has recorded whether every reported issue is gone. Walk P1–P10 in Studio. (Prices already match across all plots.)
- [ ] **Confirm what `Enum.Font.Gotham*` renders as.** (Low) The theme files' comments claim this Studio build has no Gotham files, so Gotham probably renders as Montserrat. Check by eye in Studio and update the `Theme.font` comments in both theme files to match what you see.
- [ ] **Check the hover tooltips live.** (Low) Tooltips on all six HUD buttons are wired and load without errors, but nobody has checked their position and timing by eye.
- [ ] **Confirm and remove apparently unused assets.** (Low) No script references were found for `src/ReplicatedStorage/PurchaseEffectModule_FreshTest6.luau`, `src/ReplicatedStorage/BouncePlatformTheme.luau`, `src/ReplicatedStorage/Ghosts/JumpUpgrade_ArrowBouncePlatform_Ghost.rbxm`, or `src/ServerStorage/Machines/JumpUpgrade_ArrowBouncePlatform.rbxm`. The jump assets look superseded by the Coil station. MusicGUI and MiddleShops `.rbxm` files were not scanned, so check those (or check in Studio) before deleting.
- [ ] **Decide the fate of `StructurePurchaseService`.** (Low) The only scripts that require it are the per-slot `StructureBuyPadScript`s, which are saved Disabled since `StructureSequenceService` replaced them. Removing it cleanly means editing all ten plot `.rbxm` files.
- [ ] **Identify the top-level Workspace shop parts and `Roblox_Coil`.** (Low) `BallShop` and `CreatureShop` (single Parts since the migration, changed in PR #15), `GearShop` and `Bank` (added in PR #15), and `Roblox_Coil` (added in commit `c57c46c`) aren't referenced by any script and aren't documented. Ask their authors what they're for and document them in PROJECT_STATE §1.1.
- [ ] **Clean up leftover Studio objects.** (Low) The empty `src/StarterGui/ScreenGui.rbxm`. Also check whether the Studio-only `Irwin Vernon`, `Tycoon Wall` and `Tycoon Dropper` models (listed in older docs, not in `src/`) still exist in the place.
- [ ] **Record which place is the development place.** (Low) `default.project.json` lists five `servePlaceIds`, but no doc says which is for development and which is production. Add the answer to CONTRIBUTING §11.

## 4. Testing and Validation

There is no automated test suite. These need manual playtests in the development place.

- [ ] **Multi-player plot reset (PR #16).** (High) With 2+ test accounts: leave and rejoin, and confirm (a) the departing player's progress restores fully, possibly into a different plot, and (b) the next player to take the freed plot gets a completely blank plot, with no leftover structures, balls, or Avatar stations.
- [ ] **Full save round-trip on `PlayerCashData_v3`.** (High) Confirm every saved field survives a rejoin: Cash, Gems, BankedGems, upgrade level, centre level, structures, Avatar stations (and their re-granted weapons), workers, PurchasedItems, plot color, tutorial step, and gift cooldown.
- [ ] **DataStore failure path.** (Medium) Simulate a load failure and confirm `DataLoadFailed` blocks saving, the tutorial doesn't replay, and the gift cooldown refuses. See PROJECT_STATE §2.12 and §2.13 for the intended behavior.
- [ ] **PvP weapons.** (Medium) With 2+ accounts: Knockback Plank and Throwable Ball damage, knockback and ragdoll; the ForceField exemption; cooldowns; behavior across respawn.
- [ ] **Load test with 10 players.** (Low) Profile worker AI, ball spawning, and the per-plot polling loops (Bank, station pads, centres) with a full server.

## 5. Code Quality and Maintenance

- [ ] **Fix out-of-date code comments.** (Low) `src/ReplicatedStorage/UISoundConfig/init.luau` says `hoverSoundId` is an empty placeholder, but both sound IDs are set. `src/ServerScriptService/MiddleShopPurchaseHandler.server.luau`'s header still describes five shops, including Trading Post/Vault/Upgrade.
- [ ] **Make `TeleportToTycoonEvent` a static RemoteEvent.** (Low) It's created at runtime by `PlotAssignmentScript` instead of being a `.model.json` like every other RemoteEvent.
- [ ] **Decide on the dormant shop configs.** (Low) `TradingPostConfig`, `VaultConfig` and `UpgradeShopConfig` are kept (and still whitelisted in `MiddleShopPurchaseHandler`) in case those shops return. Delete all three if they're gone for good.
- [ ] **Decide on `ReplicatedStorage/Design/`.** (Low) The StyleSheet system was meant to be applied to MainHUD, but PR #18's `UITheme` system replaced that plan, and the folder is excluded from sync by `globIgnorePaths`. Keep it for something else, or delete it.

## 6. Future Ideas

Optional ideas carried over from earlier planning notes. None are committed to.

- [ ] Game progression beyond the tycoon loop, e.g. prestige/rebirth or end-game goals.
- [ ] Admin commands or an in-game bug-report UI to help development.
