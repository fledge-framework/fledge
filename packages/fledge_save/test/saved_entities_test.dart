import 'dart:io';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_save/fledge_save.dart';
import 'package:flutter_test/flutter_test.dart';

class _Purse with Saveable {
  int coins = 0;

  @override
  String get saveKey => 'purse';

  @override
  Map<String, dynamic> toSaveJson() => {'coins': coins};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    coins = json['coins'] as int;
  }
}

class _Spot with Saveable {
  double x = 0;

  @override
  String get saveKey => 'spot';

  @override
  Map<String, dynamic> toSaveJson() => {'x': x};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    x = (json['x'] as num).toDouble();
  }
}

class _AlsoPurse with Saveable {
  @override
  String get saveKey => 'purse';

  @override
  Map<String, dynamic> toSaveJson() => {};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {}
}

class _Marker {
  const _Marker();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fledge_save_entities_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  SaveManager manager() {
    final manager = SaveManager(
      config: SaveConfig(gameDirectory: 'game', baseDirectory: tempDir.path),
    );
    manager.components
      ..register(_Purse.new)
      ..register(_Spot.new);
    return manager;
  }

  test('marked entities save their registered components by id', () async {
    final world = World();
    world.spawn()
      ..insert(const SaveId('player:1'))
      ..insert(_Purse()..coins = 7)
      ..insert(_Spot()..x = 3);
    world.spawn().insert(_Purse()..coins = 99); // not marked: not saved
    world.spawn()
      ..insert(const SaveId('empty'))
      ..insert(const _Marker()); // nothing registered: left out

    final data = manager().components.collect(world);
    expect(data, {
      'player:1': {
        'purse': {'coins': 7},
        'spot': {'x': 3.0},
      },
    });
  });

  test('loading updates entities in place and spawns missing ones', () async {
    final saving = World();
    saving.spawn()
      ..insert(const SaveId('player:1'))
      ..insert(_Purse()..coins = 7);
    saving.spawn()
      ..insert(const SaveId('npc:ada'))
      ..insert(_Purse()..coins = 2)
      ..insert(_Spot()..x = 5);
    final saver = manager();
    expect(await saver.save(saving), isTrue);

    final loading = World();
    final purse = _Purse();
    final player =
        (loading.spawn()
              ..insert(const SaveId('player:1'))
              ..insert(purse)
              ..insert(const _Marker()))
            .entity;
    final other = (loading.spawn()..insert(const SaveId('unsaved'))).entity;
    final loader = manager();
    await loader.load(loading);

    // Same entity, same component object, loaded in place.
    expect(identical(loading.get<_Purse>(player), purse), isTrue);
    expect(purse.coins, 7);
    expect(loading.has<_Marker>(player), isTrue);

    // A new entity for the id nobody carried, with its components created.
    expect(loader.lastSpawned, hasLength(1));
    final ada = loader.lastSpawned.single;
    expect(loading.get<SaveId>(ada), const SaveId('npc:ada'));
    expect(loading.get<_Purse>(ada)!.coins, 2);
    expect(loading.get<_Spot>(ada)!.x, 5);

    // Entities not in the save are left alone.
    expect(loading.has<SaveId>(other), isTrue);
    expect(loader.lastLoadedIds, unorderedEquals(['player:1', 'npc:ada']));
  });

  test('unregistered keys in a save are ignored', () {
    final world = World();
    final spawned = manager().components.restore(world, {
      'chest:1': {
        'purse': {'coins': 1},
        'retired': {'old': true},
      },
    });
    expect(world.get<_Purse>(spawned.single)!.coins, 1);
  });

  test('migrations can rewrite saved entities', () async {
    final world = World();
    world.spawn()
      ..insert(const SaveId('player:1'))
      ..insert(_Purse()..coins = 5);
    final v1 = manager();
    await v1.save(world);

    final v2 = SaveManager(
      config: SaveConfig(
        gameDirectory: 'game',
        baseDirectory: tempDir.path,
        formatVersion: 2,
        migrations: {
          1: (data) {
            final purse =
                ((data['entities'] as Map)['player:1'] as Map)['purse'] as Map;
            purse['coins'] = (purse['coins'] as int) * 10;
            return data;
          },
        },
      ),
    )..components.register(_Purse.new);
    final fresh = World();
    await v2.load(fresh);
    expect(fresh.get<_Purse>(v2.lastSpawned.single)!.coins, 50);
  });

  test('a save key belongs to one component type', () {
    final components = SavedComponents()..register(_Purse.new);
    components.register(_Purse.new); // the same type again is fine
    expect(() => components.register(_AlsoPurse.new), throwsArgumentError);
  });

  test('saves without registered components have no entities section', () {
    final world = World()..spawn().insert(const SaveId('x'));
    final plain = SaveManager(
      config: SaveConfig(gameDirectory: 'game', baseDirectory: tempDir.path),
    );
    expect(plain.components.isEmpty, isTrue);
    expect(plain.components.collect(world), isEmpty);
  });
}
