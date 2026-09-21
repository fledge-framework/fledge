import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spawns a 4×4 box at [pos] and gives it velocity [(vx, vy)] plus the
/// supplied [config].
EntityCommands _spawnDynamic(
  World world,
  double px,
  double py, {
  double vx = 0,
  double vy = 0,
  CollisionConfig? config,
}) {
  final e = world.spawn()
    ..insert(Transform2D.from(px, py))
    ..insert(
      Collider.single(const RectangleShape(x: 0, y: 0, width: 4, height: 4)),
    )
    ..insert(Velocity(vx, vy));
  if (config != null) e.insert(config);
  return e;
}

void main() {
  group('Dynamic-vs-dynamic blocking (CollisionConfig.blocksDynamic)', () {
    test(
      'two dynamics without blocksDynamic pass through each other',
      () async {
        final world = World()..insertResource(FixedTimestep());
        // A at x=0 moving right (+x), B at x=6 stationary.
        final a = _spawnDynamic(world, 0, 0, vx: 4);
        _spawnDynamic(world, 6, 0);

        await const CollisionResolutionSystem.fixed().run(world);

        // No blocking → A's velocity untouched.
        final v = world.get<Velocity>(a.entity)!;
        expect(v.x, 4.0);
        expect(v.y, 0.0);
      },
    );

    test('two dynamics with blocksDynamic block each other', () async {
      final world = World()..insertResource(FixedTimestep());
      const cfg = CollisionConfig(blocksDynamic: true);
      final a = _spawnDynamic(world, 0, 0, vx: 4, config: cfg);
      _spawnDynamic(world, 6, 0, config: cfg);

      await const CollisionResolutionSystem.fixed().run(world);

      // 4 px right would put A's right edge at 8, overlapping B at 6..10.
      // No axis-slide is possible on a 1D scenario → both x and y stay 0.
      final v = world.get<Velocity>(a.entity)!;
      expect(v.x, 0.0);
      expect(v.y, 0.0);
    });

    test(
      'blocksDynamic is symmetric: only one side setting the flag is not enough',
      () async {
        // Only A opts in; B does not. Since dynamic blocking requires
        // the mover's own `blocksDynamic` (and the blocker to be in the
        // pool, which needs ITS `blocksDynamic`), and B is not in the
        // pool, A passes through.
        final world = World()..insertResource(FixedTimestep());
        const cfgA = CollisionConfig(blocksDynamic: true);
        final a = _spawnDynamic(world, 0, 0, vx: 4, config: cfgA);
        _spawnDynamic(world, 6, 0); // No config → not in blocker pool.

        await const CollisionResolutionSystem.fixed().run(world);
        expect(world.get<Velocity>(a.entity)!.x, 4.0);
      },
    );

    test(
      'layer/mask still filters: two blocksDynamic bodies on unrelated layers pass',
      () async {
        final world = World()..insertResource(FixedTimestep());
        const layerA = 1 << 4;
        const layerB = 1 << 5;
        const cfgA = CollisionConfig(
          layer: layerA,
          mask: layerA, // Only collides with own layer.
          blocksDynamic: true,
        );
        const cfgB = CollisionConfig(
          layer: layerB,
          mask: layerB,
          blocksDynamic: true,
        );
        final a = _spawnDynamic(world, 0, 0, vx: 4, config: cfgA);
        _spawnDynamic(world, 6, 0, config: cfgB);

        await const CollisionResolutionSystem.fixed().run(world);
        expect(world.get<Velocity>(a.entity)!.x, 4.0);
      },
    );

    test(
      'head-on: two movers with blocksDynamic each get their moving axis zeroed',
      () async {
        final world = World()..insertResource(FixedTimestep());
        const cfg = CollisionConfig(blocksDynamic: true);
        final a = _spawnDynamic(world, 0, 0, vx: 4, config: cfg);
        final b = _spawnDynamic(world, 6, 0, vx: -4, config: cfg);

        await const CollisionResolutionSystem.fixed().run(world);

        // Both bodies want to move into each other; both get blocked.
        // Neither is pushed.
        expect(world.get<Velocity>(a.entity)!.x, 0.0);
        expect(world.get<Velocity>(b.entity)!.x, 0.0);
      },
    );

    test(
      'axis-by-axis slide works around a dynamic blocker just like a static one',
      () async {
        final world = World()..insertResource(FixedTimestep());
        const cfg = CollisionConfig(blocksDynamic: true);
        // Tall dynamic wall to the mover's right, spanning the full
        // vertical range the mover could reach in one step.
        world.spawn()
          ..insert(Transform2D.from(6, -10))
          ..insert(
            Collider.single(
              const RectangleShape(x: 0, y: 0, width: 4, height: 30),
            ),
          )
          ..insert(Velocity(0, 0))
          ..insert(cfg);
        // Mover heads SE; should slide along Y (x blocked, y free).
        final mover = _spawnDynamic(world, 0, 0, vx: 4, vy: 4, config: cfg);

        await const CollisionResolutionSystem.fixed().run(world);

        final v = world.get<Velocity>(mover.entity)!;
        expect(v.x, 0.0);
        expect(v.y, 4.0);
      },
    );

    test(
      'static blocking still works when dynamic blocking is enabled',
      () async {
        final world = World()..insertResource(FixedTimestep());
        const cfg = CollisionConfig(blocksDynamic: true);
        // Static wall at x=6.
        world.spawn()
          ..insert(Transform2D.from(6, 0))
          ..insert(
            Collider.single(
              const RectangleShape(x: 0, y: 0, width: 4, height: 4),
            ),
          );
        final mover = _spawnDynamic(world, 0, 0, vx: 4, config: cfg);

        await const CollisionResolutionSystem.fixed().run(world);
        expect(world.get<Velocity>(mover.entity)!.x, 0.0);
      },
    );
  });
}
