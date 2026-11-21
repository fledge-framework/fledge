import 'active_input_device.dart';

/// A vibration: the two motors' strengths (0 to 1) and how long.
class RumbleEffect {
  const RumbleEffect({
    this.low = 0,
    this.high = 0,
    this.duration = const Duration(milliseconds: 120),
  });

  /// The low-frequency (heavy) motor.
  final double low;

  /// The high-frequency (light) motor.
  final double high;

  final Duration duration;

  @override
  String toString() =>
      'RumbleEffect(low: $low, high: $high, ${duration.inMilliseconds} ms)';
}

/// Controller vibration. Systems call [play]; `InputWidget` sends it to the
/// pad (through its `GamepadSource`), fire and forget, so nothing waits on
/// the platform inside a tick.
///
/// Visibility: local (this machine's pads).
class GamepadRumble {
  GamepadRumble({this.device});

  /// Which device is in use, for [onlyWhenActive] and the default pad.
  final ActiveInputDevice? device;

  /// Off, nothing vibrates (a player setting).
  bool enabled = true;

  /// Only while a controller is the device in use: a pad lying on the desk
  /// while the player uses the keyboard stays still.
  bool onlyWhenActive = true;

  /// Sends an effect to a pad; set by `InputWidget`.
  void Function(RumbleEffect effect, String gamepadId)? handler;

  /// Stops a pad vibrating; set by `InputWidget`.
  void Function(String gamepadId)? stopHandler;

  /// The last effects played (at most [keep]), newest last: for tests and
  /// debugging.
  final List<(RumbleEffect, String?)> recent = [];
  static const keep = 16;

  /// Vibrates pad [gamepadId], or the controller in use, with [effect]
  /// (unless off, or a controller isn't in use and [onlyWhenActive]).
  void play(RumbleEffect effect, {String? gamepadId}) {
    if (!enabled) return;
    if (onlyWhenActive && !(device?.isGamepad ?? false)) return;
    final id = gamepadId ?? device?.gamepadId;
    recent.add((effect, id));
    if (recent.length > keep) recent.removeAt(0);
    if (id != null) handler?.call(effect, id);
  }

  /// Stops pad [gamepadId], or the controller in use.
  void stop({String? gamepadId}) {
    final id = gamepadId ?? device?.gamepadId;
    if (id != null) stopHandler?.call(id);
  }
}
