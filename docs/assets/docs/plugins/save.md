# Save System

The `fledge_save` package provides a save/load system for persisting game state. It features automatic resource discovery via the `Saveable` mixin, file-based storage with versioning, and an optional auto-save system.

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
    .addPlugin(SavePlugin(
      config: SaveConfig(saveDirectory: 'MyGame'),
      saveables: [Inventory()],  // Register saveable resources
    ));

  await app.tick();

  // Save the game
  final saveManager = app.world.getResource<SaveManager>()!;
  await saveManager.save(app.world, 'slot1');

  // Load the game
  await saveManager.load(app.world, 'slot1');
}
```

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
  saveDirectory: 'MyGame',  // Subdirectory in app documents
  formatVersion: 1,         // Increment for breaking changes
  compressSaves: false,     // Optional gzip compression
)
```

### Version Migration

The `formatVersion` helps manage breaking changes:

```dart
// When loading, check version and migrate if needed
if (saveData['version'] < currentVersion) {
  saveData = migrateSaveData(saveData);
}
```

## SaveManager

The `SaveManager` resource handles file I/O and coordinates saves across resources.

### Checking for Save Files

```dart
final saveManager = world.getResource<SaveManager>()!;

// Check if a specific slot has a save
final hasSave = await saveManager.hasSaveFile('slot1');

// List all save slots
final slots = await saveManager.listSaveSlots();
for (final slot in slots) {
  print('${slot.name}: saved ${slot.timestamp}');
}
```

### Saving

```dart
// Basic save
final success = await saveManager.save(world, 'slot1');

// Save with metadata (e.g., player location, screenshot path)
final success = await saveManager.save(
  world,
  'slot1',
  metadata: {
    'playerX': 100,
    'playerY': 200,
    'mapId': 'forest',
  },
);
```

### Loading

```dart
final success = await saveManager.load(world, 'slot1');

if (success) {
  // Resources have been restored
  final inventory = world.getResource<Inventory>()!;
  print('Loaded ${inventory.items.length} items');
}
```

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
    saveManager.requestSave(additionalData: {
      'checkpoint': 'forest_entrance',
    });
  }
}

// In your Flutter layer - process save requests
void gameLoop() {
  app.tick();

  final saveManager = app.world.getResource<SaveManager>()!;
  if (saveManager.saveRequested) {
    final data = saveManager.pendingSaveData;
    saveManager.clearSaveRequest();

    // Perform async save
    saveManager.save(app.world, 'autosave', metadata: data);
  }
}
```

## Save File Format

Save files are stored as JSON in the application documents directory:

```
Documents/
  MyGame/
    saves/
      slot1.json
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
  "inventory": {
    "items": ["sword", "shield", "potion"]
  },
  "progress": {
    "level": 5,
    "experience": 1250,
    "completedQuests": ["intro", "forest_rescue"]
  }
}
```

## SavePlugin

The `SavePlugin` sets up the save system:

```dart
App()
  .addPlugin(SavePlugin(
    config: SaveConfig(
      saveDirectory: 'MyGame',
      formatVersion: 1,
    ),
    saveables: [
      PlayerProgress(),
      Inventory(),
      Settings(),
    ],
  ));
```

### Custom SaveManager

For games needing custom save logic (e.g., cloud saves), extend `SaveManager`:

```dart
class CloudSaveManager extends SaveManager {
  CloudSaveManager(super.config);

  @override
  Future<bool> save(World world, String slotName, {Map<String, dynamic>? metadata}) async {
    // Save locally first
    final success = await super.save(world, slotName, metadata: metadata);

    // Then sync to cloud
    if (success) {
      await uploadToCloud(slotName);
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
// In your game, track format changes
const saveFormatVersion = 2;

// Document breaking changes
// v1: Initial format
// v2: Added 'prestigePoints' to progress, renamed 'coins' to 'gold'
```

## API Reference

### SaveConfig

| Property | Type | Description |
|----------|------|-------------|
| `saveDirectory` | `String` | Subdirectory for saves (default: 'saves') |
| `formatVersion` | `int` | Save format version for migration |
| `compressSaves` | `bool` | Enable gzip compression |

### SaveManager

| Method | Description |
|--------|-------------|
| `save(world, slotName, {metadata})` | Save game state to a slot |
| `load(world, slotName)` | Load game state from a slot |
| `deleteSave(slotName)` | Delete a save file |
| `hasSaveFile(slotName)` | Check if save exists |
| `listSaveSlots()` | List all save slots |
| `requestSave({additionalData})` | Request a save (for event-driven saves) |
| `clearSaveRequest()` | Clear pending save request |

### SaveSlotInfo

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Slot name |
| `timestamp` | `DateTime` | When the save was created |
| `metadata` | `Map<String, dynamic>?` | Custom metadata |

## See Also

- [Resources Guide](/docs/guides/resources) - Working with ECS resources
- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
