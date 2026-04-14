import 'package:fledge_ecs/fledge_ecs.dart';

import 'sync/network_identity.dart';

/// Network mode.
enum NetworkMode {
  /// Single player (no networking).
  offline,

  /// This instance is the host.
  host,

  /// This instance is a client.
  client,
}

/// Network configuration resource.
class NetworkConfig {
  /// Current network mode.
  NetworkMode mode;

  /// Network tick rate (Hz).
  int tickRate;

  /// State sync rate (Hz).
  int syncRate;

  /// Interpolation delay (ms).
  double interpolationDelay;

  NetworkConfig({
    this.mode = NetworkMode.offline,
    this.tickRate = 60,
    this.syncRate = 20,
    this.interpolationDelay = 100,
  });
}

/// Current network tick resource.
class NetworkTick {
  /// Current server tick.
  int serverTick = 0;

  /// Current local tick (for prediction).
  int localTick = 0;

  /// Tick delta time in seconds.
  double deltaTime = 0;

  /// Advance ticks.
  void advance(int tickRate) {
    serverTick++;
    localTick++;
    deltaTime = 1.0 / tickRate;
  }
}

/// Plugin for network functionality.
///
/// This plugin adds:
/// - Network configuration resources
/// - Network entity registry
/// - Network tick tracking
///
/// ## Usage
///
/// ```dart
/// await App()
///   .addPlugin(NetworkPlugin())
///   .run();
/// ```
class NetworkPlugin implements Plugin {
  /// Initial network configuration.
  final NetworkConfig config;

  NetworkPlugin({
    NetworkConfig? config,
  }) : config = config ?? NetworkConfig();

  @override
  void build(App app) {
    // Add resources
    app.insertResource(config);
    app.insertResource(NetworkTick());
    app.insertResource(NetworkEntityRegistry());
  }

  @override
  void cleanup() {}
}
