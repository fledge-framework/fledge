import 'dart:async';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class TestResource {
  int value;
  TestResource(this.value);
}

class TestEvent {
  final int value;
  TestEvent(this.value);
}

class CounterSystem implements System {
  int count = 0;

  @override
  SystemMeta get meta => const SystemMeta(name: 'counter');

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    count++;
  }
}

class TestPlugin implements Plugin {
  bool built = false;
  bool cleaned = false;

  @override
  void build(App app) {
    built = true;
    app.insertResource(TestResource(42));
  }

  @override
  void cleanup() {
    cleaned = true;
  }
}

void main() {
  group('App', () {
    test('addPlugin calls build', () {
      final plugin = TestPlugin();
      final app = App()..addPlugin(plugin);

      expect(plugin.built, isTrue);
      expect(app.world.hasResource<TestResource>(), isTrue);
    });

    test('addPlugins adds multiple plugins', () {
      final plugin1 = TestPlugin();
      final plugin2 = TestPlugin();

      App().addPlugins([plugin1, plugin2]);

      expect(plugin1.built, isTrue);
      expect(plugin2.built, isTrue);
    });

    test('insertResource adds to world', () {
      final app = App()..insertResource(TestResource(100));

      expect(app.world.getResource<TestResource>()!.value, equals(100));
    });

    test('addEvent registers event type', () {
      final app = App()..addEvent<TestEvent>();

      expect(app.world.events.isRegistered<TestEvent>(), isTrue);
    });

    test('addSystem adds to schedule', () {
      final system = CounterSystem();
      final app = App()..addSystem(system);

      expect(app.scheduler.systemCount, equals(1));
    });

    test('addSystems adds multiple systems', () {
      final app = App()..addSystems([CounterSystem(), CounterSystem()]);

      expect(app.scheduler.systemCount, equals(2));
    });

    test('a system timer hears every system run, with its schedule', () async {
      final system = CounterSystem();
      final app = App()..addSystem(system);
      final timings = <SystemTiming>[];
      app.scheduler.systemTimer = timings.add;
      await app.tick();
      final mine = timings.where((t) => t.system == system.meta.name);
      expect(mine, hasLength(1));
      expect(mine.single.stage, Schedules.update.name);
      expect(
        mine.single.syncMicros,
        lessThanOrEqualTo(mine.single.totalMicros),
      );
      app.scheduler.systemTimer = null;
      await app.tick();
      expect(timings.where((t) => t.system == system.meta.name), hasLength(1));
    });

    test('tick runs systems', () async {
      final system = CounterSystem();
      final app = App()..addSystem(system);

      await app.tick();

      expect(system.count, equals(1));
    });

    test('tick updates events', () async {
      final app = App()..addEvent<TestEvent>();

      app.world.eventWriter<TestEvent>().send(TestEvent(1));
      expect(app.world.eventReader<TestEvent>().isEmpty, isTrue);

      await app.tick();

      expect(app.world.eventReader<TestEvent>().isNotEmpty, isTrue);
    });

    test('onTick callback is called', () async {
      var tickCount = 0;
      final app = App()..onTick((app) => tickCount++);

      await app.tick();
      await app.tick();

      expect(tickCount, equals(2));
    });

    test('stop stops the app', () async {
      final app = App();

      var iterations = 0;
      app.onTick((app) {
        iterations++;
        if (iterations >= 3) {
          app.stop();
        }
      });

      await app.run();

      expect(iterations, equals(3));
      expect(app.isRunning, isFalse);
    });

    test('onStart and onStop callbacks', () async {
      var started = false;
      var stopped = false;

      final app = App()
        ..onStart((app) => started = true)
        ..onStop((app) => stopped = true)
        ..onTick((app) => app.stop());

      await app.run();

      expect(started, isTrue);
      expect(stopped, isTrue);
    });

    test('plugin cleanup is called on stop', () async {
      final plugin = TestPlugin();

      final app = App()
        ..addPlugin(plugin)
        ..onTick((app) => app.stop());

      await app.run();

      expect(plugin.cleaned, isTrue);
    });

    test('update runs single frame', () async {
      final system = CounterSystem();
      final app = App()..addSystem(system);

      await app.update();
      await app.update();
      await app.update();

      expect(system.count, equals(3));
    });
  });

  group('Plugin', () {
    test('FunctionPlugin executes build function', () {
      var built = false;
      final plugin = FunctionPlugin((app) {
        built = true;
      });

      App().addPlugin(plugin);

      expect(built, isTrue);
    });

    test('FunctionPlugin executes cleanup function', () {
      var cleaned = false;
      final plugin = FunctionPlugin((app) {}, cleanup: () => cleaned = true);

      plugin.cleanup();

      expect(cleaned, isTrue);
    });

    test('PluginGroup adds all plugins', () {
      final plugins = [TestPlugin(), TestPlugin()];

      final group = _TestPluginGroup(plugins);
      App().addPlugin(group);

      expect(plugins[0].built, isTrue);
      expect(plugins[1].built, isTrue);
    });

    test('PluginGroup cleanup cleans all plugins', () {
      final plugins = [TestPlugin(), TestPlugin()];
      final group = _TestPluginGroup(plugins);

      App().addPlugin(group);
      group.cleanup();

      expect(plugins[0].cleaned, isTrue);
      expect(plugins[1].cleaned, isTrue);
    });
  });

  group('PluginGroup lifecycle', () {
    test('children are built and cleaned up once when run() ends', () async {
      final log = <String>[];
      final a = _CountingPlugin('a', log);
      final b = _CountingPlugin('b', log);
      final app = App()
        ..addPlugin(_TestPluginGroup([a, b]))
        ..onTick((app) => app.stop());

      await app.run();

      expect(log, ['build a', 'build b', 'cleanup b', 'cleanup a']);
    });

    test('resetToSessionCheckpoint rebuilds each child once', () {
      final log = <String>[];
      final a = _CountingPlugin('a', log);
      final app = App()..addPlugin(_TestPluginGroup([a]));
      app.markSessionCheckpoint();

      app.resetToSessionCheckpoint();
      app.resetToSessionCheckpoint();

      expect(a.builds, 3); // initial build + one per reset
      expect(a.cleanups, 0);
      app.dispose();
      expect(a.cleanups, 1);
    });

    test('a group cleans up the instances it built', () {
      final log = <String>[];
      final group = _FreshInstancesGroup(log);
      App()
        ..addPlugin(group)
        ..dispose();

      expect(group.reads, 1);
      expect(log, ['build a', 'build b', 'cleanup b', 'cleanup a']);
    });

    test('a plugin added from a session plugin is rebuilt once on reset', () {
      final log = <String>[];
      final child = _CountingPlugin('child', log);
      final app = App()..addPlugin(_NestingPlugin(child));
      app.markSessionCheckpoint();

      app.resetToSessionCheckpoint();
      app.dispose();

      expect(child.builds, 2);
      expect(child.cleanups, 1);
    });
  });

  group('App.dispose', () {
    test('cleans up plugins once, in reverse registration order', () {
      final log = <String>[];
      final app = App()
        ..addPlugin(_CountingPlugin('a', log))
        ..addPlugin(_CountingPlugin('b', log));

      app.dispose();
      app.dispose();

      expect(log, ['build a', 'build b', 'cleanup b', 'cleanup a']);
      expect(app.isDisposed, isTrue);
    });

    test('tick, run and resetToSessionCheckpoint throw afterwards', () async {
      final app = App()..dispose();

      await expectLater(app.tick(), throwsStateError);
      await expectLater(app.run(), throwsStateError);
      expect(app.resetToSessionCheckpoint, throwsStateError);
    });

    test('run() cleans up through dispose', () async {
      final log = <String>[];
      final app = App()
        ..addPlugin(_CountingPlugin('a', log))
        ..onTick((app) => app.stop());

      await app.run();
      app.dispose();

      expect(log, ['build a', 'cleanup a']);
      expect(app.isDisposed, isTrue);
    });

    test('disposing from a system ends run() after the frame', () async {
      final log = <String>[];
      final app = App()..addPlugin(_CountingPlugin('a', log));
      var frames = 0;
      app.onTick((app) {
        if (++frames == 2) app.dispose();
      });

      await app.run();

      expect(frames, 2);
      expect(log, ['build a', 'cleanup a']);
    });
  });

  group('App.run event loop', () {
    test('timers fire while only synchronous systems run', () async {
      var timerFired = false;
      var frames = 0;
      final app = App()
        ..addSystem(CounterSystem())
        ..onTick((app) {
          frames++;
          if (timerFired || frames >= 10000) app.stop();
        });
      Timer(Duration.zero, () => timerFired = true);

      await app.run();

      expect(timerFired, isTrue);
      expect(frames, lessThan(10000));
    });
  });

  group('AppRunner', () {
    test('runFrames runs exact number of frames', () async {
      final system = CounterSystem();
      final app = App()..addSystem(system);

      final runner = AppRunner(app);
      await runner.runFrames(5);

      expect(system.count, equals(5));
    });
  });
}

class _CountingPlugin implements Plugin {
  final String id;
  final List<String> log;
  int builds = 0;
  int cleanups = 0;

  _CountingPlugin(this.id, this.log);

  @override
  void build(App app) {
    builds++;
    log.add('build $id');
  }

  @override
  void cleanup() {
    cleanups++;
    log.add('cleanup $id');
  }
}

/// Adds [child] from its own build, as DebugPlugin adds DebugStatsPlugin.
class _NestingPlugin implements Plugin {
  final Plugin child;
  _NestingPlugin(this.child);

  @override
  void build(App app) => app.addPlugin(child);

  @override
  void cleanup() {}
}

class _FreshInstancesGroup extends PluginGroup {
  final List<String> log;
  int reads = 0;
  _FreshInstancesGroup(this.log);

  @override
  List<Plugin> get plugins {
    reads++;
    return [_CountingPlugin('a', log), _CountingPlugin('b', log)];
  }
}

class _TestPluginGroup extends PluginGroup {
  @override
  final List<Plugin> plugins;

  _TestPluginGroup(this.plugins);
}
