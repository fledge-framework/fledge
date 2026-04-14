import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('TransformNetworkState', () {
    test('defaults to origin with identity rotation', () {
      final state = TransformNetworkState();
      expect(state.x, 0);
      expect(state.y, 0);
      expect(state.z, 0);
      expect(state.rotX, 0);
      expect(state.rotY, 0);
      expect(state.rotZ, 0);
      expect(state.rotW, 1);
    });

    test('serialize and deserialize roundtrip', () {
      final state = TransformNetworkState()
        ..x = 1.5
        ..y = 2.5
        ..z = 3.5
        ..rotX = 0.1
        ..rotY = 0.2
        ..rotZ = 0.3
        ..rotW = 0.9;

      final builder = PacketBuilder();
      state.serialize(builder);

      final restored = TransformNetworkState();
      restored.deserialize(PacketReader(builder.build()));

      expect(restored.x, closeTo(1.5, 0.001));
      expect(restored.y, closeTo(2.5, 0.001));
      expect(restored.z, closeTo(3.5, 0.001));
      expect(restored.rotX, closeTo(0.1, 0.001));
      expect(restored.rotY, closeTo(0.2, 0.001));
      expect(restored.rotZ, closeTo(0.3, 0.001));
      expect(restored.rotW, closeTo(0.9, 0.001));
    });

    test('copyFrom copies all values', () {
      final source = TransformNetworkState()
        ..x = 10
        ..y = 20
        ..z = 30
        ..rotX = 0.5
        ..rotY = 0.5
        ..rotZ = 0.5
        ..rotW = 0.5;

      final dest = TransformNetworkState();
      dest.copyFrom(source);

      expect(dest.x, 10);
      expect(dest.y, 20);
      expect(dest.z, 30);
      expect(dest.rotX, 0.5);
      expect(dest.rotY, 0.5);
      expect(dest.rotZ, 0.5);
      expect(dest.rotW, 0.5);
    });

    test('lerp interpolates at t=0', () {
      final a = TransformNetworkState()
        ..x = 0
        ..y = 0
        ..z = 0;
      final b = TransformNetworkState()
        ..x = 10
        ..y = 20
        ..z = 30;

      a.lerp(b, 0.0);
      expect(a.x, closeTo(0.0, 0.001));
      expect(a.y, closeTo(0.0, 0.001));
      expect(a.z, closeTo(0.0, 0.001));
    });

    test('lerp interpolates at t=1', () {
      final a = TransformNetworkState()
        ..x = 0
        ..y = 0
        ..z = 0;
      final b = TransformNetworkState()
        ..x = 10
        ..y = 20
        ..z = 30;

      a.lerp(b, 1.0);
      expect(a.x, closeTo(10.0, 0.001));
      expect(a.y, closeTo(20.0, 0.001));
      expect(a.z, closeTo(30.0, 0.001));
    });

    test('lerp interpolates at t=0.5', () {
      final a = TransformNetworkState()
        ..x = 0
        ..y = 0
        ..z = 0
        ..rotX = 0
        ..rotY = 0
        ..rotZ = 0
        ..rotW = 1;
      final b = TransformNetworkState()
        ..x = 10
        ..y = 20
        ..z = 30
        ..rotX = 0
        ..rotY = 0
        ..rotZ = 0
        ..rotW = 1;

      a.lerp(b, 0.5);
      expect(a.x, closeTo(5.0, 0.001));
      expect(a.y, closeTo(10.0, 0.001));
      expect(a.z, closeTo(15.0, 0.001));
    });

    test('createDelta returns serialized state', () {
      final state = TransformNetworkState()
        ..x = 5
        ..y = 10
        ..z = 15;
      final delta = state.createDelta(TransformNetworkState());
      expect(delta, isNotNull);
      expect(delta!.isNotEmpty, true);
    });

    test('applyDelta restores state', () {
      final original = TransformNetworkState()
        ..x = 7
        ..y = 14
        ..z = 21
        ..rotX = 0
        ..rotY = 0
        ..rotZ = 0
        ..rotW = 1;
      final delta = original.createDelta(TransformNetworkState())!;

      final restored = TransformNetworkState();
      restored.applyDelta(delta);

      expect(restored.x, closeTo(7, 0.001));
      expect(restored.y, closeTo(14, 0.001));
      expect(restored.z, closeTo(21, 0.001));
    });
  });

  group('StateBuffer', () {
    test('starts empty', () {
      final buffer = StateBuffer<TransformNetworkState>();
      expect(buffer.length, 0);
      expect(buffer.latest, isNull);
    });

    test('add stores snapshots', () {
      final buffer = StateBuffer<TransformNetworkState>();
      buffer.add(StateSnapshot(tick: 1, state: TransformNetworkState()));
      buffer.add(StateSnapshot(tick: 2, state: TransformNetworkState()));

      expect(buffer.length, 2);
    });

    test('latest returns most recent snapshot', () {
      final buffer = StateBuffer<TransformNetworkState>();
      final state = TransformNetworkState()..x = 42;
      buffer.add(StateSnapshot(tick: 1, state: TransformNetworkState()));
      buffer.add(StateSnapshot(tick: 2, state: state));

      expect(buffer.latest!.tick, 2);
      expect(buffer.latest!.state.x, 42);
    });

    test('respects maxSnapshots', () {
      final buffer = StateBuffer<TransformNetworkState>(maxSnapshots: 3);
      for (var i = 0; i < 5; i++) {
        buffer.add(StateSnapshot(tick: i, state: TransformNetworkState()));
      }
      expect(buffer.length, 3);
      expect(buffer.latest!.tick, 4);
    });

    test('clear removes all snapshots', () {
      final buffer = StateBuffer<TransformNetworkState>();
      buffer.add(StateSnapshot(tick: 1, state: TransformNetworkState()));
      buffer.add(StateSnapshot(tick: 2, state: TransformNetworkState()));

      buffer.clear();
      expect(buffer.length, 0);
      expect(buffer.latest, isNull);
    });

    test('getInterpolationSnapshots returns null pair when empty', () {
      final buffer = StateBuffer<TransformNetworkState>();
      final (before, after) = buffer.getInterpolationSnapshots(DateTime.now());
      expect(before, isNull);
      expect(after, isNull);
    });

    test('getInterpolationSnapshots returns single snapshot', () {
      final buffer = StateBuffer<TransformNetworkState>();
      final state = TransformNetworkState()..x = 5;
      buffer.add(StateSnapshot(tick: 1, state: state));

      final (before, after) = buffer.getInterpolationSnapshots(DateTime.now());
      expect(before, isNotNull);
      expect(before!.state.x, 5);
      expect(after, isNull);
    });

    test('getInterpolationSnapshots finds surrounding snapshots', () {
      final buffer = StateBuffer<TransformNetworkState>();
      final base = DateTime.now();

      final s1 = TransformNetworkState()..x = 0;
      final s2 = TransformNetworkState()..x = 10;

      buffer.add(StateSnapshot(
        tick: 1,
        state: s1,
        timestamp: base,
      ));
      buffer.add(StateSnapshot(
        tick: 2,
        state: s2,
        timestamp: base.add(const Duration(milliseconds: 100)),
      ));

      // Query at midpoint
      final renderTime = base.add(const Duration(milliseconds: 50));
      final (before, after) = buffer.getInterpolationSnapshots(renderTime);

      expect(before, isNotNull);
      expect(before!.state.x, 0);
      expect(after, isNotNull);
      expect(after!.state.x, 10);
    });
  });

  group('NetworkInterpolation', () {
    test('starts with default state', () {
      final interp = NetworkInterpolation();
      expect(interp.currentState.x, 0);
      expect(interp.currentState.y, 0);
      expect(interp.currentState.z, 0);
      expect(interp.interpolationDelay, 100);
    });

    test('addState populates buffer', () {
      final interp = NetworkInterpolation();
      interp.addState(1, TransformNetworkState()..x = 5);
      interp.addState(2, TransformNetworkState()..x = 10);

      expect(interp.buffer.length, 2);
    });

    test('update with no states does nothing', () {
      final interp = NetworkInterpolation();
      interp.update(DateTime.now());
      expect(interp.currentState.x, 0);
    });

    test('update extrapolates from single state', () {
      final interp = NetworkInterpolation(interpolationDelay: 0);
      final state = TransformNetworkState()..x = 42;
      interp.addState(1, state);

      // Update well after the snapshot
      interp.update(DateTime.now().add(const Duration(milliseconds: 200)));
      expect(interp.currentState.x, closeTo(42, 0.001));
    });

    test('configurable buffer size', () {
      final interp = NetworkInterpolation(bufferSize: 5);
      for (var i = 0; i < 10; i++) {
        interp.addState(i, TransformNetworkState());
      }
      expect(interp.buffer.length, 5);
    });
  });

  group('StateSnapshot', () {
    test('stores tick and state', () {
      final state = TransformNetworkState()..x = 99;
      final snapshot = StateSnapshot(tick: 42, state: state);
      expect(snapshot.tick, 42);
      expect(snapshot.state.x, 99);
    });

    test('auto-populates timestamp', () {
      final before = DateTime.now();
      final snapshot = StateSnapshot(tick: 1, state: TransformNetworkState());
      expect(
          snapshot.timestamp
              .isAfter(before.subtract(const Duration(milliseconds: 1))),
          true);
    });

    test('accepts explicit timestamp', () {
      final time = DateTime(2025, 6, 15);
      final snapshot = StateSnapshot(
        tick: 1,
        state: TransformNetworkState(),
        timestamp: time,
      );
      expect(snapshot.timestamp, time);
    });
  });
}
