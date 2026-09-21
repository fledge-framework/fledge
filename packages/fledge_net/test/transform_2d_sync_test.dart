import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// Tests specific to the Phase 8 rewrite: the 2D transform wire format
/// must be exactly 12 bytes on the wire (3 float32s) and its 3-bit delta
/// mask must only encode fields that actually changed.
void main() {
  group('Transform2DNetworkState wire format', () {
    test('serialize writes exactly 12 bytes (3 float32s)', () {
      final state = Transform2DNetworkState()
        ..x = 1.25
        ..y = -3.5
        ..rotation = 0.75;

      final builder = PacketBuilder();
      state.serialize(builder);
      final bytes = builder.build();

      // 3 float32s only — no z, no quaternion. Down from 28 bytes on the
      // old 3D wire format.
      expect(bytes.length, 12);
    });

    test('serialization is a byte-for-byte round-trip', () {
      final state = Transform2DNetworkState()
        ..x = 42.5
        ..y = -17.25
        ..rotation = 3.14;

      final builder = PacketBuilder();
      state.serialize(builder);
      final bytes = builder.build();

      final restored = Transform2DNetworkState();
      restored.deserialize(PacketReader(bytes));

      // float32 preserves ~7 significant digits; use closeTo.
      expect(restored.x, closeTo(42.5, 1e-4));
      expect(restored.y, closeTo(-17.25, 1e-4));
      expect(restored.rotation, closeTo(3.14, 1e-4));
    });
  });

  group('Transform2DNetworkState delta encoding', () {
    test('changing only x produces a 1-bit mask + one float (5 bytes)', () {
      final current = Transform2DNetworkState()
        ..x = 7
        ..y = 0
        ..rotation = 0;
      final baseline = Transform2DNetworkState();

      final delta = current.createDelta(baseline);
      expect(delta, isNotNull);
      // 1-byte bitmask + 1 float32 == 5 bytes.
      expect(delta!.length, 1 + 4);
      // Only the X bit set (bit 0).
      expect(delta[0], 1);
    });

    test('changing only y produces a 1-bit mask + one float (5 bytes)', () {
      final current = Transform2DNetworkState()
        ..x = 0
        ..y = 3.5
        ..rotation = 0;
      final baseline = Transform2DNetworkState();

      final delta = current.createDelta(baseline);
      expect(delta, isNotNull);
      expect(delta!.length, 1 + 4);
      // Only the Y bit set (bit 1).
      expect(delta[0], 1 << 1);
    });

    test('changing only rotation produces a 1-bit mask + one float', () {
      final current = Transform2DNetworkState()..rotation = 1.5;
      final baseline = Transform2DNetworkState();

      final delta = current.createDelta(baseline);
      expect(delta, isNotNull);
      expect(delta!.length, 1 + 4);
      // Only the rotation bit set (bit 2).
      expect(delta[0], 1 << 2);
    });

    test('changing all three fields produces a 3-bit mask + three floats', () {
      final current = Transform2DNetworkState()
        ..x = 1
        ..y = 2
        ..rotation = 3;
      final baseline = Transform2DNetworkState();

      final delta = current.createDelta(baseline);
      expect(delta, isNotNull);
      // 1-byte bitmask + 3 float32s == 13 bytes.
      expect(delta!.length, 1 + 3 * 4);
      // Bits X | Y | rotation == 0b111 == 7.
      expect(delta[0], 0x07);
    });

    test('identical states produce null delta', () {
      final a = Transform2DNetworkState()
        ..x = 1
        ..y = 2
        ..rotation = 0.5;
      final b = Transform2DNetworkState()
        ..x = 1
        ..y = 2
        ..rotation = 0.5;

      expect(a.createDelta(b), isNull);
    });

    test('sub-epsilon change (1e-6) is filtered to null', () {
      final a = Transform2DNetworkState()..x = 1.0;
      final b = Transform2DNetworkState()..x = 1.0 + 1e-6;

      // Below the 0.001 epsilon → treated as no change.
      expect(b.createDelta(a), isNull);
    });

    test('super-epsilon change (0.01) is encoded', () {
      final a = Transform2DNetworkState()..x = 1.0;
      final b = Transform2DNetworkState()..x = 1.01;

      // Above the 0.001 epsilon → non-null delta with only X bit set.
      final delta = b.createDelta(a);
      expect(delta, isNotNull);
      expect(delta![0], 1);
      expect(delta.length, 1 + 4);
    });

    test('applyDelta only mutates the fields present in the mask', () {
      final baseline = Transform2DNetworkState()
        ..x = 10
        ..y = 20
        ..rotation = 1.5;

      // Craft a "y changed" delta on top of the baseline.
      final withYChange = Transform2DNetworkState()
        ..x = 10 // unchanged
        ..y = 25 // changed
        ..rotation = 1.5; // unchanged
      final delta = withYChange.createDelta(baseline)!;

      // Mask should have only the Y bit set.
      expect(delta[0], 1 << 1);
      expect(delta.length, 1 + 4);

      // Apply to a fresh copy of the baseline.
      final restored = Transform2DNetworkState()..copyFrom(baseline);
      restored.applyDelta(delta);

      // X and rotation preserved from the baseline; y is the new value.
      expect(restored.x, closeTo(10, 1e-4));
      expect(restored.rotation, closeTo(1.5, 1e-4));
      expect(restored.y, closeTo(25, 1e-4));
    });

    test(
        'createDelta against a non-Transform2DNetworkState baseline sends a '
        'full snapshot', () {
      final current = Transform2DNetworkState()
        ..x = 1
        ..y = 2
        ..rotation = 3;

      final delta = current.createDelta(_UnrelatedState());
      expect(delta, isNotNull);
      // Full mask (0b111) + 3 floats.
      expect(delta![0], 0x07);
      expect(delta.length, 1 + 3 * 4);
    });
  });
}

/// A dummy [NetworkState] used solely to exercise the "different type"
/// fallback path in [Transform2DNetworkState.createDelta].
class _UnrelatedState implements NetworkState {
  @override
  void serialize(PacketBuilder builder) {}
  @override
  void deserialize(PacketReader reader) {}
  @override
  Uint8List? createDelta(NetworkState other) => null;
  @override
  void applyDelta(Uint8List delta) {}
}
