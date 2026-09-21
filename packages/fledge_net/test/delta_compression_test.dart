import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('Transform2DNetworkState delta compression', () {
    test('createDelta returns null when states are identical', () {
      final a = Transform2DNetworkState()
        ..x = 1
        ..y = 2
        ..rotation = 0.25;
      final b = Transform2DNetworkState()
        ..x = 1
        ..y = 2
        ..rotation = 0.25;

      expect(a.createDelta(b), isNull);
    });

    test('createDelta returns non-null when position changes', () {
      final current = Transform2DNetworkState()..x = 10;
      final baseline = Transform2DNetworkState()..x = 0;

      final delta = current.createDelta(baseline);
      expect(delta, isNotNull);
      expect(delta!.isNotEmpty, true);
    });

    test('only changed fields are encoded', () {
      final current = Transform2DNetworkState()
        ..x = 5
        ..y = 0
        ..rotation = 0;
      final baseline = Transform2DNetworkState();

      final delta = current.createDelta(baseline)!;

      // The delta should contain: 1 byte bitmask + 4 bytes for x only.
      // Bitmask should have only bit 0 set (x changed).
      expect(delta[0], 1); // _bitX = 1 << 0
      expect(delta.length, 1 + 4); // bitmask + one float32
    });

    test('applyDelta correctly updates only changed fields', () {
      final target = Transform2DNetworkState()
        ..x = 1
        ..y = 2
        ..rotation = 1.25;

      // Create delta from target against a default baseline.
      final baseline = Transform2DNetworkState();
      final delta = target.createDelta(baseline)!;

      // Apply delta to a fresh state.
      final restored = Transform2DNetworkState();
      restored.applyDelta(delta);

      expect(restored.x, closeTo(1, 0.01));
      expect(restored.y, closeTo(2, 0.01));
      expect(restored.rotation, closeTo(1.25, 0.01));
    });

    test('epsilon threshold ignores changes smaller than 0.001', () {
      final a = Transform2DNetworkState()..x = 1.0;
      final b = Transform2DNetworkState()..x = 1.0005; // diff < 0.001

      // The difference is below epsilon, so delta should be null.
      expect(a.createDelta(b), isNull);
    });

    test('epsilon threshold detects changes at 0.001', () {
      final a = Transform2DNetworkState()..x = 1.0;
      final b = Transform2DNetworkState()..x = 1.002; // diff > 0.001

      expect(a.createDelta(b), isNotNull);
    });

    test('full round-trip: create state A, modify to B, delta, apply', () {
      final stateA = Transform2DNetworkState()
        ..x = 10
        ..y = 20
        ..rotation = 0;

      final stateB = Transform2DNetworkState()
        ..x = 15
        ..y = 20 // unchanged
        ..rotation = 1.5;

      // Create delta: what changed from A to B.
      final delta = stateB.createDelta(stateA)!;

      // Apply delta to a copy of A.
      final restored = Transform2DNetworkState();
      restored.copyFrom(stateA);
      restored.applyDelta(delta);

      expect(restored.x, closeTo(stateB.x, 0.01));
      expect(restored.y, closeTo(stateB.y, 0.01));
      expect(restored.rotation, closeTo(stateB.rotation, 0.01));
    });
  });
}
