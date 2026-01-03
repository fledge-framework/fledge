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
  Future<void> run(World world) {
    count++;
    return Future.value();
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

      expect(app.schedule.systemCount, equals(1));
    });

    test('addSystems adds multiple systems', () {
      final app = App()
        ..addSystems([
          CounterSystem(),
          CounterSystem(),
        ]);

      expect(app.schedule.systemCount, equals(2));
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
      final plugin = FunctionPlugin(
        (app) {},
        cleanup: () => cleaned = true,
      );

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

class _TestPluginGroup extends PluginGroup {
  @override
  final List<Plugin> plugins;

  _TestPluginGroup(this.plugins);
}
