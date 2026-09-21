import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class _Log {
  final List<String> entries = <String>[];
}

class _SpySystem implements System {
  final String tag;
  @override
  final SystemMeta meta;

  _SpySystem(this.tag) : meta = SystemMeta(name: 'spy:$tag');

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    world.getResource<_Log>()!.entries.add(tag);
  }
}

void main() {
  group('App lifecycle (Phase 1c)', () {
    test('startup fires once, on first tick, before Schedules.first', () async {
      final app = App()
        ..insertResource(_Log())
        ..addSystem(_SpySystem('startup'), schedule: Schedules.startup)
        ..addSystem(_SpySystem('first'), schedule: Schedules.first);

      await app.tick();
      await app.tick();
      await app.tick();

      final entries = app.world.getResource<_Log>()!.entries;
      final startupCount = entries.where((e) => e == 'startup').length;
      final firstIdx = entries.indexOf('first');
      final lastStartupIdx = entries.lastIndexOf('startup');

      expect(startupCount, equals(1),
          reason: 'startup should run exactly once');
      expect(firstIdx, isNonNegative, reason: 'first should have run');
      expect(lastStartupIdx, lessThan(firstIdx),
          reason: 'startup entry must precede every first entry');

      // Verify: entries per tick is 1 startup + 3 first entries.
      expect(entries.where((e) => e == 'first').length, equals(3));
    });

    test('extract and render fire per frame, after Schedules.last', () async {
      final app = App()
        ..insertResource(_Log())
        ..addSystem(_SpySystem('last'), schedule: Schedules.last)
        ..addSystem(_SpySystem('extract'), schedule: Schedules.extract)
        ..addSystem(_SpySystem('render'), schedule: Schedules.render);

      for (var i = 0; i < 3; i++) {
        await app.tick();
      }

      final entries = app.world.getResource<_Log>()!.entries;
      expect(entries.where((e) => e == 'last').length, equals(3));
      expect(entries.where((e) => e == 'extract').length, equals(3));
      expect(entries.where((e) => e == 'render').length, equals(3));

      // Per-frame order: last -> extract -> render, repeated.
      final pattern = <String>[
        'last',
        'extract',
        'render',
        'last',
        'extract',
        'render',
        'last',
        'extract',
        'render',
      ];
      expect(entries, equals(pattern));
    });

    test('App.runStartup is idempotent — tick 1 does not re-run startup',
        () async {
      final app = App()
        ..insertResource(_Log())
        ..addSystem(_SpySystem('startup'), schedule: Schedules.startup);

      await app.runStartup();
      expect(
        app.world.getResource<_Log>()!.entries.where((e) => e == 'startup'),
        hasLength(1),
      );

      // First tick should not re-run startup.
      await app.tick();
      await app.tick();
      expect(
        app.world.getResource<_Log>()!.entries.where((e) => e == 'startup'),
        hasLength(1),
      );

      // And a second explicit runStartup is also a no-op.
      await app.runStartup();
      expect(
        app.world.getResource<_Log>()!.entries.where((e) => e == 'startup'),
        hasLength(1),
      );
    });
  });
}
