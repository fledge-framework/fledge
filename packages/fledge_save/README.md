# fledge_save

Save/load system for [Fledge](https://fledge-framework.dev) games. Resource serialization with version tracking and slot-based storage.

[![pub package](https://img.shields.io/pub/v/fledge_save.svg)](https://pub.dev/packages/fledge_save)

## Installation

```yaml
dependencies:
  fledge_save: ^0.6.0
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

## Saving Entities

Per-entity state (players, NPCs, placed objects) lives in components, not resources. Mark the entity with a stable `SaveId` and register the component types once; every marked entity then has those components saved under its id, in the file's `entities` section.

```dart
class Health with Saveable {
  int hp = 10;

  @override
  String get saveKey => 'health';

  @override
  Map<String, dynamic> toSaveJson() => {'hp': hp};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) => hp = json['hp'] as int;
}

final saveManager = app.world.getResource<SaveManager>()!;
saveManager.components
  ..register(Inventory.new)
  ..register(Health.new);

app.world.spawn()
  ..insert(const SaveId('player:1'))
  ..insert(Inventory())
  ..insert(Health());
```

On load, an entity already carrying the same `SaveId` is updated in place (its other components are kept); a saved id nobody carries is spawned, with its components created from the registered constructors. `saveManager.lastSpawned` lists those new entities so the game can attach what isn't saved (sprites, colliders). Entities whose ids aren't in the save are left alone. Migrations see the `entities` section like any other part of the file.

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

## Preferences

Settings that belong to the machine rather than a save (volume, keys, display) go in a `PreferencesFile`: plain JSON beside the saves, written atomically, readable before any save is loaded. A missing or broken file reads as `null`, so the game falls back to defaults.

```dart
final prefs = PreferencesFile(gameDirectory: 'MyGame'); // MyGame/settings.json
final data = await prefs.read() ?? {};
await prefs.write({...data, 'music': 0.6});
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/gameplay/save) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
