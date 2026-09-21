import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VelocityIntegrationSystem', () {
    test(
      'fixed-step 60 Hz: Velocity(max 4) moves exactly 4 px per step',
      () async {
        final world = World()
          ..insertResource(FixedTimestep()); // default 60 Hz
        final entity = world.spawn()
          ..insert(Transform2D.from(0, 0))
          ..insert(Velocity(4, 0));

        const sys = VelocityIntegrationSystem.fixed();
        await sys.run(world);
        expect(world.get<Transform2D>(entity.entity)!.translation.x, 4.0);

        await sys.run(world);
        expect(world.get<Transform2D>(entity.entity)!.translation.x, 8.0);
      },
    );

    test(
      'fixed-step 30 Hz: Velocity(max 4) still produces 240 px/s',
      () async {
        // 30 Hz → 8 px/step × 30 steps = 240 px/s.
        final world = World()
          ..insertResource(
            FixedTimestep(stepDuration: const Duration(microseconds: 33333)),
          );
        final entity = world.spawn()
          ..insert(Transform2D.from(0, 0))
          ..insert(Velocity(4, 0));

        const sys = VelocityIntegrationSystem.fixed();
        await sys.run(world);
        expect(
          world.get<Transform2D>(entity.entity)!.translation.x,
          closeTo(8.0, 0.01),
        );
      },
    );

    test('fixed-step 120 Hz: Velocity(max 4) → 2 px/step (240 px/s)', () async {
      final world = World()
        ..insertResource(
          FixedTimestep(stepDuration: const Duration(microseconds: 8333)),
        );
      final entity = world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(Velocity(4, 0));

      const sys = VelocityIntegrationSystem.fixed();
      await sys.run(world);
      expect(
        world.get<Transform2D>(entity.entity)!.translation.x,
        closeTo(2.0, 0.01),
      );
    });

    test('variable mode reads WallTime.delta at 60 Hz reference', () async {
      final world = World()..insertResource(WallTime());
      world.getResource<WallTime>()!.delta = 1 / 60;
      final entity = world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(Velocity(4, 0));

      const sys = VelocityIntegrationSystem();
      await sys.run(world);
      expect(
        world.get<Transform2D>(entity.entity)!.translation.x,
        closeTo(4.0, 0.001),
      );
    });

    test('stationary bodies are not moved', () async {
      final world = World()..insertResource(FixedTimestep());
      final entity = world.spawn()
        ..insert(Transform2D.from(10, 10))
        ..insert(Velocity(0, 0));

      const sys = VelocityIntegrationSystem.fixed();
      await sys.run(world);
      final t = world.get<Transform2D>(entity.entity)!;
      expect(t.translation.x, 10.0);
      expect(t.translation.y, 10.0);
    });

    test('unnormalized diagonals preserved (no auto-normalization)', () async {
      // Porios feel-lock: diagonals move by (v, v), not (v/sqrt(2), v/sqrt(2)).
      final world = World()..insertResource(FixedTimestep());
      final entity = world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(Velocity(4, 4));

      const sys = VelocityIntegrationSystem.fixed();
      await sys.run(world);
      final t = world.get<Transform2D>(entity.entity)!;
      expect(t.translation.x, 4.0);
      expect(t.translation.y, 4.0);
    });
  });

  group('CollisionResolutionSystem — fixed mode', () {
    test('reads FixedTimestep and blocks movement into a wall', () async {
      final world = World()..insertResource(FixedTimestep());
      // Wall to the right of origin.
      world.spawn()
        ..insert(Transform2D.from(10, 0))
        ..insert(
          Collider.single(
            const RectangleShape(x: 0, y: 0, width: 10, height: 10),
          ),
        );
      final player = world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(
          Collider.single(
            const RectangleShape(x: 0, y: 0, width: 10, height: 10),
          ),
        )
        ..insert(Velocity(4, 0));

      const sys = CollisionResolutionSystem.fixed();
      await sys.run(world);

      // 4 px movement would land player's right edge at 14, overlapping
      // wall from 10..20. Full move blocked, no valid axis slide → both
      // components stay zero after resolution's velocity.reset().
      final v = world.get<Velocity>(player.entity)!;
      expect(v.x, 0);
      expect(v.y, 0);
    });

    test('axis-by-axis sliding preserved (Porios feel lock)', () async {
      final world = World()..insertResource(FixedTimestep());
      // Wall directly below entity, no wall to the right.
      world.spawn()
        ..insert(Transform2D.from(0, 5))
        ..insert(
          Collider.single(
            const RectangleShape(x: 0, y: 0, width: 100, height: 10),
          ),
        );
      final player = world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(
          Collider.single(
            const RectangleShape(x: 0, y: 0, width: 4, height: 4),
          ),
        )
        // Diagonal SE movement: X should slide, Y should get zeroed.
        ..insert(Velocity(4, 4));

      const sys = CollisionResolutionSystem.fixed();
      await sys.run(world);

      final v = world.get<Velocity>(player.entity)!;
      expect(v.x, 4.0);
      expect(v.y, 0.0);
    });
  });

  group('PhysicsPlugin fixed-mode scheduling', () {
    test('systems land in Schedules.fixedUpdate under PhysicsMode.fixed', () {
      final app = App()
        ..addPlugin(
          const PhysicsPlugin(config: PhysicsConfig(mode: PhysicsMode.fixed)),
        );
      // No ordering ambiguities inside fixedUpdate.
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty);
    });

    test('variable-mode plugin still works', () {
      final app = App()..addPlugin(const PhysicsPlugin());
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty);
    });
  });
}
