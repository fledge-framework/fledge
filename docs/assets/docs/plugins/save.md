# Save System

The `fledge_save` package provides a save/load system for persisting game state. Any resource that mixes in `Saveable` and is inserted into the world is auto-discovered at save time — no manual registration needed for the common case. File-based storage with versioning and a request-based save pattern for ECS-to-Flutter bridging round out the package.

## Installation

```yaml
dependencies:
  fledge_save: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_save/fledge_save.dart';

// 1. Make your resources saveable
class Inventory with Saveable {
  final List<String> items = [];

  @override
  String get saveKey => 'inventory';

  @override
  Map<String, dynamic> toSaveJson() => {
    'items': items,
  };

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    items.clear();
    items.addAll((json['items'] as List?)?.cast<String>() ?? []);
  }
}

// 2. Set up the save system
void main() async {
  final app = App()
    ..addPlugin(SavePlugin(
      config: SaveConfig(gameDirectory: 'MyGame'),
    ))
    ..insertResource(Inventory()); // auto-discovered as Saveable

  await app.tick();

  // Save the game
  final saveManager = app.world.getResource<SaveManager>()!;
  await saveManager.save(app.world, slotName: 'slot1');

  // Load the game
  await saveManager.load(app.world, slotName: 'slot1');
}
```

> **Manual registration** (`SavePlugin.registerSaveable`) is still available for `Saveable` objects that live *outside* the world's resource table — e.g. a singleton you manage yourself. World resources are picked up automatically.

## The Saveable Mixin

Resources that need to be persisted implement the `Saveable` mixin:

```dart
mixin Saveable {
  /// Unique key for this resource in save files
  String get saveKey;

  /// Serialize state to JSON
  Map<String, dynamic> toSaveJson();

  /// Restore state from JSON
  void loadFromSaveJson(Map<String, dynamic> json);
}
```

### Example: Player Progress

```dart
class PlayerProgress with Saveable {
  int level = 1;
  int experience = 0;
  Set<String> completedQuests = {};

  @override
  String get saveKey => 'progress';

  @override
  Map<String, dynamic> toSaveJson() => {
    'level': level,
    'experience': experience,
    'completedQuests': completedQuests.toList(),
  };

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    level = json['level'] as int? ?? 1;
    experience = json['experience'] as int? ?? 0;
    completedQuests = Set.from(
      (json['completedQuests'] as List?)?.cast<String>() ?? [],
    );
  }
}
```

### Backwards Compatibility

Handle missing keys gracefully to support loading older save files:

```dart
@override
void loadFromSaveJson(Map<String, dynamic> json) {
  // Always provide defaults for new fields
  level = json['level'] as int? ?? 1;

  // New field added in v2 - older saves won't have it
  prestigePoints = json['prestigePoints'] as int? ?? 0;
}
```

## SaveConfig

Configure save system behavior:

```dart
SaveConfig(
  gameDirectory: 'MyGame',  // Subdirectory for saves (default: 'saves')
  formatVersion: 1,         // Increment for breaking changes (default: 1)
  defaultSlot: 'save',      // Default slot name when none specified (default: 'save')
  migrations: {},           // Migration steps keyed by from-version (default: none)
  keepBackup: false,        // Keep the previous save as <slot>.backup.json (default: false)
  baseDirectory: null,      // Override the app documents directory (default: null)
)
```

`baseDirectory` replaces the `path_provider` application documents directory; saves then live in `<baseDirectory>/<gameDirectory>/`. It is handy for tests (point it at a temp dir), portable installs, or a user-chosen save location.

### Version Migration

Bump `formatVersion` whenever the save shape changes, and register one `SaveMigration` step per version bump in `migrations`, keyed by the version it migrates **from**:

```dart
SaveConfig(
  formatVersion: 3,
  migrations: {
    // v1 -> v2: 'coins' was renamed to 'gold'
    1: (data) {
      final progress = data['resources']['progress'] as Map<String, dynamic>;
      progress['gold'] = progress.remove('coins');
      return data;
    },
    // v2 -> v3: new 'prestigePoints' field
    2: (data) {
      data['resources']['progress']['prestigePoints'] = 0;
      return data;
    },
  },
)
```

Each step receives the whole decoded save file (`version`, `timestamp`, `metadata`, `resources`) and returns the next version's data; `SaveManager` sets `version` for you after each step. On `load()`, a v1 file runs `migrations[1]` then `migrations[2]` before any resource is restored.

Rules:

- A file whose `version` is **greater** than `formatVersion` is refused (`load()` returns `null`) — you can't load a save from a newer build.
- If any step in the chain is missing, the load fails (`null`, with a message on the `fledge_save` log) and no resource is touched.
- If `migrations` is empty (the default), older files load as-is with no migration, exactly as before migrations existed. Rely on defaults in `loadFromSaveJson` (see [Backwards Compatibility](#backwards-compatibility)) in that case.
- A file with no `version` key is treated as version `0`, so it needs a `migrations[0]` step once you register any migrations.

### Backups and Crash Safety

Every `save()` writes to `<slot>.json.tmp` first (flushed to disk), then renames it over `<slot>.json`. A crash or power loss mid-save leaves the previous `<slot>.json` intact; the leftover `.tmp` is ignored and never listed as a slot.

With `keepBackup: true`, the previous `<slot>.json` is moved to `<slot>.backup.json` before the new file takes its place, giving you one-save-deep rollback:

```dart
if (await saveManager.load(world, slotName: 'slot1') == null &&
    await saveManager.hasBackup('slot1')) {
  // Current save is corrupt or unreadable - fall back to the previous one
  await saveManager.load(world, slotName: 'slot1', fromBackup: true);
}
```

Backups are not returned by `listSaveSlots()`, and `deleteSave()` removes a slot's backup and any leftover temp file along with it.

## SaveManager

The `SaveManager` resource handles file I/O and coordinates saves across resources.

### Initialization

`initialize()` is optional. `save()` creates the save directory on demand, and `load()` / `listSaveSlots()` work without it. Call it at startup if you want the directory created and the slot list cached up front:

```dart
final saveManager = world.getResource<SaveManager>()!;
await saveManager.initialize();
```

### Checking for Save Files

```dart
final saveManager = world.getResource<SaveManager>()!;

// Check if a specific slot has a save
final hasSave = await saveManager.hasSaveFile('slot1');

// List all save slots (sorted by timestamp, newest first)
final slots = await saveManager.listSaveSlots();
for (final slot in slots) {
  print('${slot.slotName}: saved ${slot.timestamp}');
}
```

### Saving

```dart
// Basic save (uses default slot)
final success = await saveManager.save(world);

// Save to a specific slot
final success = await saveManager.save(world, slotName: 'slot1');

// Save with metadata (e.g., player location, screenshot path)
final success = await saveManager.save(
  world,
  slotName: 'slot1',
  metadata: {
    'playerX': 100,
    'playerY': 200,
    'mapId': 'forest',
  },
);
```

### Loading

```dart
final metadata = await saveManager.load(world, slotName: 'slot1');

if (metadata != null) {
  // Resources have been restored, metadata contains save metadata
  final inventory = world.getResource<Inventory>()!;
  print('Loaded ${inventory.items.length} items');
}

// Load the previous save instead (requires keepBackup: true)
await saveManager.load(world, slotName: 'slot1', fromBackup: true);
```

`load()` applies any registered [migrations](#version-migration) before restoring resources. It returns `null` if the file is missing or unreadable, was written by a newer `formatVersion`, or a migration step is missing; in all of those cases no resource is modified. Failures are logged via `dart:developer` under the `fledge_save` name rather than thrown. Note that a save written without metadata also returns `null`, so use `hasSaveFile()` first if you need to tell the two apart.

### Deleting Saves

```dart
await saveManager.deleteSave('slot1');
```

## Request-Based Saving

For games where saves are triggered by events (e.g., reaching a checkpoint, going to sleep), use the request pattern:

```dart
// In your game system - request a save
@system
void checkpointSystem(World world) {
  final saveManager = world.getResource<SaveManager>();
  if (saveManager == null) return;

  // Player reached checkpoint
  if (reachedCheckpoint) {
    saveManager.requestSave(metadata: {
      'checkpoint': 'forest_entrance',
    });
  }
}

// In your Flutter layer - process save requests
void gameLoop() {
  app.tick();

  final saveManager = app.world.getResource<SaveManager>()!;
  if (saveManager.saveRequested) {
    final data = saveManager.pendingMetadata;
    saveManager.clearSaveRequest();

    // Perform async save
    saveManager.save(app.world, slotName: 'autosave', metadata: data);
  }
}
```

## Save File Format

Save files are stored as JSON in the application documents directory (or `SaveConfig.baseDirectory` when set):

```
Documents/
  MyGame/
    slot1.json
    slot1.backup.json   # only with keepBackup: true
    slot2.json
    autosave.json
```

### File Structure

```json
{
  "version": 1,
  "timestamp": "2024-01-15T10:30:00Z",
  "metadata": {
    "playerX": 100,
    "playerY": 200
  },
  "resources": {
    "inventory": {
      "items": ["sword", "shield", "potion"]
    },
    "progress": {
      "level": 5,
      "experience": 1250,
      "completedQuests": ["intro", "forest_rescue"]
    }
  }
}
```

## SavePlugin

The `SavePlugin` sets up the save system:

```dart
final savePlugin = SavePlugin(
  config: SaveConfig(
    gameDirectory: 'MyGame',
    formatVersion: 1,
  ),
);

// Register saveable resources
savePlugin.registerSaveable(PlayerProgress());
savePlugin.registerSaveable(Inventory());
savePlugin.registerSaveable(Settings());

App()
  .addPlugin(savePlugin);
```

### Custom SaveManager

For games needing custom save logic (e.g., cloud saves), extend `SaveManager`:

```dart
class CloudSaveManager extends SaveManager {
  CloudSaveManager({required super.config});

  @override
  Future<bool> save(World world, {String? slotName, Map<String, dynamic>? metadata}) async {
    // Save locally first
    final success = await super.save(world, slotName: slotName, metadata: metadata);

    // Then sync to cloud
    if (success) {
      await uploadToCloud(slotName ?? config.defaultSlot);
    }

    return success;
  }
}
```

## Best Practices

### 1. Use Stable Save Keys

Save keys should remain constant across versions:

```dart
// Good - stable key
@override
String get saveKey => 'player_inventory';

// Bad - might change if class is renamed
@override
String get saveKey => runtimeType.toString();
```

### 2. Handle Missing Data Gracefully

```dart
@override
void loadFromSaveJson(Map<String, dynamic> json) {
  // Always provide sensible defaults
  health = json['health'] as int? ?? 100;
  gold = json['gold'] as int? ?? 0;
}
```

### 3. Don't Save Transient State

Only save persistent data, not per-frame state:

```dart
class GameState with Saveable {
  // Persistent - save this
  int score = 0;
  List<String> unlockedLevels = [];

  // Transient - don't save these
  bool isPaused = false;
  double animationTimer = 0;

  @override
  Map<String, dynamic> toSaveJson() => {
    'score': score,
    'unlockedLevels': unlockedLevels,
    // Don't include isPaused or animationTimer
  };
}
```

### 4. Version Your Save Format

```dart
// Document breaking changes next to their migrations
// v1: Initial format
// v2: Renamed 'coins' to 'gold'
// v3: Added 'prestigePoints' to progress
SaveConfig(
  formatVersion: 3,
  migrations: {1: renameCoinsToGold, 2: addPrestigePoints},
)
```

Never ship a `formatVersion` bump without the matching migration step, or every existing save becomes unloadable.

## API Reference

### SaveConfig

| Property | Type | Description |
|----------|------|-------------|
| `gameDirectory` | `String` | Subdirectory for saves (default: `'saves'`) |
| `formatVersion` | `int` | Save format version for migration (default: `1`) |
| `defaultSlot` | `String` | Default slot name when none specified (default: `'save'`) |
| `migrations` | `Map<int, SaveMigration>` | Migration steps keyed by from-version (default: `{}`) |
| `keepBackup` | `bool` | Keep the previous save as `<slot>.backup.json` (default: `false`) |
| `baseDirectory` | `String?` | Overrides the app documents directory (default: `null`) |

### SaveManager

| Method | Description |
|--------|-------------|
| `initialize()` | Optional: create the save directory and cache slot info |
| `save(world, {slotName, metadata})` | Save game state to a slot (atomic temp-file + rename) |
| `load(world, {slotName, fromBackup})` | Migrate and load game state from a slot or its backup (returns metadata or null) |
| `hasSaveFile([slotName])` | Whether a slot has a save file |
| `hasBackup([slotName])` | Whether a slot has a backup file |
| `listSaveSlots()` | List save slots, newest first (excludes backups/temp files) |
| `deleteSave([slotName])` | Delete a save file, its backup, and any temp file |
| `hasSaveFile([slotName])` | Check if save exists |
| `listSaveSlots()` | List all save slots (newest first) |
| `requestSave({metadata})` | Request a save (for event-driven saves) |
| `clearSaveRequest()` | Clear pending save request |

### SaveSlotInfo

| Property | Type | Description |
|----------|------|-------------|
| `slotName` | `String` | Slot name |
| `timestamp` | `DateTime` | When the save was created |
| `formatVersion` | `int` | Save format version |
| `metadata` | `Map<String, dynamic>` | Custom metadata (default: `{}`) |

## See Also

- [Resources Guide](/docs/guides/resources) - Working with ECS resources
- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
