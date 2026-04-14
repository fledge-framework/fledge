import 'dart:typed_data';

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

  /// Optional server password for authentication.
  String? serverPassword;

  /// Custom authenticator callback.
  ///
  /// Called when a client connects. Return `true` to accept, `false` to reject.
  /// The [clientId] is the identifier sent by the client, and [credentials]
  /// contains any additional authentication data.
  Future<bool> Function(String clientId, Uint8List credentials)? authenticator;

  /// Whether to enable packet encryption.
  bool enableEncryption;

  /// Interest radius for spatial filtering.
  ///
  /// If null, all entities are broadcast to all clients (default).
  /// If set, only entities within this radius of a peer's owned entity
  /// are synchronized to that peer.
  double? interestRadius;

  NetworkConfig({
    this.mode = NetworkMode.offline,
    this.tickRate = 60,
    this.syncRate = 20,
    this.interpolationDelay = 100,
    this.serverPassword,
    this.authenticator,
    this.enableEncryption = false,
    this.interestRadius,
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
