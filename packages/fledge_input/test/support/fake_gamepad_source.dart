import 'dart:async';

import 'package:fledge_input/fledge_input.dart';
import 'package:gamepads/gamepads.dart';

/// A [GamepadSource] a test drives by hand.
class FakeGamepadSource implements GamepadSource {
  final events_ = StreamController<GamepadEvent>.broadcast();
  final connections_ = StreamController<GamepadConnectionEvent>.broadcast();
  List<GamepadInfo> pads = [];
  final List<(String, double, double)> rumbles = [];
  bool disposed = false;

  @override
  Stream<GamepadEvent> get events => events_.stream;

  @override
  Stream<GamepadConnectionEvent> get connections => connections_.stream;

  @override
  Future<List<GamepadInfo>> list() async => [...pads];

  @override
  Future<bool> rumble(
    String id, {
    double low = 0,
    double high = 0,
    Duration duration = const Duration(milliseconds: 120),
  }) async {
    rumbles.add((id, low, high));
    return true;
  }

  @override
  Future<bool> stopRumble(String id) async => true;

  @override
  void dispose() => disposed = true;

  void button(String pad, String key, bool down) => events_.add(
    GamepadEvent(
      gamepadId: pad,
      timestamp: 0,
      type: KeyType.button,
      key: key,
      value: down ? 1 : 0,
    ),
  );

  void axis(String pad, String key, double value) => events_.add(
    GamepadEvent(
      gamepadId: pad,
      timestamp: 0,
      type: KeyType.analog,
      key: key,
      value: value,
    ),
  );

  void connect(String pad, String name) => connections_.add(
    GamepadConnectionEvent(
      gamepadId: pad,
      name: name,
      type: GamepadConnectionEventType.connected,
    ),
  );

  void disconnect(String pad) => connections_.add(
    GamepadConnectionEvent(
      gamepadId: pad,
      name: '',
      type: GamepadConnectionEventType.disconnected,
    ),
  );
}
