import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('Transform2DNetworkState', () {
    test('defaults to origin with zero rotation', () {
      final state = Transform2DNetworkState();
      expect(state.x, 0);
      expect(state.y, 0);
      expect(state.rotation, 0);
    });

    test('serialize and deserialize roundtrip', () {
      final state = Transform2DNetworkState()
        ..x = 1.5
        ..y = 2.5
        ..rotation = 0.75;

      final builder = PacketBuilder();
      state.serialize(builder);

      final restored = Transform2DNetworkState();
      restored.deserialize(PacketReader(builder.build()));

      expect(restored.x, closeTo(1.5, 0.001));
      expect(restored.y, closeTo(2.5, 0.001));
      expect(restored.rotation, closeTo(0.75, 0.001));
    });

    test('copyFrom copies all values', () {
      final source = Transform2DNetworkState()
        ..x = 10
        ..y = 20
        ..rotation = 1.25;

      final dest = Transform2DNetworkState();
      dest.copyFrom(source);

      expect(dest.x, 10);
      expect(dest.y, 20);
      expect(dest.rotation, 1.25);
    });

    test('lerp interpolates at t=0', () {
      final a = Transform2DNetworkState()
        ..x = 0
        ..y = 0
        ..rotation = 0;
      final b = Transform2DNetworkState()
        ..x = 10
        ..y = 20
        ..rotation = 1;

      a.lerp(b, 0.0);
      expect(a.x, closeTo(0.0, 0.001));
      expect(a.y, closeTo(0.0, 0.001));
      expect(a.rotation, closeTo(0.0, 0.001));
    });

    test('lerp interpolates at t=1', () {
      final a = Transform2DNetworkState()
        ..x = 0
        ..y = 0
        ..rotation = 0;
      final b = Transform2DNetworkState()
        ..x = 10
        ..y = 20
        ..rotation = 1;

      a.lerp(b, 1.0);
      expect(a.x, closeTo(10.0, 0.001));
      expect(a.y, closeTo(20.0, 0.001));
      expect(a.rotation, closeTo(1.0, 0.001));
    });

    test('lerp interpolates at t=0.5', () {
      final a = Transform2DNetworkState()
        ..x = 0
        ..y = 0
        ..rotation = 0;
      final b = Transform2DNetworkState()
        ..x = 10
        ..y = 20
        ..rotation = 2;

      a.lerp(b, 0.5);
      expect(a.x, closeTo(5.0, 0.001));
      expect(a.y, closeTo(10.0, 0.001));
      expect(a.rotation, closeTo(1.0, 0.001));
    });

    test('createDelta returns serialized state', () {
      final state = Transform2DNetworkState()
        ..x = 5
        ..y = 10
        ..rotation = 0.5;
      final delta = state.createDelta(Transform2DNetworkState());
      expect(delta, isNotNull);
      expect(delta!.isNotEmpty, true);
    });

    test('applyDelta restores state', () {
      final original = Transform2DNetworkState()
        ..x = 7
        ..y = 14
        ..rotation = 1.5;
      final delta = original.createDelta(Transform2DNetworkState())!;

      final restored = Transform2DNetworkState();
      restored.applyDelta(delta);

      expect(restored.x, closeTo(7, 0.001));
      expect(restored.y, closeTo(14, 0.001));
      expect(restored.rotation, closeTo(1.5, 0.001));
    });
  });

  group('StateBuffer', () {
    test('starts empty', () {
      final buffer = StateBuffer<Transform2DNetworkState>();
      expect(buffer.length, 0);
      expect(buffer.latest, isNull);
    });

    test('add stores snapshots', () {
      final buffer = StateBuffer<Transform2DNetworkState>();
      buffer.add(StateSnapshot(tick: 1, state: Transform2DNetworkState()));
      buffer.add(StateSnapshot(tick: 2, state: Transform2DNetworkState()));

      expect(buffer.length, 2);
    });

    test('latest returns most recent snapshot', () {
      final buffer = StateBuffer<Transform2DNetworkState>();
      final state = Transform2DNetworkState()..x = 42;
      buffer.add(StateSnapshot(tick: 1, state: Transform2DNetworkState()));
      buffer.add(StateSnapshot(tick: 2, state: state));

      expect(buffer.latest!.tick, 2);
      expect(buffer.latest!.state.x, 42);
    });

    test('respects maxSnapshots', () {
      final buffer = StateBuffer<Transform2DNetworkState>(maxSnapshots: 3);
      for (var i = 0; i < 5; i++) {
        buffer.add(StateSnapshot(tick: i, state: Transform2DNetworkState()));
      }
      expect(buffer.length, 3);
      expect(buffer.latest!.tick, 4);
    });

    test('clear removes all snapshots', () {
      final buffer = StateBuffer<Transform2DNetworkState>();
      buffer.add(StateSnapshot(tick: 1, state: Transform2DNetworkState()));
      buffer.add(StateSnapshot(tick: 2, state: Transform2DNetworkState()));

      buffer.clear();
      expect(buffer.length, 0);
      expect(buffer.latest, isNull);
    });

    test('getInterpolationSnapshots returns null pair when empty', () {
      final buffer = StateBuffer<Transform2DNetworkState>();
      final (before, after) = buffer.getInterpolationSnapshots(DateTime.now());
      expect(before, isNull);
      expect(after, isNull);
    });

    test('getInterpolationSnapshots returns single snapshot', () {
      final buffer = StateBuffer<Transform2DNetworkState>();
      final state = Transform2DNetworkState()..x = 5;
      buffer.add(StateSnapshot(tick: 1, state: state));

      final (before, after) = buffer.getInterpolationSnapshots(DateTime.now());
      expect(before, isNotNull);
      expect(before!.state.x, 5);
      expect(after, isNull);
    });

    test('getInterpolationSnapshots finds surrounding snapshots', () {
      final buffer = StateBuffer<Transform2DNetworkState>();
      final base = DateTime.now();

      final s1 = Transform2DNetworkState()..x = 0;
      final s2 = Transform2DNetworkState()..x = 10;

      buffer.add(StateSnapshot(tick: 1, state: s1, timestamp: base));
      buffer.add(
        StateSnapshot(
          tick: 2,
          state: s2,
          timestamp: base.add(const Duration(milliseconds: 100)),
        ),
      );

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
      expect(interp.currentState.rotation, 0);
      expect(interp.interpolationDelay, 100);
    });

    test('addState populates buffer', () {
      final interp = NetworkInterpolation();
      interp.addState(1, Transform2DNetworkState()..x = 5);
      interp.addState(2, Transform2DNetworkState()..x = 10);

      expect(interp.buffer.length, 2);
    });

    test('update with no states does nothing', () {
      final interp = NetworkInterpolation();
      interp.update(DateTime.now());
      expect(interp.currentState.x, 0);
    });

    test('update extrapolates from single state', () {
      final interp = NetworkInterpolation(interpolationDelay: 0);
      final state = Transform2DNetworkState()..x = 42;
      interp.addState(1, state);

      // Update well after the snapshot
      interp.update(DateTime.now().add(const Duration(milliseconds: 200)));
      expect(interp.currentState.x, closeTo(42, 0.001));
    });

    test('configurable buffer size', () {
      final interp = NetworkInterpolation(bufferSize: 5);
      for (var i = 0; i < 10; i++) {
        interp.addState(i, Transform2DNetworkState());
      }
      expect(interp.buffer.length, 5);
    });
  });

  group('StateSnapshot', () {
    test('stores tick and state', () {
      final state = Transform2DNetworkState()..x = 99;
      final snapshot = StateSnapshot(tick: 42, state: state);
      expect(snapshot.tick, 42);
      expect(snapshot.state.x, 99);
    });

    test('auto-populates timestamp', () {
      final before = DateTime.now();
      final snapshot = StateSnapshot(tick: 1, state: Transform2DNetworkState());
      expect(
        snapshot.timestamp.isAfter(
          before.subtract(const Duration(milliseconds: 1)),
        ),
        true,
      );
    });

    test('accepts explicit timestamp', () {
      final time = DateTime(2025, 6, 15);
      final snapshot = StateSnapshot(
        tick: 1,
        state: Transform2DNetworkState(),
        timestamp: time,
      );
      expect(snapshot.timestamp, time);
    });
  });
}
