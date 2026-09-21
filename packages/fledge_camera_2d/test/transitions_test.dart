import 'dart:ui' show Color;

import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraFadeTransition', () {
    test('progress advances with WallTime.delta', () async {
      final world = World();
      final time = WallTime()..start();
      world.insertResource(time);

      final fade = CameraFadeTransition(
        duration: 1.0,
        color: const Color(0xFF000000),
      );
      world.spawn().insert(fade);

      time.delta = 0.5;
      await CameraTransitionSystem().run(world);
      expect(fade.progress, closeTo(0.5, 1e-9));
      expect(fade.isComplete, isFalse);

      time.delta = 0.6;
      await CameraTransitionSystem().run(world);
      expect(fade.isComplete, isTrue);
      expect(fade.progress, closeTo(1.0, 1e-9));
    });

    test('reverse flips progress', () {
      final fade = CameraFadeTransition(duration: 1.0, reverse: true);
      fade.elapsed = 0.25;
      expect(fade.progress, closeTo(0.25, 1e-9));
      expect(fade.effectiveProgress, closeTo(0.75, 1e-9));
    });
  });

  group('CameraWipeTransition', () {
    test('advances toward completion', () async {
      final world = World();
      world.insertResource(WallTime()..start());

      final wipe = CameraWipeTransition(
        duration: 2.0,
        direction: WipeDirection.leftToRight,
      );
      world.spawn().insert(wipe);

      world.getResource<WallTime>()!.delta = 1.0;
      await CameraTransitionSystem().run(world);
      expect(wipe.progress, closeTo(0.5, 1e-9));

      world.getResource<WallTime>()!.delta = 2.0;
      await CameraTransitionSystem().run(world);
      expect(wipe.isComplete, isTrue);
    });
  });
}
