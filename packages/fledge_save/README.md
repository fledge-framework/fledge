# fledge_save

Save/load system for [Fledge](https://fledge-framework.dev) games. Resource serialization with version migration support.

[![pub package](https://img.shields.io/pub/v/fledge_save.svg)](https://pub.dev/packages/fledge_save)

## Features

- **Saveable Mixin**: Resources implement `Saveable` to participate in saves
- **Automatic Discovery**: SaveManager finds and serializes all registered saveables
- **Version Migration**: Track save format versions for backwards compatibility
- **Request Pattern**: ECS systems request saves, Flutter layer processes them
- **Slot-Based Storage**: Multiple save slots with timestamps and metadata

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
      saveables: [Inventory()],
    ));

  await app.tick();

  // 3. Save/load
  final saveManager = app.world.getResource<SaveManager>()!;
  await saveManager.save(app.world, 'slot1');
  await saveManager.load(app.world, 'slot1');
}
```

## The Saveable Mixin

Resources implement `Saveable` to be included in saves:

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

## Request-Based Saving

For event-driven saves (checkpoints, sleeping, etc.):

```dart
// In ECS systems - request a save
@system
void checkpointSystem(World world) {
  final saveManager = world.getResource<SaveManager>();
  if (reachedCheckpoint) {
    saveManager?.requestSave(metadata: {
      'checkpoint': 'forest_entrance',
    });
  }
}

// In Flutter layer - process requests
void gameLoop() {
  app.tick();

  final saveManager = app.world.getResource<SaveManager>()!;
  if (saveManager.saveRequested) {
    final metadata = saveManager.pendingMetadata;
    saveManager.clearSaveRequest();
    saveManager.save(app.world, 'autosave', metadata: metadata);
  }
}
```

## Save File Format

```json
{
  "version": 1,
  "timestamp": "2024-01-15T10:30:00Z",
  "metadata": {
    "playerX": 100,
    "playerY": 200
  },
  "resources": {
    "inventory": { "items": ["sword", "potion"] },
    "progress": { "level": 5, "experience": 1250 }
  }
}
```

## Documentation

See the [Save System Guide](https://fledge-framework.dev/docs/plugins/save) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_time](https://pub.dev/packages/fledge_time) - Game calendar/time system

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
