import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_save/fledge_save.dart';
import 'package:flutter_test/flutter_test.dart';

class _Inventory with Saveable {
  final List<String> items;
  _Inventory([List<String>? items]) : items = items ?? [];

  @override
  String get saveKey => 'inventory';

  @override
  Map<String, dynamic> toSaveJson() => {'items': items};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    items
      ..clear()
      ..addAll((json['items'] as List).cast<String>());
  }
}

class _Progress with Saveable {
  int level;
  _Progress([this.level = 1]);

  @override
  String get saveKey => 'progress';

  @override
  Map<String, dynamic> toSaveJson() => {'level': level};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    level = json['level'] as int;
  }
}

class _NotSaveable {
  int x = 0;
}

/// Isolated Saveable not inserted as a world resource (tests manual path).
class _Preferences with Saveable {
  bool sound = true;

  @override
  String get saveKey => 'preferences';

  @override
  Map<String, dynamic> toSaveJson() => {'sound': sound};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    sound = json['sound'] as bool;
  }
}

void main() {
  group('Auto-discovery of Saveables', () {
    test('default SaveManager enumerates every Saveable in the world', () {
      final world = World();
      final inventory = _Inventory(['potion']);
      final progress = _Progress(5);
      world
        ..insertResource(inventory)
        ..insertResource(progress)
        ..insertResource(_NotSaveable());

      final manager = SaveManager();
      final discovered = manager.getSaveableResources(world).toList();
      expect(discovered, containsAll([inventory, progress]));
      expect(discovered.length, 2);
    });

    test(
      'SaveManagerWithSaveables merges world resources with manual ones',
      () {
        final world = World();
        final inventory = _Inventory();
        final prefs = _Preferences(); // not a world resource
        world.insertResource(inventory);

        final manual = <Saveable>[prefs];
        final manager = SaveManagerWithSaveables(
          config: const SaveConfig.defaults(),
          getSaveables: () => manual,
        );

        final discovered = manager.getSaveableResources(world).toList();
        expect(discovered, containsAll([inventory, prefs]));
        expect(discovered.length, 2);
      },
    );

    test('manual registration is deduplicated with auto-discovery', () {
      final world = World();
      final inventory = _Inventory();
      world.insertResource(inventory);

      // Explicitly register the same instance that's already in the world.
      final manager = SaveManagerWithSaveables(
        config: const SaveConfig.defaults(),
        getSaveables: () => <Saveable>[inventory],
      );

      final discovered = manager.getSaveableResources(world).toList();
      expect(discovered, [inventory]);
    });

    test(
      'SavePlugin builds a SaveManagerWithSaveables that sees world state',
      () {
        final world = World();
        final inventory = _Inventory(['sword']);
        world.insertResource(inventory);

        final plugin = SavePlugin();
        // Simulate what App.addPlugin does, without spinning up a full App.
        plugin.build(_FakeAppStub(world));

        final manager = plugin.saveManager!;
        final discovered = manager.getSaveableResources(world).toList();
        expect(discovered, [inventory]);
      },
    );

    test('round-trip through toSaveJson/loadFromSaveJson preserves state', () {
      final source = _Progress(10);
      final target = _Progress(0);
      target.loadFromSaveJson(source.toSaveJson());
      expect(target.level, 10);
    });
  });
}

/// Minimal stand-in for `App` used by `SavePlugin.build`. `SavePlugin` only
/// calls `insertResource`, so we forward that to a real World.
class _FakeAppStub implements App {
  final World _world;
  _FakeAppStub(this._world);

  @override
  World get world => _world;

  @override
  App insertResource<T>(T resource) {
    _world.insertResource(resource);
    return this;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
