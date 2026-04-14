import 'dart:typed_data';

import '../protocol/packet.dart';

/// Serializable state for network synchronization.
abstract class NetworkState {
  /// Serialize state to bytes.
  void serialize(PacketBuilder builder);

  /// Deserialize state from bytes.
  void deserialize(PacketReader reader);

  /// Create a delta from this state to another.
  Uint8List? createDelta(NetworkState other);

  /// Apply a delta to update this state.
  void applyDelta(Uint8List delta);
}

/// Simple transform state for position/rotation sync.
class TransformNetworkState implements NetworkState {
  double x = 0;
  double y = 0;
  double z = 0;
  double rotX = 0;
  double rotY = 0;
  double rotZ = 0;
  double rotW = 1;

  @override
  void serialize(PacketBuilder builder) {
    builder.writeFloat32(x);
    builder.writeFloat32(y);
    builder.writeFloat32(z);
    builder.writeFloat32(rotX);
    builder.writeFloat32(rotY);
    builder.writeFloat32(rotZ);
    builder.writeFloat32(rotW);
  }

  @override
  void deserialize(PacketReader reader) {
    x = reader.readFloat32();
    y = reader.readFloat32();
    z = reader.readFloat32();
    rotX = reader.readFloat32();
    rotY = reader.readFloat32();
    rotZ = reader.readFloat32();
    rotW = reader.readFloat32();
  }

  @override
  Uint8List? createDelta(NetworkState other) {
    // Full state for now (no delta compression)
    final builder = PacketBuilder();
    serialize(builder);
    return builder.build();
  }

  @override
  void applyDelta(Uint8List delta) {
    deserialize(PacketReader(delta));
  }

  /// Copy values from another state.
  void copyFrom(TransformNetworkState other) {
    x = other.x;
    y = other.y;
    z = other.z;
    rotX = other.rotX;
    rotY = other.rotY;
    rotZ = other.rotZ;
    rotW = other.rotW;
  }

  /// Linear interpolate between this and target state.
  void lerp(TransformNetworkState target, double t) {
    x = x + (target.x - x) * t;
    y = y + (target.y - y) * t;
    z = z + (target.z - z) * t;
    // Simple quaternion lerp (not slerp for performance)
    rotX = rotX + (target.rotX - rotX) * t;
    rotY = rotY + (target.rotY - rotY) * t;
    rotZ = rotZ + (target.rotZ - rotZ) * t;
    rotW = rotW + (target.rotW - rotW) * t;
    // Normalize quaternion
    final len = (rotX * rotX + rotY * rotY + rotZ * rotZ + rotW * rotW);
    if (len > 0) {
      final invLen = 1.0 / len;
      rotX *= invLen;
      rotY *= invLen;
      rotZ *= invLen;
      rotW *= invLen;
    }
  }
}

/// Snapshot of entity state at a specific time.
class StateSnapshot<T extends NetworkState> {
  /// Network tick this snapshot was taken.
  final int tick;

  /// Timestamp of the snapshot.
  final DateTime timestamp;

  /// The state data.
  final T state;

  StateSnapshot({
    required this.tick,
    required this.state,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Buffer of recent state snapshots for interpolation.
class StateBuffer<T extends NetworkState> {
  final List<StateSnapshot<T>> _snapshots = [];
  final int maxSnapshots;

  StateBuffer({this.maxSnapshots = 30});

  /// Add a new snapshot.
  void add(StateSnapshot<T> snapshot) {
    _snapshots.add(snapshot);
    while (_snapshots.length > maxSnapshots) {
      _snapshots.removeAt(0);
    }
  }

  /// Get snapshots surrounding a render time.
  (StateSnapshot<T>?, StateSnapshot<T>?) getInterpolationSnapshots(
    DateTime renderTime,
  ) {
    if (_snapshots.isEmpty) return (null, null);
    if (_snapshots.length == 1) return (_snapshots[0], null);

    // Find surrounding snapshots
    StateSnapshot<T>? before;
    StateSnapshot<T>? after;

    for (var i = 0; i < _snapshots.length; i++) {
      if (_snapshots[i].timestamp.isAfter(renderTime)) {
        after = _snapshots[i];
        if (i > 0) before = _snapshots[i - 1];
        break;
      }
      before = _snapshots[i];
    }

    return (before, after);
  }

  /// Get latest snapshot.
  StateSnapshot<T>? get latest => _snapshots.isEmpty ? null : _snapshots.last;

  /// Clear all snapshots.
  void clear() => _snapshots.clear();

  /// Number of snapshots in buffer.
  int get length => _snapshots.length;
}

/// Component for interpolating remote entity state.
class NetworkInterpolation {
  /// State buffer for interpolation.
  final StateBuffer<TransformNetworkState> buffer;

  /// Interpolation delay in milliseconds.
  final double interpolationDelay;

  /// Current interpolated state.
  final TransformNetworkState currentState = TransformNetworkState();

  NetworkInterpolation({
    int bufferSize = 30,
    this.interpolationDelay = 100,
  }) : buffer = StateBuffer(maxSnapshots: bufferSize);

  /// Add a new received state.
  void addState(int tick, TransformNetworkState state) {
    buffer.add(StateSnapshot(tick: tick, state: state));
  }

  /// Update interpolation for current render time.
  void update(DateTime now) {
    final renderTime = now.subtract(
      Duration(milliseconds: interpolationDelay.toInt()),
    );

    final (before, after) = buffer.getInterpolationSnapshots(renderTime);

    if (before == null) return;

    if (after == null) {
      // Extrapolate from last known state
      currentState.copyFrom(before.state);
      return;
    }

    // Interpolate between snapshots
    final totalDuration =
        after.timestamp.difference(before.timestamp).inMilliseconds;
    if (totalDuration <= 0) {
      currentState.copyFrom(after.state);
      return;
    }

    final elapsed = renderTime.difference(before.timestamp).inMilliseconds;
    final t = (elapsed / totalDuration).clamp(0.0, 1.0);

    currentState.copyFrom(before.state);
    currentState.lerp(after.state, t);
  }
}
