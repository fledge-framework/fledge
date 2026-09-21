# fledge_save

Save/load system for [Fledge](https://fledge-framework.dev) games. Resource serialization with version tracking and slot-based storage.

[![pub package](https://img.shields.io/pub/v/fledge_save.svg)](https://pub.dev/packages/fledge_save)

## Installation

```yaml
dependencies:
  fledge_save: ^0.2.1
```

## Quick Start

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

void main() async {
  final app = App()
    ..addPlugin(SavePlugin(config: SaveConfig(gameDirectory: 'MyGame')))
    ..insertResource(Inventory()); // auto-discovered as Saveable

  await app.tick();

  final saveManager = app.world.getResource<SaveManager>()!;
  await saveManager.save(app.world, slotName: 'slot1');
  await saveManager.load(app.world, slotName: 'slot1');
}
```

## Migrations and Backups

```dart
SavePlugin(
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
    keepBackup: true, // previous save kept as <slot>.backup.json
  ),
);

// Later: fall back to the previous save if the current one won't load.
await saveManager.load(world, slotName: 'slot1', fromBackup: true);
```

- Saves are written atomically (`<slot>.json.tmp`, then renamed), so a crash mid-save never truncates the current file.
- Files from a newer `formatVersion`, or with a missing migration step, are refused (`load` returns `null`) without touching resources. With no `migrations` registered, older files load as-is.
- `baseDirectory` overrides the app documents directory (useful for tests).

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/save) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
