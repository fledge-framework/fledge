import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('TransformNetworkState delta compression', () {
    test('createDelta returns null when states are identical', () {
      final a = TransformNetworkState()
        ..x = 1
        ..y = 2
        ..z = 3
        ..rotX = 0
        ..rotY = 0
        ..rotZ = 0
        ..rotW = 1;
      final b = TransformNetworkState()
        ..x = 1
        ..y = 2
        ..z = 3
        ..rotX = 0
        ..rotY = 0
        ..rotZ = 0
        ..rotW = 1;

      expect(a.createDelta(b), isNull);
    });

    test('createDelta returns non-null when position changes', () {
      final current = TransformNetworkState()..x = 10;
      final baseline = TransformNetworkState()..x = 0;

      final delta = current.createDelta(baseline);
      expect(delta, isNotNull);
      expect(delta!.isNotEmpty, true);
    });

    test('only changed fields are encoded', () {
      final current = TransformNetworkState()
        ..x = 5
        ..y = 0
        ..z = 0
        ..rotX = 0
        ..rotY = 0
        ..rotZ = 0
        ..rotW = 1;
      final baseline = TransformNetworkState(); // x=0, rotW=1

      final delta = current.createDelta(baseline)!;

      // The delta should contain: 1 byte bitmask + 4 bytes for x only.
      // Bitmask should have only bit 0 set (x changed).
      expect(delta[0], 1); // _bitX = 1 << 0
      expect(delta.length, 1 + 4); // bitmask + one float32
    });

    test('applyDelta correctly updates only changed fields', () {
      final target = TransformNetworkState()
        ..x = 1
        ..y = 2
        ..z = 3
        ..rotX = 0.1
        ..rotY = 0.2
        ..rotZ = 0.3
        ..rotW = 0.9;

      // Create delta from target against a default baseline.
      final baseline = TransformNetworkState();
      final delta = target.createDelta(baseline)!;

      // Apply delta to a fresh state.
      final restored = TransformNetworkState();
      restored.applyDelta(delta);

      expect(restored.x, closeTo(1, 0.01));
      expect(restored.y, closeTo(2, 0.01));
      expect(restored.z, closeTo(3, 0.01));
      expect(restored.rotX, closeTo(0.1, 0.01));
      expect(restored.rotY, closeTo(0.2, 0.01));
      expect(restored.rotZ, closeTo(0.3, 0.01));
      expect(restored.rotW, closeTo(0.9, 0.01));
    });

    test('epsilon threshold ignores changes smaller than 0.001', () {
      final a = TransformNetworkState()..x = 1.0;
      final b = TransformNetworkState()..x = 1.0005; // diff < 0.001

      // The difference is below epsilon, so delta should be null.
      expect(a.createDelta(b), isNull);
    });

    test('epsilon threshold detects changes at 0.001', () {
      final a = TransformNetworkState()..x = 1.0;
      final b = TransformNetworkState()..x = 1.002; // diff > 0.001

      expect(a.createDelta(b), isNotNull);
    });

    test('full round-trip: create state A, modify to B, delta, apply', () {
      final stateA = TransformNetworkState()
        ..x = 10
        ..y = 20
        ..z = 30
        ..rotX = 0
        ..rotY = 0
        ..rotZ = 0
        ..rotW = 1;

      final stateB = TransformNetworkState()
        ..x = 15
        ..y = 20
        ..z = 35
        ..rotX = 0
        ..rotY = 0.5
        ..rotZ = 0
        ..rotW = 0.866;

      // Create delta: what changed from A to B.
      final delta = stateB.createDelta(stateA)!;

      // Apply delta to a copy of A.
      final restored = TransformNetworkState();
      restored.copyFrom(stateA);
      restored.applyDelta(delta);

      expect(restored.x, closeTo(stateB.x, 0.01));
      expect(restored.y, closeTo(stateB.y, 0.01));
      expect(restored.z, closeTo(stateB.z, 0.01));
      expect(restored.rotX, closeTo(stateB.rotX, 0.01));
      expect(restored.rotY, closeTo(stateB.rotY, 0.01));
      expect(restored.rotZ, closeTo(stateB.rotZ, 0.01));
      expect(restored.rotW, closeTo(stateB.rotW, 0.01));
    });
  });
}
