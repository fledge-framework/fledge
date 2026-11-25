import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RectangleShape.bounds', () {
    test('a 10x10 square turned 45 degrees is about 14.14 across', () {
      final b = const RectangleShape(
        x: 0,
        y: 0,
        width: 10,
        height: 10,
        rotation: 45,
      ).bounds;
      expect(b.width, closeTo(10 * math.sqrt2, 1e-9));
      expect(b.height, closeTo(10 * math.sqrt2, 1e-9));
    });

    test('turns clockwise about the top-left corner, as Tiled does', () {
      final b = const RectangleShape(
        x: 100,
        y: 50,
        width: 20,
        height: 10,
        rotation: 90,
      ).bounds;
      expect(b.left, closeTo(90, 1e-9));
      expect(b.top, closeTo(50, 1e-9));
      expect(b.right, closeTo(100, 1e-9));
      expect(b.bottom, closeTo(70, 1e-9));
    });

    test('unrotated is the rectangle itself', () {
      final b = const RectangleShape(x: 1, y: 2, width: 3, height: 4).bounds;
      expect((b.left, b.top, b.width, b.height), (1.0, 2.0, 3.0, 4.0));
    });
  });

  group('Velocity.max', () {
    (double, double) step(Velocity velocity) {
      final world = World()..insertResource(FixedTimestep()); // 60 Hz
      final entity = world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(velocity);
      const VelocityIntegrationSystem.fixed().run(world);
      final t = world.get<Transform2D>(entity.entity)!.translation;
      return (t.x, t.y);
    }

    test('is a setting, not a cap: velocity is applied as set', () {
      expect(step(Velocity(10, 0, 4)), (10.0, 0.0));
      expect(Velocity.stationary().max, 4);
    });

    test('velocity scales with the step (30 Hz)', () {
      final world = World()
        ..insertResource(
          FixedTimestep(stepDuration: const Duration(microseconds: 33333)),
        );
      final entity = world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(Velocity(10, 0, 4));
      const VelocityIntegrationSystem.fixed().run(world);
      expect(
        world.get<Transform2D>(entity.entity)!.translation.x,
        closeTo(20, 0.01),
      );
    });
  });

  group('Pathfinder.hasPath', () {
    test('agrees with findPath on random grids', () {
      final random = math.Random(7);
      for (final diagonal in [true, false]) {
        final pathfinder = Pathfinder(allowDiagonal: diagonal);
        for (var trial = 0; trial < 200; trial++) {
          final grid = CollisionGrid(width: 12, height: 9);
          for (var y = 0; y < 9; y++) {
            for (var x = 0; x < 12; x++) {
              if (random.nextDouble() < 0.35) grid.setBlocked(x, y);
            }
          }
          final sx = random.nextInt(12), sy = random.nextInt(9);
          final gx = random.nextInt(12), gy = random.nextInt(9);
          expect(
            pathfinder.hasPath(grid, sx, sy, gx, gy),
            pathfinder.findPath(grid, sx, sy, gx, gy).success,
            reason: 'trial $trial, diagonal $diagonal',
          );
        }
      }
    });

    test('ignores costs, so it reaches the goal on a budget A* runs out '
        'of', () {
      // A costly band between start and goal sends A* round every cheap
      // cell first; reachability heads straight across.
      final grid = CollisionGrid(width: 60, height: 60);
      for (var x = 0; x < 60; x++) {
        grid.setCost(x, 30, 1000);
      }
      const pathfinder = Pathfinder(maxIterations: 200);
      expect(pathfinder.findPath(grid, 30, 0, 30, 59).success, isFalse);
      expect(pathfinder.hasPath(grid, 30, 0, 30, 59), isTrue);
    });

    test('blocked or out-of-bounds ends have no path; start == goal has', () {
      final grid = CollisionGrid(width: 4, height: 4)..setBlocked(3, 3);
      const pathfinder = Pathfinder();
      expect(pathfinder.hasPath(grid, 0, 0, 3, 3), isFalse);
      expect(pathfinder.hasPath(grid, -1, 0, 1, 1), isFalse);
      expect(pathfinder.hasPath(grid, 1, 1, 1, 1), isTrue);
    });
  });

  group('UpdateSets membership', () {
    test('variable-mode systems join UpdateSets.simulate', () {
      expect(const CollisionResolutionSystem().meta.sets, [
        UpdateSets.simulate,
      ]);
      expect(const VelocityIntegrationSystem().meta.sets, [
        UpdateSets.simulate,
      ]);
      expect(const CollisionDetectionSystem().meta.sets, [UpdateSets.simulate]);
    });

    test('fixed-mode systems, run in fixedUpdate, join no update set', () {
      expect(const CollisionResolutionSystem.fixed().meta.sets, isEmpty);
      expect(const VelocityIntegrationSystem.fixed().meta.sets, isEmpty);
      expect(
        const CollisionDetectionSystem(mode: PhysicsMode.fixed).meta.sets,
        isEmpty,
      );
    });

    test('the fixed-mode plugin has no ordering ambiguities', () {
      final app = App()
        ..addPlugin(
          const PhysicsPlugin(config: PhysicsConfig(mode: PhysicsMode.fixed)),
        );
      expect(app.checkScheduleOrdering(), isEmpty);
    });
  });
}
