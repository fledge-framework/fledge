# fledge_save

Save/load system for [Fledge](https://fledge-framework.dev) games. Resource serialization with version tracking and slot-based storage.

[![pub package](https://img.shields.io/pub/v/fledge_save.svg)](https://pub.dev/packages/fledge_save)

## Installation

```yaml
dependencies:
  fledge_save: ^0.2.0
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

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/save) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
