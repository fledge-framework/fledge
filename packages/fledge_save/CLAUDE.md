# fledge_save

## Purpose
Save/load system with slot management, resource aggregation, atomic writes, backups, and versioned migrations.

## Status: Functional

## Stats
- Source: 5 files, ~780 LOC
- Tests: 2 files (auto-discovery/manual registration; disk I/O — migrations, backups, atomic writes, slots)
- TODOs in code: 0

## What Works
- Save/load game state to/from named slots
- Slot management (list, delete, metadata)
- Version tracking on save files with a migration chain (`SaveConfig.formatVersion` + `SaveConfig.migrations`)
- Atomic saves (write `<slot>.json.tmp`, then rename) and optional backups (`SaveConfig.keepBackup`, `load(fromBackup: true)`)
- **Auto-discovery** of `Saveable` resources: any resource inserted into the world that mixes in `Saveable` is picked up at save/load time — no manual registration required
- `SavePlugin.registerSaveable` remains for `Saveable` objects that live outside the world's resource table

## Gaps
None identified.

## Action Items
No open action items.

## Architecture Notes
- **Entry point**: `lib/fledge_save.dart` (barrel export)
- **SavePlugin** (`lib/src/plugin.dart`): Inserts a `SaveManagerWithSaveables` resource only — registers **no systems**. `registerSaveable` / `unregisterSaveable` for out-of-world objects.
- **Saveable** (`lib/src/traits/saveable.dart`): Mixin resources apply to participate in save/load. Auto-discovered via `World.resourcesOfType<Saveable>()` — just insert the resource and it's in the save set.
- **SaveManager** (`lib/src/resources/save_manager.dart`): Orchestrates save/load — collects all `Saveable` resources from the world (default behaviour is `world.resourcesOfType<Saveable>()`), serializes to JSON, writes to disk. On load, deserializes and restores resources. Override `getSaveableResources` to customise discovery.
- **SaveManagerWithSaveables**: Default implementation installed by `SavePlugin`. Unions the auto-discovered set with any explicitly registered via `SavePlugin.registerSaveable`, deduping by identity.
- **Slot system**: Each save occupies a named slot with metadata (timestamp, version, custom data). `listSaveSlots()` returns `SaveSlotInfo`s for UI; backup and stale `.tmp` files are never listed as slots.
- **Migrations** (`lib/src/config/save_config.dart`): `migrations` is keyed by the version a step migrates **from**; loading a file at `v < formatVersion` runs each step in order. A missing step fails the load without touching resources; files newer than `formatVersion` are refused.
- **Async bridge**: ECS system calls `requestSave(metadata: …)` (sets `saveRequested` + `pendingMetadata`); Flutter game loop checks flag and calls `save(world)` async. File I/O via `path_provider` and `dart:io`.
- **Tests**: Flutter package — run with `flutter test`.
