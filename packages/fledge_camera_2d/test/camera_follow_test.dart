import 'dart:ui' show Rect, Size;

import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraFollowSystem', () {
    late World world;
    late Entity target;
    late Entity cameraEntity;

    setUp(() {
      world = World();
      target =
          (world.spawn()
                ..insert(Transform2D.from(100, 200))
                ..insert(GlobalTransform2D.identity()))
              .entity;
      // Manually set GlobalTransform2D so we don't need to run
      // TransformPropagateSystem in this focused test.
      world
          .get<GlobalTransform2D>(target)!
          .matrix
          .setValues(1, 0, 0, 0, 1, 0, 100, 200, 1);

      cameraEntity =
          (world.spawn()
                ..insert(Transform2D.from(0, 0))
                ..insert(Camera2D())
                ..insert(CameraFollow(target: target, smoothing: 0.5)))
              .entity;
    });

    test('lerps toward target with smoothing factor', () async {
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      // 0.5 * (100 - 0) = 50
      expect(t.translation.x, closeTo(50, 1e-9));
      expect(t.translation.y, closeTo(100, 1e-9));
    });

    test('converges to target within N frames', () async {
      final system = CameraFollowSystem();
      for (var i = 0; i < 40; i++) {
        await system.run(world);
      }
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, closeTo(100, 1e-3));
      expect(t.translation.y, closeTo(200, 1e-3));
    });

    test('smoothing = 1.0 snaps in a single frame', () async {
      world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 100);
      expect(t.translation.y, 200);
    });

    test('bounds keep the view inside the map', () async {
      // 200 units tall at 16:9 shows about 356 x 200 of the world.
      world.insertResource(ViewportSize(width: 1600, height: 900));
      world.get<Camera2D>(cameraEntity)!.projection = OrthographicProjection(
        viewportHeight: 200,
      );
      world.get<CameraFollow>(cameraEntity)!
        ..smoothing = 1.0
        ..bounds = const Rect.fromLTRB(0, 0, 1000, 250);
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      // x: the target at 100 is too near the left edge, so it stops at 178.
      expect(t.translation.x, closeTo(1600 / 900 * 200 / 2, 1));
      // y: 200 tall view in a 250 tall map stops at 250 - 100.
      expect(t.translation.y, closeTo(150, 1e-9));
    });

    test('bounds narrower than the view centre the camera', () async {
      world.insertResource(ViewportSize(width: 1600, height: 900));
      world.get<Camera2D>(cameraEntity)!.projection = OrthographicProjection(
        viewportHeight: 200,
      );
      world.get<CameraFollow>(cameraEntity)!
        ..smoothing = 1.0
        ..bounds = const Rect.fromLTRB(0, 0, 120, 140);
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 60);
      expect(t.translation.y, 70);
    });

    test('applies offset', () async {
      world.get<CameraFollow>(cameraEntity)!
        ..smoothing = 1.0
        ..offset = const Offset(10, -20);
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 110);
      expect(t.translation.y, 180);
    });

    test('missing target logs once and stops', () async {
      world.despawn(target);
      // First run — should log without throwing.
      await CameraFollowSystem().run(world);
      final follow = world.get<CameraFollow>(cameraEntity)!;
      expect(follow.warnedMissingTarget, isTrue);
      // Second run — should be a no-op (already warned).
      await CameraFollowSystem().run(world);
    });

    test('pixelPerfect: camera position is snapped to whole pixels', () async {
      // Target at (100.6, 200.4) — the smoothed camera position lands
      // at non-integer coordinates, which pixelPerfect must round.
      world.get<Transform2D>(target)!.translation.setValues(100.6, 200.4);
      world
          .get<GlobalTransform2D>(target)!
          .matrix
          .setValues(1, 0, 0, 0, 1, 0, 100.6, 200.4, 1);
      world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
      world.get<Camera2D>(cameraEntity)!.pixelPerfect = true;

      await CameraFollowSystem().run(world);

      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 101);
      expect(t.translation.y, 200);
    });

    test(
      'root camera also writes GlobalTransform2D so same-frame readers '
      'see the follow-updated position (regression for Batch 4 #19)',
      () async {
        world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
        // Give the camera a GlobalTransform2D at the old position so we
        // can detect it being updated.
        world.insert(cameraEntity, GlobalTransform2D.identity());
        await CameraFollowSystem().run(world);
        final g = world.get<GlobalTransform2D>(cameraEntity)!;
        // storage[6] = translationX, storage[7] = translationY.
        expect(g.matrix.storage[6], 100);
        expect(g.matrix.storage[7], 200);
      },
    );

    test(
      'root camera without a prior GlobalTransform2D gets one inserted',
      () async {
        world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
        // No GlobalTransform2D on the camera to start with.
        expect(world.get<GlobalTransform2D>(cameraEntity), isNull);
        await CameraFollowSystem().run(world);
        final g = world.get<GlobalTransform2D>(cameraEntity);
        expect(g, isNotNull);
        expect(g!.matrix.storage[6], 100);
        expect(g.matrix.storage[7], 200);
      },
    );

    test('pixelPerfect with a scaled widget view snaps to screen pixels, '
        'not world units', () async {
      world.get<Transform2D>(target)!.translation.setValues(100.6, 200.3);
      world
          .get<GlobalTransform2D>(target)!
          .matrix
          .setValues(1, 0, 0, 0, 1, 0, 100.6, 200.3, 1);
      world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
      world.get<Camera2D>(cameraEntity)!
        ..pixelPerfect = true
        ..scaleWidgetView = true
        ..projection = OrthographicProjection(viewportHeight: 540);
      // Drawn 1080 tall: 2 screen pixels per world unit.
      world.insertResource(
        ActiveCameraView()..viewportSize = const Size(1920, 1080),
      );

      await CameraFollowSystem().run(world);

      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 100.5);
      expect(t.translation.y, 200.5);
    });

    test('a scaled widget view clamps to the area it was drawn at', () async {
      world.get<Camera2D>(cameraEntity)!
        ..pixelPerfect = true
        ..scaleWidgetView = true
        ..projection = OrthographicProjection(viewportHeight: 540);
      // A 4:3 window: zoom 2 shows 800 x 600 world units. The unrelated
      // default ViewportSize (16:9) must not decide the width.
      world.insertResource(
        ActiveCameraView()..viewportSize = const Size(1600, 1200),
      );
      world.get<CameraFollow>(cameraEntity)!
        ..smoothing = 1.0
        ..bounds = const Rect.fromLTRB(0, 0, 2000, 2000);

      await CameraFollowSystem().run(world);

      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 400);
      expect(t.translation.y, 300);
    });

    test('non-pixelPerfect keeps sub-pixel positions', () async {
      world.get<Transform2D>(target)!.translation.setValues(100.6, 200.4);
      world
          .get<GlobalTransform2D>(target)!
          .matrix
          .setValues(1, 0, 0, 0, 1, 0, 100.6, 200.4, 1);
      world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
      world.get<Camera2D>(cameraEntity)!.pixelPerfect = false;

      await CameraFollowSystem().run(world);

      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, closeTo(100.6, 1e-4));
      expect(t.translation.y, closeTo(200.4, 1e-4));
    });

    /// Runs the follow for [seconds] at [hz], with a WallTime clock.
    Future<void> runFor(double seconds, double hz) async {
      final time = WallTime()..delta = 1 / hz;
      world.insertResource(time);
      final system = CameraFollowSystem();
      for (var i = 0; i < (seconds * hz).round(); i++) {
        await system.run(world);
      }
    }

    test('pixelPerfect: the catch-up eases all the way in, not stalling '
        'a pixel short', () async {
      world.get<CameraFollow>(cameraEntity)!.smoothing = 0.1;
      world.get<Camera2D>(cameraEntity)!.pixelPerfect = true;
      await runFor(3, 60);
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 100);
      expect(t.translation.y, 200);
    });

    test('pixelPerfect: the follow keeps its unrounded position', () async {
      world.get<Camera2D>(cameraEntity)!.pixelPerfect = true;
      world.get<CameraFollow>(cameraEntity)!.smoothing = 0.25;
      await CameraFollowSystem().run(world);
      final follow = world.get<CameraFollow>(cameraEntity)!;
      expect(follow.position!.dx, 25);
      // A second step works from 25, not the snapped value.
      await CameraFollowSystem().run(world);
      expect(follow.position!.dx, closeTo(25 + 75 * 0.25, 1e-9));
      expect(world.get<Transform2D>(cameraEntity)!.translation.x, 44);
    });

    test('damped follow is the same at any frame rate', () async {
      world.get<CameraFollow>(cameraEntity)!.smoothing = 0.05;
      await runFor(0.5, 60);
      final at60 = world.get<Transform2D>(cameraEntity)!.translation.x;
      world.get<Transform2D>(cameraEntity)!.translation.setValues(0, 0);
      await runFor(0.5, 144);
      final at144 = world.get<Transform2D>(cameraEntity)!.translation.x;
      expect(at60, greaterThan(50));
      expect(at60, lessThan(99));
      expect(at144, closeTo(at60, 0.01));
    });

    test('with a clock, a frame with no time passing does not move', () async {
      world.insertResource(WallTime());
      await CameraFollowSystem().run(world);
      expect(world.get<Transform2D>(cameraEntity)!.translation.x, 0);
    });

    test('smoothTime: a spring settles on the target without overshooting, '
        'the same at any frame rate', () async {
      world.get<CameraFollow>(cameraEntity)!.smoothTime = 0.3;
      final xs = <double>[];
      final time = WallTime()..delta = 1 / 60;
      world.insertResource(time);
      final system = CameraFollowSystem();
      for (var i = 0; i < 90; i++) {
        await system.run(world);
        xs.add(world.get<Transform2D>(cameraEntity)!.translation.x);
      }
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThanOrEqualTo(xs[i - 1]));
        expect(xs[i], lessThanOrEqualTo(100));
      }
      // Eases in: the first step is smaller than the next.
      expect(xs[1] - xs[0], greaterThan(xs[0]));
      expect(xs.last, closeTo(100, 0.5));

      final at60 = xs[29];
      world.get<Transform2D>(cameraEntity)!.translation.setValues(0, 0);
      await runFor(0.5, 144);
      final half144 = world.get<Transform2D>(cameraEntity)!.translation.x;
      world.get<Transform2D>(cameraEntity)!.translation.setValues(0, 0);
      await runFor(0.5, 60);
      expect(
        half144,
        closeTo(world.get<Transform2D>(cameraEntity)!.translation.x, 1),
      );
      expect(at60, lessThan(100));
    });

    test('pixelPerfect: following a steady walk, every camera step is the '
        'same size', () async {
      // A 120 units/s walk at 60 Hz: 2 units a frame, a whole number of
      // screen pixels at zoom 2.
      world.get<CameraFollow>(cameraEntity)!.smoothTime = 0.25;
      world.get<Camera2D>(cameraEntity)!
        ..pixelPerfect = true
        ..scaleWidgetView = true
        ..projection = OrthographicProjection(viewportHeight: 540);
      world.insertResource(
        ActiveCameraView()..viewportSize = const Size(1920, 1080),
      );
      world.insertResource(WallTime()..delta = 1 / 60);
      final system = CameraFollowSystem();
      final steps = <double>[];
      var x = 100.0;
      var last = 0.0;
      for (var i = 0; i < 600; i++) {
        x += 2;
        world
            .get<GlobalTransform2D>(target)!
            .matrix
            .setValues(1, 0, 0, 0, 1, 0, x, 200, 1);
        await system.run(world);
        final now = world.get<Transform2D>(cameraEntity)!.translation.x;
        steps.add(now - last);
        last = now;
      }
      // Once the spring has caught up to walking speed, all steps are 2.
      expect(steps.skip(180).toSet(), {2.0});
    });

    test('subpixelScroll: the follow leaves the camera unsnapped for the '
        'render to place', () async {
      world.get<Transform2D>(target)!.translation.setValues(100.6, 200.4);
      world
          .get<GlobalTransform2D>(target)!
          .matrix
          .setValues(1, 0, 0, 0, 1, 0, 100.6, 200.4, 1);
      world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
      world.get<Camera2D>(cameraEntity)!
        ..pixelPerfect = true
        ..subpixelScroll = true;
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, closeTo(100.6, 1e-4));
      expect(t.translation.y, closeTo(200.4, 1e-4));
    });

    test('a camera moved by something else is followed from where it is '
        'now', () async {
      world.get<CameraFollow>(cameraEntity)!.smoothing = 0.5;
      await CameraFollowSystem().run(world);
      // A transition or teleport puts the camera elsewhere.
      world.get<Transform2D>(cameraEntity)!.translation.setValues(300, 400);
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 200);
      expect(t.translation.y, 300);
    });
  });

  group('CameraFollow marker target', () {
    test('CameraFollow.marker() tracks whichever entity carries '
        'CameraFollowTarget', () async {
      final world = World();
      // Spawn a camera that has no explicit target yet.
      final cameraEntity =
          (world.spawn()
                ..insert(Transform2D.from(0, 0))
                ..insert(Camera2D())
                ..insert(CameraFollow.marker(smoothing: 1.0)))
              .entity;

      // First run — no marker anywhere. Camera stays put. In marker
      // mode the system stays silent because a target-less start-up
      // is the normal shape it exists for (Batch 6 item 27).
      await CameraFollowSystem().run(world);
      expect(world.get<Transform2D>(cameraEntity)!.translation.x, 0);
      expect(world.get<Transform2D>(cameraEntity)!.translation.y, 0);
      expect(
        world.get<CameraFollow>(cameraEntity)!.warnedMissingTarget,
        isFalse,
      );

      // Spawn a target with the marker.
      final target = world.spawn()
        ..insert(Transform2D.from(50, 75))
        ..insert(
          GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, 50, 75, 1),
        )
        ..insert(const CameraFollowTarget());
      // Un-latch the warning so the next run picks up the newly
      // spawned marker cleanly.
      world.get<CameraFollow>(cameraEntity)!.warnedMissingTarget = false;

      await CameraFollowSystem().run(world);
      expect(world.get<Transform2D>(cameraEntity)!.translation.x, 50);
      expect(world.get<Transform2D>(cameraEntity)!.translation.y, 75);
      // We used the marker entity — return-value is just to keep
      // the intent visible.
      expect(target.entity, isNotNull);
    });

    test(
      'explicit CameraFollow.target wins over the CameraFollowTarget marker',
      () async {
        final world = World();
        final explicit = world.spawn()
          ..insert(Transform2D.from(10, 20))
          ..insert(
            GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, 10, 20, 1),
          );
        world.spawn()
          ..insert(Transform2D.from(500, 500))
          ..insert(
            GlobalTransform2D()
              ..matrix.setValues(1, 0, 0, 0, 1, 0, 500, 500, 1),
          )
          ..insert(const CameraFollowTarget()); // decoy

        final cameraEntity =
            (world.spawn()
                  ..insert(Transform2D.from(0, 0))
                  ..insert(Camera2D())
                  ..insert(
                    CameraFollow(target: explicit.entity, smoothing: 1.0),
                  ))
                .entity;

        await CameraFollowSystem().run(world);
        expect(world.get<Transform2D>(cameraEntity)!.translation.x, 10);
        expect(world.get<Transform2D>(cameraEntity)!.translation.y, 20);
      },
    );
  });
}
