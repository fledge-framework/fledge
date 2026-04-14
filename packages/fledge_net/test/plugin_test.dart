import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('NetworkConfig', () {
    test('defaults', () {
      final config = NetworkConfig();
      expect(config.mode, NetworkMode.offline);
      expect(config.tickRate, 60);
      expect(config.syncRate, 20);
      expect(config.interpolationDelay, 100);
    });

    test('custom values', () {
      final config = NetworkConfig(
        mode: NetworkMode.host,
        tickRate: 30,
        syncRate: 10,
        interpolationDelay: 200,
      );
      expect(config.mode, NetworkMode.host);
      expect(config.tickRate, 30);
      expect(config.syncRate, 10);
      expect(config.interpolationDelay, 200);
    });

    test('mode is mutable', () {
      final config = NetworkConfig();
      config.mode = NetworkMode.client;
      expect(config.mode, NetworkMode.client);
    });
  });

  group('NetworkTick', () {
    test('starts at zero', () {
      final tick = NetworkTick();
      expect(tick.serverTick, 0);
      expect(tick.localTick, 0);
      expect(tick.deltaTime, 0);
    });

    test('advance increments ticks and sets deltaTime', () {
      final tick = NetworkTick();
      tick.advance(60);

      expect(tick.serverTick, 1);
      expect(tick.localTick, 1);
      expect(tick.deltaTime, closeTo(1.0 / 60, 0.0001));
    });

    test('advance accumulates ticks', () {
      final tick = NetworkTick();
      tick.advance(30);
      tick.advance(30);
      tick.advance(30);

      expect(tick.serverTick, 3);
      expect(tick.localTick, 3);
      expect(tick.deltaTime, closeTo(1.0 / 30, 0.0001));
    });
  });

  group('NetworkPlugin', () {
    test('registers resources into app', () {
      final app = App();
      final plugin = NetworkPlugin();
      plugin.build(app);

      final world = app.world;
      expect(world.getResource<NetworkConfig>(), isNotNull);
      expect(world.getResource<NetworkTick>(), isNotNull);
      expect(world.getResource<NetworkEntityRegistry>(), isNotNull);
    });

    test('uses provided config', () {
      final app = App();
      final config = NetworkConfig(mode: NetworkMode.host, tickRate: 30);
      final plugin = NetworkPlugin(config: config);
      plugin.build(app);

      final retrieved = app.world.getResource<NetworkConfig>()!;
      expect(retrieved.mode, NetworkMode.host);
      expect(retrieved.tickRate, 30);
    });

    test('uses default config when none provided', () {
      final app = App();
      final plugin = NetworkPlugin();
      plugin.build(app);

      final config = app.world.getResource<NetworkConfig>()!;
      expect(config.mode, NetworkMode.offline);
      expect(config.tickRate, 60);
    });

    test('cleanup does not throw', () {
      final plugin = NetworkPlugin();
      expect(() => plugin.cleanup(), returnsNormally);
    });
  });

  group('NetworkMode', () {
    test('has three values', () {
      expect(NetworkMode.values.length, 3);
      expect(NetworkMode.values, contains(NetworkMode.offline));
      expect(NetworkMode.values, contains(NetworkMode.host));
      expect(NetworkMode.values, contains(NetworkMode.client));
    });
  });
}
