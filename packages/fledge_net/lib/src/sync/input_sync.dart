import 'dart:collection';
import 'dart:typed_data';

import '../protocol/packet.dart';

/// Represents a single input frame.
class InputFrame {
  /// Input tick number.
  final int tick;

  /// Movement input (-1 to 1 for each axis).
  double moveX = 0;
  double moveY = 0;
  double moveZ = 0;

  /// Look input (mouse delta or stick).
  double lookX = 0;
  double lookY = 0;

  /// Button states (bit flags).
  int buttons = 0;

  /// Custom input data.
  Uint8List? customData;

  InputFrame({required this.tick});

  /// Serialize input to bytes.
  void serialize(PacketBuilder builder) {
    builder.writeInt32(tick);
    builder.writeFloat32(moveX);
    builder.writeFloat32(moveY);
    builder.writeFloat32(moveZ);
    builder.writeFloat32(lookX);
    builder.writeFloat32(lookY);
    builder.writeInt32(buttons);
    if (customData != null) {
      builder.writeBytes(customData!);
    } else {
      builder.writeInt16(0);
    }
  }

  /// Deserialize input from bytes.
  static InputFrame deserialize(PacketReader reader) {
    final frame = InputFrame(tick: reader.readInt32());
    frame.moveX = reader.readFloat32();
    frame.moveY = reader.readFloat32();
    frame.moveZ = reader.readFloat32();
    frame.lookX = reader.readFloat32();
    frame.lookY = reader.readFloat32();
    frame.buttons = reader.readInt32();
    frame.customData = reader.readBytes();
    if (frame.customData!.isEmpty) frame.customData = null;
    return frame;
  }

  /// Copy values from another frame.
  void copyFrom(InputFrame other) {
    moveX = other.moveX;
    moveY = other.moveY;
    moveZ = other.moveZ;
    lookX = other.lookX;
    lookY = other.lookY;
    buttons = other.buttons;
    customData = other.customData;
  }

  /// Check if a button is pressed.
  bool isButtonPressed(int buttonIndex) {
    return (buttons & (1 << buttonIndex)) != 0;
  }

  /// Set button state.
  void setButton(int buttonIndex, bool pressed) {
    if (pressed) {
      buttons |= (1 << buttonIndex);
    } else {
      buttons &= ~(1 << buttonIndex);
    }
  }
}

/// Common button indices.
class InputButton {
  static const int primaryAction = 0; // Left mouse / primary action
  static const int secondaryAction = 1; // Right mouse / secondary action
  static const int jump = 2;
  static const int crouch = 3;
  static const int sprint = 4;
  static const int interact = 5;
  static const int reload = 6;
  static const int pause = 7;
}

/// Buffer of input frames for client prediction.
class InputBuffer {
  final Queue<InputFrame> _frames = Queue();
  final int maxFrames;

  InputBuffer({this.maxFrames = 60});

  /// Add an input frame.
  void add(InputFrame frame) {
    _frames.addLast(frame);
    while (_frames.length > maxFrames) {
      _frames.removeFirst();
    }
  }

  /// Get frames after a specific tick.
  List<InputFrame> getFramesAfter(int tick) {
    return _frames.where((f) => f.tick > tick).toList();
  }

  /// Remove frames up to and including a tick.
  void removeUpTo(int tick) {
    while (_frames.isNotEmpty && _frames.first.tick <= tick) {
      _frames.removeFirst();
    }
  }

  /// Get the latest frame.
  InputFrame? get latest => _frames.isEmpty ? null : _frames.last;

  /// Get frame at specific tick.
  InputFrame? getFrame(int tick) {
    for (final frame in _frames) {
      if (frame.tick == tick) return frame;
    }
    return null;
  }

  /// Clear all frames.
  void clear() => _frames.clear();

  /// Number of buffered frames.
  int get length => _frames.length;
}

/// Manages client-side prediction and server reconciliation.
class ClientPrediction {
  /// Local input buffer.
  final InputBuffer inputBuffer = InputBuffer();

  /// Current local tick.
  int localTick = 0;

  /// Last acknowledged tick from server.
  int lastAckedTick = 0;

  /// Predicted state history for reconciliation.
  final Queue<_PredictedState> _stateHistory = Queue();
  final int maxStates = 60;

  /// Record local input and predicted state.
  void recordInput(InputFrame input, Map<String, dynamic> predictedState) {
    inputBuffer.add(input);
    _stateHistory.addLast(_PredictedState(
      tick: input.tick,
      state: Map.from(predictedState),
    ));
    while (_stateHistory.length > maxStates) {
      _stateHistory.removeFirst();
    }
  }

  /// Process server state update and return inputs to replay.
  List<InputFrame> reconcile(int serverTick, Map<String, dynamic> serverState) {
    lastAckedTick = serverTick;

    // Remove old states and inputs
    inputBuffer.removeUpTo(serverTick);
    while (_stateHistory.isNotEmpty && _stateHistory.first.tick <= serverTick) {
      _stateHistory.removeFirst();
    }

    // Get inputs that need to be replayed
    return inputBuffer.getFramesAfter(serverTick);
  }

  /// Get unacknowledged inputs to send to server.
  List<InputFrame> getUnackedInputs() {
    return inputBuffer.getFramesAfter(lastAckedTick);
  }

  /// Advance local tick.
  int nextTick() {
    localTick++;
    return localTick;
  }
}

class _PredictedState {
  final int tick;
  final Map<String, dynamic> state;

  _PredictedState({required this.tick, required this.state});
}

/// Server-side input queue for a client.
class ServerInputQueue {
  final Queue<InputFrame> _frames = Queue();

  /// Last processed tick.
  int lastProcessedTick = 0;

  /// Add received input frames.
  void addFrames(List<InputFrame> frames) {
    for (final frame in frames) {
      // Only add if newer than last processed
      if (frame.tick > lastProcessedTick) {
        // Check for duplicates
        if (!_frames.any((f) => f.tick == frame.tick)) {
          _frames.addLast(frame);
        }
      }
    }
  }

  /// Get next input frame to process.
  InputFrame? getNextFrame(int currentTick) {
    while (_frames.isNotEmpty) {
      final frame = _frames.first;
      if (frame.tick <= currentTick) {
        _frames.removeFirst();
        if (frame.tick > lastProcessedTick) {
          lastProcessedTick = frame.tick;
          return frame;
        }
      } else {
        break;
      }
    }
    return null;
  }

  /// Clear all frames.
  void clear() => _frames.clear();

  /// Number of queued frames.
  int get length => _frames.length;
}
