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

/// Simple 2D transform state for position + rotation sync.
///
/// Fledge is a 2D engine — transforms carry an (x, y) translation plus a
/// single scalar `rotation` in radians. This wire format uses three
/// float32s (12 bytes) plus an optional 1-byte delta bitmask.
///
/// Wire-format breaking change from the previous 3D `TransformNetworkState`
/// (7 floats, 28 bytes + 7-bit mask). See `PacketHeader.version`.
class Transform2DNetworkState implements NetworkState {
  /// X position, in world units.
  double x = 0;

  /// Y position, in world units.
  double y = 0;

  /// Rotation about the Z-axis, in radians.
  double rotation = 0;

  @override
  void serialize(PacketBuilder builder) {
    builder.writeFloat32(x);
    builder.writeFloat32(y);
    builder.writeFloat32(rotation);
  }

  @override
  void deserialize(PacketReader reader) {
    x = reader.readFloat32();
    y = reader.readFloat32();
    rotation = reader.readFloat32();
  }

  /// Epsilon threshold for detecting meaningful changes.
  static const double _epsilon = 0.001;

  // Bitmask field indices for delta encoding. Three bits — one per field.
  static const int _bitX = 1 << 0;
  static const int _bitY = 1 << 1;
  static const int _bitRotation = 1 << 2;

  /// All-fields mask used when creating a full-state "delta".
  static const int _allBits = _bitX | _bitY | _bitRotation;

  @override
  Uint8List? createDelta(NetworkState other) {
    if (other is! Transform2DNetworkState) {
      // Can't delta against a different type — send full state.
      final builder = PacketBuilder()..writeByte(_allBits);
      serialize(builder);
      return builder.build();
    }

    // Compare fields and build bitmask.
    int mask = 0;
    if ((x - other.x).abs() > _epsilon) mask |= _bitX;
    if ((y - other.y).abs() > _epsilon) mask |= _bitY;
    if ((rotation - other.rotation).abs() > _epsilon) mask |= _bitRotation;

    if (mask == 0) return null; // Nothing changed.

    final builder = PacketBuilder()..writeByte(mask);
    if (mask & _bitX != 0) builder.writeFloat32(x);
    if (mask & _bitY != 0) builder.writeFloat32(y);
    if (mask & _bitRotation != 0) builder.writeFloat32(rotation);
    return builder.build();
  }

  @override
  void applyDelta(Uint8List delta) {
    final reader = PacketReader(delta);
    final mask = reader.readByte();

    if (mask & _bitX != 0) x = reader.readFloat32();
    if (mask & _bitY != 0) y = reader.readFloat32();
    if (mask & _bitRotation != 0) rotation = reader.readFloat32();
  }

  /// Copy values from another state.
  void copyFrom(Transform2DNetworkState other) {
    x = other.x;
    y = other.y;
    rotation = other.rotation;
  }

  /// Linear interpolate between this and target state.
  ///
  /// Rotation is lerped as a scalar. Games that need shortest-arc angular
  /// interpolation (e.g. crossing ±π) should apply their own wrapping in
  /// their sync system before calling [lerp].
  void lerp(Transform2DNetworkState target, double t) {
    x = x + (target.x - x) * t;
    y = y + (target.y - y) * t;
    rotation = rotation + (target.rotation - rotation) * t;
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

  StateSnapshot({required this.tick, required this.state, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
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
  final StateBuffer<Transform2DNetworkState> buffer;

  /// Interpolation delay in milliseconds.
  final double interpolationDelay;

  /// Current interpolated state.
  final Transform2DNetworkState currentState = Transform2DNetworkState();

  NetworkInterpolation({int bufferSize = 30, this.interpolationDelay = 100})
    : buffer = StateBuffer(maxSnapshots: bufferSize);

  /// Add a new received state.
  void addState(int tick, Transform2DNetworkState state) {
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
    final totalDuration = after.timestamp
        .difference(before.timestamp)
        .inMilliseconds;
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
