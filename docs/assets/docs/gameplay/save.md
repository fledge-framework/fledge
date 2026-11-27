# Save & Load

`fledge_save` writes your game's state to JSON files in save slots. You mark
resources (and, optionally, per-entity components) as `Saveable`; the
`SaveManager` collects them into one file per slot and restores them on load,
with format versioning and migrations for when your save layout changes.

## What you need

```yaml
dependencies:
  fledge_save: ^0.7.1
```

- **Flutter 3.50+** (Dart `^3.14`). Saves go to the platform documents
  directory through `path_provider`.
- **Platforms**: Windows, macOS and Linux; mobile should work. Files are
  written with `dart:io`, so **the web isn't supported**.
- No other plugin is required, and `SavePlugin` adds no systems: it inserts
  the `SaveManager` resource. Saving and loading are `async` and happen
  outside the tick (see [Saving from a system](#saving-from-a-system)).

## Quick start

<!-- snippet-setup
class Inventory with Saveable {
  final List<String> items = [];

  @override
  String get saveKey => 'inventory';

  @override
  Map<String, dynamic> toSaveJson() => {'items': items};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    items
      ..clear()
      ..addAll((json['items'] as List?)?.cast<String>() ?? []);
  }
}

class Health with Saveable {
  int hp = 10;

  @override
  String get saveKey => 'health';

  @override
  Map<String, dynamic> toSaveJson() => {'hp': hp};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) =>
      hp = json['hp'] as int? ?? 10;
}

Future<void> uploadToCloud(String slot) async {}

bool reachedCheckpoint(World world) => true;
-->

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_save/fledge_save.dart';

class Inventory with Saveable {
  final List<String> items = [];

  @override
  String get saveKey => 'inventory';

  @override
  Map<String, dynamic> toSaveJson() => {'items': items};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    items
      ..clear()
      ..addAll((json['items'] as List?)?.cast<String>() ?? []);
  }
}

Future<void> main() async {
  final app = App()
    ..addPlugin(SavePlugin(config: const SaveConfig(gameDirectory: 'MyGame')))
    ..insertResource(Inventory()); // found automatically: it's Saveable

  await app.tick();

  final saves = app.world.getResource<SaveManager>()!;
  await saves.save(app.world, slotName: 'slot1');
  await saves.load(app.world, slotName: 'slot1');
}
```

`App.tick()` returns a `Future`; await it.

## The `Saveable` mixin

A saveable type supplies three members:

| Member | Purpose |
|---|---|
| `saveKey` | The key its data is stored under. Keep it stable across versions: renaming it orphans old saves |
| `toSaveJson()` | Returns its state as JSON-encodable data |
| `loadFromSaveJson(json)` | Restores from that data. Old saves may lack newer keys, so give every read a default |

Only persist what the player would expect back. Caches, UI state and anything
derived from other saved data can be rebuilt after a load.

### Resources are discovered automatically

At save and load time the manager collects every resource in the world that
mixes in `Saveable` (`world.resourcesOfType<Saveable>()`). Insert the resource
and it's included. **Don't** also register world resources by hand.

`SavePlugin.registerSaveable(obj)` exists for saveable objects that *aren't*
world resources, such as a singleton your own plugin owns.
`unregisterSaveable(obj)` removes one, `saveables` lists them, and the
`saveManager` getter returns the manager the plugin inserted (null before
`build`). An object both registered and in the world is saved once.

```dart
final savePlugin = SavePlugin();
final app = App()..addPlugin(savePlugin);

savePlugin.registerSaveable(Inventory()); // not a world resource
```

On load, each saveable whose key is in the file gets `loadFromSaveJson`;
saveables missing from the file are left as they are, and keys in the file
that nothing claims are ignored. Loading restores into the resources that
already exist: it doesn't insert new ones.

## Saving entities

Per-entity state (the player, NPCs, placed objects) lives in components. Mark
each entity to save with a stable `SaveId`, and register the component types
once on `saveManager.components`. Components to save mix in `Saveable` too;
their `saveKey` names them in the file.

```dart
final app = App()..addPlugin(SavePlugin());
final saves = app.world.getResource<SaveManager>()!;

saves.components
  ..register(Inventory.new)
  ..register(Health.new);

app.world.spawn()
  ..insert(const SaveId('player:1'))
  ..insert(Inventory())
  ..insert(Health());
```

The marked entities' registered components go in the file's `entities`
section, keyed by id. On load:

- an entity already carrying the same `SaveId` is updated in place, and its
  other components are kept;
- a saved id no entity carries is spawned, with a `SaveId` and its components
  created by the registered constructors. `saves.lastSpawned` lists those new
  entities, so you can attach what isn't saved (sprites, colliders);
  `lastLoadedIds` lists every id restored;
- entities whose ids aren't in the save are left alone (load doesn't despawn).

Ids must be unique among saved entities and stable across sessions
(`'npc:ada'`, `'chest:12'`). Registering two types with the same `saveKey`
throws an `ArgumentError`.

## Saving from a system

Systems are synchronous and must not await file I/O inside a tick. So a
system only *requests* a save, and the code that drives the frames does the
writing after the tick:

```dart
final checkpoint = FunctionSystem(
  'checkpoint',
  resourceWrites: {SaveManager},
  run: (world) {
    if (reachedCheckpoint(world)) {
      world.getResource<SaveManager>()?.requestSave(
        metadata: {'checkpoint': 'forest_entrance'},
      );
    }
  },
);

final app = App()
  ..addPlugin(SavePlugin())
  ..addSystem(checkpoint, schedule: Schedules.update);

// Your frame driver (a Flutter ticker callback, a game loop):
Future<void> frame() async {
  await app.tick();

  final saves = app.world.getResource<SaveManager>()!;
  if (saves.saveRequested) {
    final metadata = saves.pendingMetadata;
    saves.clearSaveRequest();
    await saves.save(app.world, slotName: 'autosave', metadata: metadata);
  }
}
```

`save` reads every saveable synchronously before its first `await`, so the
file is a consistent snapshot of that moment even if more frames run while
it's being written. `load` writes into resources and entities when the file
has been read, so call it while the game isn't mid-tick, for example from a
title screen or between frames.

## Slots, metadata and the file

```dart
Future<void> slots(World world, SaveManager saves) async {
  await saves.save(world, slotName: 'slot2', metadata: {'playTime': 3600});

  for (final slot in await saves.listSaveSlots()) {
    print('${slot.slotName}: ${slot.timestamp} ${slot.metadata}');
  }

  if (await saves.hasSaveFile('slot2')) {
    final metadata = await saves.load(world, slotName: 'slot2');
    print(metadata?['playTime']);
  }

  await saves.deleteSave('slot2');
}
```

Files live in `<documents>/<gameDirectory>/<slot>.json`:

```json
{
  "version": 1,
  "timestamp": "2026-01-15T10:30:00.000",
  "metadata": { "checkpoint": "forest_entrance" },
  "resources": {
    "inventory": { "items": ["sword"] }
  },
  "entities": {
    "player:1": { "health": { "hp": 7 } }
  }
}
```

`metadata` is omitted when you pass none; `entities` appears only when
component types are registered. `listSaveSlots()` reads just enough of each
file to return a `SaveSlotInfo` (`slotName`, `timestamp`, `formatVersion`,
`metadata`), newest first, for a load menu. Unreadable files are skipped.

### Crash safety and backups

Every save writes `<slot>.json.tmp`, flushes it, then renames it over
`<slot>.json`, so a crash mid-save never truncates the current file. With
`keepBackup: true` the previous `<slot>.json` becomes `<slot>.backup.json`
first; `load(world, slotName: ..., fromBackup: true)` reads it and
`hasBackup(slot)` checks for it. `deleteSave` removes the slot, its backup and
any leftover temp file. Backup and temp files never appear as slots.

## Versions and migrations

```dart
final plugin = SavePlugin(
  config: SaveConfig(
    gameDirectory: 'MyGame',
    formatVersion: 2,
    // Keyed by the version each step migrates FROM.
    migrations: {
      1: (data) {
        final inv = data['resources']['inventory'] as Map<String, dynamic>;
        inv['items'] = inv.remove('itemIds') ?? [];
        return data;
      },
    },
    keepBackup: true,
  ),
);
```

On load, a file with `version` *v* lower than `formatVersion` runs
`migrations[v]`, `migrations[v + 1]`, … up to `formatVersion - 1`, each
receiving the whole decoded file (`version`, `timestamp`, `metadata`,
`resources`, `entities`). The manager sets `version` after each step. A file
with no `version` counts as 0.

`load` returns `null` and leaves the world untouched when the file is missing
or unreadable, was written by a **newer** `formatVersion`, or needs a step
that isn't registered. With no `migrations` at all (the default), older files
load as they are. `load` also returns `null` for a good save written without
metadata, so check `hasSaveFile` first if you need to tell the cases apart.

| `SaveConfig` field | Default | Meaning |
|---|---|---|
| `gameDirectory` | `'saves'` | Folder under the base directory |
| `formatVersion` | `1` | Version written into new saves |
| `defaultSlot` | `'save'` | Slot used when a call names none |
| `migrations` | `{}` | Steps keyed by from-version |
| `keepBackup` | `false` | Keep the previous save as `<slot>.backup.json` |
| `baseDirectory` | `null` | Use this absolute directory instead of the documents directory (tests, portable installs) |

## `SaveManager` reference

| Member | Meaning |
|---|---|
| `save(world, {slotName, metadata})` | Writes a slot; `true` on success. Failures are logged, not thrown |
| `load(world, {slotName, fromBackup})` | Restores a slot; returns its metadata or `null` |
| `requestSave({metadata})` | Sets `saveRequested` and `pendingMetadata`, for systems |
| `saveRequested` / `pendingMetadata` | The pending request |
| `clearSaveRequest()` | Clears both |
| `hasSaveFile([slot])` / `hasBackup([slot])` | Whether the file exists |
| `listSaveSlots()` | `SaveSlotInfo` for each slot, newest first (cached; refreshed by save and delete) |
| `deleteSave([slot])` | Removes the slot, backup and temp file |
| `initialize()` / `isInitialized` | Optional: creates the directory and caches the slot list up front. Everything works without it |
| `components` | The `SavedComponents` registry for entity saving |
| `lastSpawned` / `lastLoadedIds` | Entities spawned and ids restored by the last successful load |
| `getSaveableResources(world)` | The saveables a save or load covers; override in a subclass |
| `config` | The `SaveConfig` |

Full signatures are in the
[dartdoc](https://pub.dev/documentation/fledge_save/latest/).

## A custom save manager

To add behaviour (say, uploading to a cloud service), subclass the manager.
Extending `SaveManagerWithSaveables`, the class `SavePlugin` inserts, keeps
both auto-discovery and the plugin's registered saveables:

```dart
class CloudSaveManager extends SaveManagerWithSaveables {
  CloudSaveManager({required super.config, required super.getSaveables});

  @override
  Future<bool> save(
    World world, {
    String? slotName,
    Map<String, dynamic>? metadata,
  }) async {
    final ok = await super.save(world, slotName: slotName, metadata: metadata);
    if (ok) await uploadToCloud(slotName ?? config.defaultSlot);
    return ok;
  }
}

// Insert it after the plugin, so it replaces the plugin's manager.
App buildApp() {
  final savePlugin = SavePlugin(config: const SaveConfig(gameDirectory: 'MyGame'));
  return App()
    ..addPlugin(savePlugin)
    // The type argument matters: resources are looked up by the type they
    // were inserted as, and everything reads `getResource<SaveManager>()`.
    ..insertResource<SaveManager>(
      CloudSaveManager(
        config: savePlugin.config,
        getSaveables: () => savePlugin.saveables,
      ),
    );
}
```

A plain `SaveManager` subclass also works, inserted the same way (or without
`SavePlugin` at all); it still discovers `Saveable` resources in the world
but doesn't see objects registered with `registerSaveable`. Note that
`savePlugin.saveManager` keeps pointing at the plugin's original manager.

## Preferences

Settings that belong to the machine rather than to a save (volume, key
bindings, display mode) go in a `PreferencesFile`: plain JSON beside the
saves (`<gameDirectory>/settings.json` by default; `name:` changes it),
written with the same tmp-then-rename safety, and readable before any save
is loaded. A missing or broken file reads as `null`, so the game falls back to
its defaults.

```dart
Future<void> savePrefs() async {
  final prefs = PreferencesFile(gameDirectory: 'MyGame');
  final data = await prefs.read() ?? {};
  await prefs.write({...data, 'music': 0.6});
}
```

## See also

- [Calendar](/docs/gameplay/calendar#saving-the-calendar): saving the in-game clock
- [Resources](/docs/ecs/resources)
- [Dialogue](/docs/gameplay/dialogue)
