import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('InputFrame', () {
    test('defaults to zero movement and no buttons', () {
      final frame = InputFrame(tick: 1);
      expect(frame.tick, 1);
      expect(frame.moveX, 0);
      expect(frame.moveY, 0);
      expect(frame.moveZ, 0);
      expect(frame.lookX, 0);
      expect(frame.lookY, 0);
      expect(frame.buttons, 0);
      expect(frame.customData, isNull);
    });

    test('setButton and isButtonPressed', () {
      final frame = InputFrame(tick: 1);

      frame.setButton(InputButton.jump, true);
      expect(frame.isButtonPressed(InputButton.jump), true);
      expect(frame.isButtonPressed(InputButton.crouch), false);

      frame.setButton(InputButton.sprint, true);
      expect(frame.isButtonPressed(InputButton.sprint), true);
      expect(frame.isButtonPressed(InputButton.jump), true);

      frame.setButton(InputButton.jump, false);
      expect(frame.isButtonPressed(InputButton.jump), false);
      expect(frame.isButtonPressed(InputButton.sprint), true);
    });

    test('multiple buttons as bit flags', () {
      final frame = InputFrame(tick: 1);
      frame.setButton(0, true);
      frame.setButton(2, true);
      frame.setButton(4, true);

      expect(frame.buttons, (1 << 0) | (1 << 2) | (1 << 4));
    });

    test('serialize and deserialize roundtrip', () {
      final frame = InputFrame(tick: 42)
        ..moveX = 0.5
        ..moveY = -0.3
        ..moveZ = 1.0
        ..lookX = 2.5
        ..lookY = -1.0;
      frame.setButton(InputButton.jump, true);
      frame.setButton(InputButton.sprint, true);

      final builder = PacketBuilder();
      frame.serialize(builder);

      final restored = InputFrame.deserialize(PacketReader(builder.build()));
      expect(restored.tick, 42);
      expect(restored.moveX, closeTo(0.5, 0.001));
      expect(restored.moveY, closeTo(-0.3, 0.01));
      expect(restored.moveZ, closeTo(1.0, 0.001));
      expect(restored.lookX, closeTo(2.5, 0.001));
      expect(restored.lookY, closeTo(-1.0, 0.001));
      expect(restored.isButtonPressed(InputButton.jump), true);
      expect(restored.isButtonPressed(InputButton.sprint), true);
      expect(restored.isButtonPressed(InputButton.crouch), false);
      expect(restored.customData, isNull);
    });

    test('serialize and deserialize with custom data', () {
      final frame = InputFrame(tick: 1)
        ..customData = Uint8List.fromList([10, 20, 30]);

      final builder = PacketBuilder();
      frame.serialize(builder);

      final restored = InputFrame.deserialize(PacketReader(builder.build()));
      expect(restored.customData, Uint8List.fromList([10, 20, 30]));
    });

    test('copyFrom copies all values', () {
      final source = InputFrame(tick: 1)
        ..moveX = 1.0
        ..moveY = 2.0
        ..moveZ = 3.0
        ..lookX = 4.0
        ..lookY = 5.0;
      source.setButton(InputButton.jump, true);
      source.customData = Uint8List.fromList([1]);

      final dest = InputFrame(tick: 2);
      dest.copyFrom(source);

      expect(dest.moveX, 1.0);
      expect(dest.moveY, 2.0);
      expect(dest.moveZ, 3.0);
      expect(dest.lookX, 4.0);
      expect(dest.lookY, 5.0);
      expect(dest.isButtonPressed(InputButton.jump), true);
      expect(dest.customData, Uint8List.fromList([1]));
      // tick is NOT copied (it's final on dest)
      expect(dest.tick, 2);
    });
  });

  group('InputButton', () {
    test('constants are distinct', () {
      final values = [
        InputButton.primaryAction,
        InputButton.secondaryAction,
        InputButton.jump,
        InputButton.crouch,
        InputButton.sprint,
        InputButton.interact,
        InputButton.reload,
        InputButton.pause,
      ];
      expect(values.toSet().length, values.length);
    });
  });

  group('InputBuffer', () {
    test('starts empty', () {
      final buffer = InputBuffer();
      expect(buffer.length, 0);
      expect(buffer.latest, isNull);
    });

    test('add stores frames', () {
      final buffer = InputBuffer();
      buffer.add(InputFrame(tick: 1));
      buffer.add(InputFrame(tick: 2));
      expect(buffer.length, 2);
    });

    test('latest returns most recent frame', () {
      final buffer = InputBuffer();
      buffer.add(InputFrame(tick: 1)..moveX = 0.5);
      buffer.add(InputFrame(tick: 2)..moveX = 1.0);
      expect(buffer.latest!.tick, 2);
      expect(buffer.latest!.moveX, 1.0);
    });

    test('respects maxFrames', () {
      final buffer = InputBuffer(maxFrames: 3);
      for (var i = 0; i < 5; i++) {
        buffer.add(InputFrame(tick: i));
      }
      expect(buffer.length, 3);
      // Oldest frames removed
      expect(buffer.latest!.tick, 4);
    });

    test('getFrame returns frame at tick', () {
      final buffer = InputBuffer();
      buffer.add(InputFrame(tick: 5)..moveX = 0.5);
      buffer.add(InputFrame(tick: 10)..moveX = 1.0);

      expect(buffer.getFrame(5)?.moveX, 0.5);
      expect(buffer.getFrame(10)?.moveX, 1.0);
      expect(buffer.getFrame(7), isNull);
    });

    test('getFramesAfter returns newer frames', () {
      final buffer = InputBuffer();
      for (var i = 1; i <= 5; i++) {
        buffer.add(InputFrame(tick: i));
      }

      final frames = buffer.getFramesAfter(3);
      expect(frames.length, 2);
      expect(frames[0].tick, 4);
      expect(frames[1].tick, 5);
    });

    test('getFramesAfter returns empty when none match', () {
      final buffer = InputBuffer();
      buffer.add(InputFrame(tick: 1));
      buffer.add(InputFrame(tick: 2));

      expect(buffer.getFramesAfter(5), isEmpty);
    });

    test('removeUpTo removes older frames', () {
      final buffer = InputBuffer();
      for (var i = 1; i <= 5; i++) {
        buffer.add(InputFrame(tick: i));
      }

      buffer.removeUpTo(3);
      expect(buffer.length, 2);
      expect(buffer.getFrame(3), isNull);
      expect(buffer.getFrame(4)?.tick, 4);
      expect(buffer.getFrame(5)?.tick, 5);
    });

    test('clear removes all frames', () {
      final buffer = InputBuffer();
      buffer.add(InputFrame(tick: 1));
      buffer.add(InputFrame(tick: 2));

      buffer.clear();
      expect(buffer.length, 0);
      expect(buffer.latest, isNull);
    });
  });

  group('ClientPrediction', () {
    late ClientPrediction prediction;

    setUp(() {
      prediction = ClientPrediction();
    });

    test('starts at tick 0', () {
      expect(prediction.localTick, 0);
      expect(prediction.lastAckedTick, 0);
    });

    test('nextTick increments', () {
      expect(prediction.nextTick(), 1);
      expect(prediction.nextTick(), 2);
      expect(prediction.nextTick(), 3);
      expect(prediction.localTick, 3);
    });

    test('recordInput stores input and state', () {
      final input = InputFrame(tick: 1)..moveX = 1.0;
      prediction.recordInput(input, {'x': 10.0});

      expect(prediction.inputBuffer.length, 1);
      expect(prediction.inputBuffer.getFrame(1)?.moveX, 1.0);
    });

    test('getUnackedInputs returns inputs after lastAckedTick', () {
      for (var i = 1; i <= 5; i++) {
        prediction.recordInput(
          InputFrame(tick: i)..moveX = i.toDouble(),
          {'x': i * 10.0},
        );
      }

      prediction.lastAckedTick = 3;
      final unacked = prediction.getUnackedInputs();
      // getFramesAfter(3) should return ticks 4, 5
      // But lastAckedTick was just set, removeUpTo wasn't called
      // getUnackedInputs calls getFramesAfter(lastAckedTick)
      expect(unacked.length, 2);
      expect(unacked[0].tick, 4);
      expect(unacked[1].tick, 5);
    });

    test('reconcile updates lastAckedTick and returns replay inputs', () {
      for (var i = 1; i <= 5; i++) {
        prediction.recordInput(
          InputFrame(tick: i),
          {'x': i * 10.0},
        );
      }

      final replay = prediction.reconcile(3, {'x': 30.0});

      expect(prediction.lastAckedTick, 3);
      // Inputs after tick 3 should be returned for replay
      expect(replay.length, 2);
      expect(replay[0].tick, 4);
      expect(replay[1].tick, 5);
    });

    test('reconcile removes old inputs and states', () {
      for (var i = 1; i <= 5; i++) {
        prediction.recordInput(
          InputFrame(tick: i),
          {'x': i * 10.0},
        );
      }

      prediction.reconcile(3, {'x': 30.0});

      // Inputs up to tick 3 should be removed
      expect(prediction.inputBuffer.getFrame(1), isNull);
      expect(prediction.inputBuffer.getFrame(2), isNull);
      expect(prediction.inputBuffer.getFrame(3), isNull);
      expect(prediction.inputBuffer.getFrame(4), isNotNull);
      expect(prediction.inputBuffer.getFrame(5), isNotNull);
    });

    test('reconcile with no pending inputs returns empty', () {
      final replay = prediction.reconcile(0, {});
      expect(replay, isEmpty);
    });
  });

  group('ServerInputQueue', () {
    late ServerInputQueue queue;

    setUp(() {
      queue = ServerInputQueue();
    });

    test('starts empty', () {
      expect(queue.length, 0);
      expect(queue.lastProcessedTick, 0);
    });

    test('addFrames stores new frames', () {
      queue.addFrames([
        InputFrame(tick: 1),
        InputFrame(tick: 2),
        InputFrame(tick: 3),
      ]);
      expect(queue.length, 3);
    });

    test('addFrames ignores frames at or before lastProcessedTick', () {
      queue.lastProcessedTick = 5;
      queue.addFrames([
        InputFrame(tick: 3),
        InputFrame(tick: 5),
        InputFrame(tick: 6),
        InputFrame(tick: 7),
      ]);
      expect(queue.length, 2); // only 6 and 7
    });

    test('addFrames rejects duplicates', () {
      queue.addFrames([
        InputFrame(tick: 1),
        InputFrame(tick: 2),
      ]);
      queue.addFrames([
        InputFrame(tick: 2), // duplicate
        InputFrame(tick: 3),
      ]);
      expect(queue.length, 3); // 1, 2, 3
    });

    test('getNextFrame returns frames in order', () {
      queue.addFrames([
        InputFrame(tick: 1)..moveX = 1.0,
        InputFrame(tick: 2)..moveX = 2.0,
        InputFrame(tick: 3)..moveX = 3.0,
      ]);

      final f1 = queue.getNextFrame(1);
      expect(f1?.tick, 1);
      expect(f1?.moveX, 1.0);
      expect(queue.lastProcessedTick, 1);

      final f2 = queue.getNextFrame(2);
      expect(f2?.tick, 2);
      expect(queue.lastProcessedTick, 2);

      final f3 = queue.getNextFrame(3);
      expect(f3?.tick, 3);
      expect(queue.lastProcessedTick, 3);
    });

    test('getNextFrame returns null when no frames available', () {
      expect(queue.getNextFrame(1), isNull);
    });

    test('getNextFrame skips already processed ticks', () {
      queue.lastProcessedTick = 2;
      queue.addFrames([
        InputFrame(tick: 3)..moveX = 3.0,
      ]);

      // currentTick=1 won't return tick 3 (3 > 1 so it breaks)
      // Wait, let me re-read the logic...
      // getNextFrame checks if frame.tick <= currentTick
      // So with currentTick=3, it should return frame at tick 3
      final f = queue.getNextFrame(3);
      expect(f?.tick, 3);
      expect(queue.lastProcessedTick, 3);
    });

    test('getNextFrame does not return frames beyond currentTick', () {
      queue.addFrames([
        InputFrame(tick: 5),
        InputFrame(tick: 10),
      ]);

      // currentTick=3 means tick 5 and 10 are in the future
      expect(queue.getNextFrame(3), isNull);
    });

    test('clear removes all frames', () {
      queue.addFrames([InputFrame(tick: 1), InputFrame(tick: 2)]);
      queue.clear();
      expect(queue.length, 0);
    });
  });
}
