import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

/// Small helper — a 4×4 dynamic body at [pos] with the given velocity
/// and config.
EntityCommands _dyn(
  World world,
  double px,
  double py, {
  double vx = 0,
  double vy = 0,
  CollisionConfig? config,
  double w = 4,
  double h = 4,
}) {
  final e = world.spawn()
    ..insert(Transform2D.from(px, py))
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: w, height: h)))
    ..insert(Velocity(vx, vy));
  if (config != null) e.insert(config);
  return e;
}

/// Wires a bare fixed-step world with a yield tracker + the required
/// event queues. Mirrors what PhysicsPlugin does.
World _yieldWorld() {
  final world = World()
    ..insertResource(FixedTimestep())
    ..insertResource(ContactYieldTracker())
    ..registerEvent<ContactYieldStarted>()
    ..registerEvent<ContactYieldEnded>();
  return world;
}

void main() {
  group('CollisionConfig.yieldAfter', () {
    test(
      'pair blocks until yieldAfter has elapsed, then passes through',
      () async {
        final world = _yieldWorld();
        const cfg = CollisionConfig(
          blocksDynamic: true,
          yieldAfter: Duration(milliseconds: 100), // 6 fixed steps @ 60 Hz
        );
        // A and B overlap by 1 px on x (0..4 and 3..7) — that's a
        // strict Rect.overlaps overlap, which is what the contact
        // tracker uses.
        final a = _dyn(world, 0, 0, vx: 4, config: cfg);
        final b = _dyn(world, 3, 0, config: cfg);

        final resolver = const CollisionResolutionSystem.fixed();
        final tracker = world.getResource<ContactYieldTracker>()!;

        // Each step A's vx is zeroed by blocking. Sixth step's age (6 ×
        // 16.667 ms) crosses the 100 ms threshold and the pair yields.
        var yieldedOnStep = -1;
        for (var step = 1; step <= 8; step++) {
          // Re-arm velocity every step (blocking zeroes it).
          world.get<Velocity>(a.entity)!.x = 4;
          await resolver.run(world);
          if (tracker.isYielding(a.entity, b.entity)) {
            yieldedOnStep = step;
            break;
          }
          // Still blocked while age < 100ms.
          expect(world.get<Velocity>(a.entity)!.x, 0.0);
        }
        expect(
          yieldedOnStep,
          greaterThanOrEqualTo(6),
          reason: 'Yield should trigger after 6 fixed steps (100 ms).',
        );
        expect(
          yieldedOnStep,
          lessThanOrEqualTo(7),
          reason: 'Yield should not take much longer than the threshold.',
        );

        // Once yielding, blocking is off — A's velocity is preserved.
        world.get<Velocity>(a.entity)!.x = 4;
        await resolver.run(world);
        expect(world.get<Velocity>(a.entity)!.x, 4.0);
      },
    );

    test('separation ends yielding and clears the tracker entry', () async {
      final world = _yieldWorld();
      const cfg = CollisionConfig(
        blocksDynamic: true,
        yieldAfter: Duration(milliseconds: 50),
      );
      final a = _dyn(world, 0, 0, vx: 4, config: cfg);
      final b = _dyn(world, 3, 0, config: cfg);
      final resolver = const CollisionResolutionSystem.fixed();
      final tracker = world.getResource<ContactYieldTracker>()!;

      // Drive through the yield threshold.
      for (var step = 0; step < 10; step++) {
        world.get<Velocity>(a.entity)!.x = 4;
        await resolver.run(world);
        if (tracker.isYielding(a.entity, b.entity)) break;
      }
      expect(tracker.isYielding(a.entity, b.entity), isTrue);

      // Separate B by moving it far away.
      world.get<Transform2D>(b.entity)!.translation.x = 1000;
      world.get<Velocity>(a.entity)!.x = 0;

      await resolver.run(world);

      expect(tracker.isYielding(a.entity, b.entity), isFalse);
      expect(tracker.contactAge(a.entity, b.entity), isNull);
    });

    test(
      'ContactYieldStarted fires exactly once when the pair enters yielding',
      () async {
        final world = _yieldWorld();
        const cfg = CollisionConfig(
          blocksDynamic: true,
          yieldAfter: Duration(milliseconds: 50),
        );
        final a = _dyn(world, 0, 0, vx: 4, config: cfg);
        _dyn(world, 3, 0, config: cfg);
        final resolver = const CollisionResolutionSystem.fixed();

        int startedCount = 0;
        for (var step = 0; step < 12; step++) {
          world.get<Velocity>(a.entity)!.x = 4;
          await resolver.run(world);
          world.updateEvents();
          startedCount += world
              .eventReader<ContactYieldStarted>()
              .read()
              .length;
        }
        expect(startedCount, 1);
      },
    );

    test('ContactYieldEnded fires when a yielding pair separates', () async {
      final world = _yieldWorld();
      const cfg = CollisionConfig(
        blocksDynamic: true,
        yieldAfter: Duration(milliseconds: 50),
      );
      final a = _dyn(world, 0, 0, vx: 4, config: cfg);
      final b = _dyn(world, 3, 0, config: cfg);
      final resolver = const CollisionResolutionSystem.fixed();
      final tracker = world.getResource<ContactYieldTracker>()!;

      // Get into yielding.
      for (var step = 0; step < 12; step++) {
        world.get<Velocity>(a.entity)!.x = 4;
        await resolver.run(world);
        world.updateEvents();
        if (tracker.isYielding(a.entity, b.entity)) break;
      }

      // Separate.
      world.get<Transform2D>(b.entity)!.translation.x = 1000;
      world.get<Velocity>(a.entity)!.x = 0;
      await resolver.run(world);
      world.updateEvents();

      final ended = world.eventReader<ContactYieldEnded>().read().toList();
      expect(ended, hasLength(1));
    });

    // Regression coverage for the Porios Batch 5 handoff (item 22).
    // Before the fix, resolution stopped a moving body 1–3 px short of
    // a standing body — bounds never overlapped, so the yield timer
    // never started and the pair was blocked forever.
    test('walking into a STANDING body still triggers yieldAfter '
        '(regression for Batch 5 #22)', () async {
      final world = _yieldWorld();
      const cfg = CollisionConfig(
        blocksDynamic: true,
        yieldAfter: Duration(milliseconds: 100),
      );
      // Bodies are 1 px apart on the X axis — the mover would hit
      // the standing body on its next step. Resolution zeros the
      // velocity so their bounds never overlap in practice.
      final a = _dyn(world, 0, 0, vx: 4, config: cfg);
      final b = _dyn(world, 5, 0, config: cfg);
      final resolver = const CollisionResolutionSystem.fixed();
      final tracker = world.getResource<ContactYieldTracker>()!;

      for (var step = 0; step < 15; step++) {
        // Re-arm the intent each step; resolution zeroes it.
        world.get<Velocity>(a.entity)!.x = 4;
        await resolver.run(world);
        if (tracker.isYielding(a.entity, b.entity)) break;
      }

      expect(
        tracker.isYielding(a.entity, b.entity),
        isTrue,
        reason:
            'A walking into a standing B should yield after the '
            'configured contact time even when their bounds never '
            'quite overlap because resolution keeps stopping the mover.',
      );

      // Once yielding, blocking is off — A's velocity is preserved.
      world.get<Velocity>(a.entity)!.x = 4;
      await resolver.run(world);
      expect(world.get<Velocity>(a.entity)!.x, 4.0);
    });

    test('two bodies walking toward each other also start the yield timer '
        '(regression for Batch 5 #22)', () async {
      final world = _yieldWorld();
      const cfg = CollisionConfig(
        blocksDynamic: true,
        yieldAfter: Duration(milliseconds: 100),
      );
      // Same 1 px gap, but this time both bodies are trying to
      // close it. Resolution will still zero both velocities, but
      // the predicted-bounds check has to catch the pair.
      final a = _dyn(world, 0, 0, vx: 4, config: cfg);
      final b = _dyn(world, 5, 0, vx: -4, config: cfg);
      final resolver = const CollisionResolutionSystem.fixed();
      final tracker = world.getResource<ContactYieldTracker>()!;

      for (var step = 0; step < 15; step++) {
        world.get<Velocity>(a.entity)!.x = 4;
        world.get<Velocity>(b.entity)!.x = -4;
        await resolver.run(world);
        if (tracker.isYielding(a.entity, b.entity)) break;
      }

      expect(tracker.isYielding(a.entity, b.entity), isTrue);
    });

    test('pair with only one side setting yieldAfter never yields', () async {
      final world = _yieldWorld();
      const cfgA = CollisionConfig(
        blocksDynamic: true,
        yieldAfter: Duration(milliseconds: 50),
      );
      const cfgB = CollisionConfig(blocksDynamic: true);
      final a = _dyn(world, 0, 0, vx: 4, config: cfgA);
      final b = _dyn(world, 3, 0, config: cfgB);
      final resolver = const CollisionResolutionSystem.fixed();
      final tracker = world.getResource<ContactYieldTracker>()!;

      for (var step = 0; step < 30; step++) {
        world.get<Velocity>(a.entity)!.x = 4;
        await resolver.run(world);
      }
      expect(tracker.isYielding(a.entity, b.entity), isFalse);
    });
  });
}
