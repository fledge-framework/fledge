import 'dart:convert';
import 'dart:io';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_save/fledge_save.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Player with Saveable {
  String name;
  int gold;
  _Player({this.name = '', this.gold = 0});

  @override
  String get saveKey => 'player';

  @override
  Map<String, dynamic> toSaveJson() => {'name': name, 'gold': gold};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    name = json['name'] as String;
    gold = json['gold'] as int;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fledge_save_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  String saveDirPath() => p.join(tempDir.path, 'game');

  SaveConfig config({
    int formatVersion = 1,
    Map<int, SaveMigration> migrations = const {},
    bool keepBackup = false,
  }) => SaveConfig(
    gameDirectory: 'game',
    baseDirectory: tempDir.path,
    formatVersion: formatVersion,
    migrations: migrations,
    keepBackup: keepBackup,
  );

  /// Write a raw save file into the save directory.
  Future<void> writeRaw(String fileName, Map<String, dynamic> data) async {
    final dir = Directory(saveDirPath());
    await dir.create(recursive: true);
    await File(p.join(dir.path, fileName)).writeAsString(jsonEncode(data));
  }

  Map<String, dynamic> readRaw(String fileName) =>
      jsonDecode(File(p.join(saveDirPath(), fileName)).readAsStringSync())
          as Map<String, dynamic>;

  World worldWith(_Player player) => World()..insertResource(player);

  group('Migrations', () {
    test('applies a v1 -> v2 -> v3 chain in order', () async {
      await writeRaw('save.json', {
        'version': 1,
        'metadata': {'m': 1},
        'resources': {
          'player': {'playerName': 'Ada'},
        },
      });

      final calls = <int>[];
      final manager = SaveManager(
        config: config(
          formatVersion: 3,
          migrations: {
            1: (data) {
              calls.add(1);
              expect(data['version'], 1);
              final player =
                  (data['resources'] as Map<String, dynamic>)['player']
                      as Map<String, dynamic>;
              player['name'] = player.remove('playerName');
              return data;
            },
            2: (data) {
              calls.add(2);
              expect(data['version'], 2);
              final player =
                  (data['resources'] as Map<String, dynamic>)['player']
                      as Map<String, dynamic>;
              player['gold'] = 50;
              return data;
            },
          },
        ),
      );

      final player = _Player();
      final metadata = await manager.load(worldWith(player));

      expect(calls, [1, 2]);
      expect(metadata, {'m': 1});
      expect(player.name, 'Ada');
      expect(player.gold, 50);
    });

    test('missing step fails the load and leaves resources alone', () async {
      await writeRaw('save.json', {
        'version': 1,
        'resources': {
          'player': {'name': 'Ada', 'gold': 1},
        },
      });

      final manager = SaveManager(
        config: config(
          formatVersion: 3,
          migrations: {1: (data) => data}, // no step from 2
        ),
      );

      final player = _Player(name: 'untouched', gold: 7);
      expect(await manager.load(worldWith(player)), isNull);
      expect(player.name, 'untouched');
      expect(player.gold, 7);
    });

    test('empty migrations loads older files as-is', () async {
      await writeRaw('save.json', {
        'version': 1,
        'metadata': {'ok': true},
        'resources': {
          'player': {'name': 'Old', 'gold': 3},
        },
      });

      final manager = SaveManager(config: config(formatVersion: 4));
      final player = _Player();
      expect(await manager.load(worldWith(player)), {'ok': true});
      expect(player.name, 'Old');
      expect(player.gold, 3);
    });

    test(
      'files with no version load as-is when migrations are empty',
      () async {
        await writeRaw('save.json', {
          'metadata': {'ok': true},
          'resources': {
            'player': {'name': 'Ancient', 'gold': 1},
          },
        });

        final player = _Player();
        final manager = SaveManager(config: config(formatVersion: 2));
        expect(await manager.load(worldWith(player)), {'ok': true});
        expect(player.name, 'Ancient');
      },
    );

    test('refuses files from a newer format version', () async {
      await writeRaw('save.json', {
        'version': 5,
        'resources': {
          'player': {'name': 'Future', 'gold': 1},
        },
      });

      final manager = SaveManager(config: config(formatVersion: 2));
      final player = _Player(name: 'untouched');
      expect(await manager.load(worldWith(player)), isNull);
      expect(player.name, 'untouched');
    });
  });

  group('Backups and atomic writes', () {
    test('two saves keep current + backup with correct contents', () async {
      final player = _Player(name: 'Ada', gold: 1);
      final world = worldWith(player);
      final manager = SaveManager(config: config(keepBackup: true));

      expect(await manager.save(world), isTrue);
      expect(await manager.hasBackup(), isFalse);

      player.gold = 2;
      expect(await manager.save(world), isTrue);

      final current = readRaw('save.json');
      final backup = readRaw('save.backup.json');
      expect((current['resources'] as Map)['player'], {
        'name': 'Ada',
        'gold': 2,
      });
      expect((backup['resources'] as Map)['player'], {
        'name': 'Ada',
        'gold': 1,
      });
      expect(await manager.hasBackup(), isTrue);
      expect(File(p.join(saveDirPath(), 'save.json.tmp')).existsSync(), false);
    });

    test('no backup is written when keepBackup is false', () async {
      final world = worldWith(_Player(name: 'Ada'));
      final manager = SaveManager(config: config());

      await manager.save(world);
      await manager.save(world);

      expect(await manager.hasSaveFile(), isTrue);
      expect(await manager.hasBackup(), isFalse);
    });

    test('load(fromBackup: true) restores the previous save', () async {
      final player = _Player(name: 'Ada', gold: 1);
      final world = worldWith(player);
      final manager = SaveManager(config: config(keepBackup: true));

      await manager.save(world, metadata: {'n': 1});
      player.gold = 2;
      await manager.save(world, metadata: {'n': 2});

      player.gold = 0;
      expect(await manager.load(world, fromBackup: true), {'n': 1});
      expect(player.gold, 1);

      expect(await manager.load(world), {'n': 2});
      expect(player.gold, 2);
    });

    test(
      'load(fromBackup: true) returns null when there is no backup',
      () async {
        final world = worldWith(_Player(name: 'Ada'));
        final manager = SaveManager(config: config(keepBackup: true));
        await manager.save(world);

        expect(await manager.load(world, fromBackup: true), isNull);
      },
    );

    test('stale .tmp is ignored: current loads and it is not a slot', () async {
      await writeRaw('save.json', {
        'version': 1,
        'timestamp': DateTime(2024).toIso8601String(),
        'resources': {
          'player': {'name': 'Good', 'gold': 9},
        },
      });
      // Simulate a crash mid-write: a truncated temp file next to the save.
      await File(
        p.join(saveDirPath(), 'save.json.tmp'),
      ).writeAsString('{"version": 1, "resou');

      final manager = SaveManager(config: config(keepBackup: true));
      final player = _Player();
      expect(await manager.load(worldWith(player)), isNull); // no metadata
      expect(player.name, 'Good');
      expect(player.gold, 9);

      final slots = await manager.listSaveSlots();
      expect(slots.map((s) => s.slotName), ['save']);
    });

    test('backup files are not listed as slots', () async {
      final world = worldWith(_Player(name: 'Ada'));
      final manager = SaveManager(config: config(keepBackup: true));
      await manager.save(world, slotName: 'slot1');
      await manager.save(world, slotName: 'slot1');
      await manager.save(world, slotName: 'slot2');

      expect(await manager.hasBackup('slot1'), isTrue);
      final names = (await manager.listSaveSlots())
          .map((s) => s.slotName)
          .toSet();
      expect(names, {'slot1', 'slot2'});
    });

    test('save creates the directory without initialize()', () async {
      final manager = SaveManager(config: config());
      expect(Directory(saveDirPath()).existsSync(), isFalse);

      expect(await manager.save(worldWith(_Player(name: 'Ada'))), isTrue);
      expect(Directory(saveDirPath()).existsSync(), isTrue);
      expect(await manager.hasSaveFile(), isTrue);
      expect(manager.isInitialized, isFalse);
    });

    test('deleteSave removes current, backup and temp files', () async {
      final world = worldWith(_Player(name: 'Ada'));
      final manager = SaveManager(config: config(keepBackup: true));
      await manager.save(world);
      await manager.save(world);
      await File(p.join(saveDirPath(), 'save.json.tmp')).writeAsString('x');

      expect(await manager.deleteSave(), isTrue);
      expect(await manager.hasSaveFile(), isFalse);
      expect(await manager.hasBackup(), isFalse);
      expect(File(p.join(saveDirPath(), 'save.json.tmp')).existsSync(), false);
      expect(await manager.listSaveSlots(), isEmpty);
    });
  });
}
