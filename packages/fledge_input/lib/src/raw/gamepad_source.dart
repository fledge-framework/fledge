import 'dart:async';

import 'package:gamepads/gamepads.dart';

/// A connected gamepad as its source reports it.
class GamepadInfo {
  const GamepadInfo({
    required this.id,
    required this.name,
    this.vendorId,
    this.productId,
  });

  /// The source's opaque id for the pad; the `gamepadId` of its events.
  final String id;

  /// A user-facing, platform-dependent name ("Xbox Wireless Controller").
  final String name;

  /// The USB vendor and product ids, where the platform exposes them (not
  /// on macOS or iOS).
  final int? vendorId;
  final int? productId;

  @override
  String toString() => 'GamepadInfo($id, $name)';
}

/// Where gamepad input comes from: the `gamepads` plugin by default
/// ([PluginGamepadSource]), or a fake in tests. `InputWidget` reads it.
abstract class GamepadSource {
  /// Button and axis events, as they happen.
  Stream<GamepadEvent> get events;

  /// Pads being connected and disconnected.
  Stream<GamepadConnectionEvent> get connections;

  /// The pads connected now.
  Future<List<GamepadInfo>> list();

  /// Plays a dual-motor vibration on pad [id] (motor strengths 0 to 1).
  /// False where the pad or platform can't.
  Future<bool> rumble(
    String id, {
    double low = 0,
    double high = 0,
    Duration duration = const Duration(milliseconds: 120),
  });

  /// Stops pad [id] vibrating.
  Future<bool> stopRumble(String id);

  /// Releases whatever the source holds.
  void dispose() {}
}

/// The `gamepads` plugin as a [GamepadSource].
class PluginGamepadSource implements GamepadSource {
  /// The plugin's controller objects, kept for rumble; each listens to its
  /// pad's events, so they're disposed when replaced or no longer needed.
  final Map<String, GamepadController> _controllers = {};

  @override
  Stream<GamepadEvent> get events => Gamepads.events;

  @override
  Stream<GamepadConnectionEvent> get connections => Gamepads.connectionEvents;

  @override
  Future<List<GamepadInfo>> list() async {
    final controllers = await Gamepads.list();
    for (final old in _controllers.values) {
      unawaited(old.dispose());
    }
    _controllers
      ..clear()
      ..addEntries(controllers.map((c) => MapEntry(c.id, c)));
    return [
      for (final c in controllers)
        GamepadInfo(
          id: c.id,
          name: c.name,
          vendorId: c.vendorId,
          productId: c.productId,
        ),
    ];
  }

  @override
  Future<bool> rumble(
    String id, {
    double low = 0,
    double high = 0,
    Duration duration = const Duration(milliseconds: 120),
  }) async {
    final controller = _controllers[id];
    if (controller == null) return false;
    return controller.rumble(
      lowFrequency: low.clamp(0, 1),
      highFrequency: high.clamp(0, 1),
      duration: duration,
    );
  }

  @override
  Future<bool> stopRumble(String id) async =>
      await _controllers[id]?.stopRumble() ?? false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      unawaited(controller.dispose());
    }
    _controllers.clear();
  }
}
