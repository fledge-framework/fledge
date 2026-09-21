import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// Directly bump the accumulator so `FixedTimestep.alpha` returns the
/// value we're testing at.
void _setAlpha(FixedTimestep ft, double alpha) {
  final steps = ft.stepSeconds * alpha;
  ft.addAccumulated(steps);
}

void main() {
  group('interpolatedRenderMatrix', () {
    late World world;
    late Entity entity;

    setUp(() {
      world = World()..insertResource(FixedTimestep());
      final commands = world.spawn()
        ..insert(Transform2D.from(10, 20))
        ..insert(
          GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, 10, 20, 1),
        )
        ..insert(PreviousTransform2D(translation: Vector2(0, 0)));
      entity = commands.entity;
    });

    test('alpha = 0 → snapshot position', () {
      final m = interpolatedRenderMatrix(
        world,
        entity,
        world.get<GlobalTransform2D>(entity)!,
        0.0,
      );
      expect(m.storage[6], 0.0);
      expect(m.storage[7], 0.0);
    });

    test('alpha = 0.5 → midpoint', () {
      final m = interpolatedRenderMatrix(
        world,
        entity,
        world.get<GlobalTransform2D>(entity)!,
        0.5,
      );
      expect(m.storage[6], 5.0);
      expect(m.storage[7], 10.0);
    });

    test('alpha = 1.0 → current position (matrix returned unchanged)', () {
      final source = world.get<GlobalTransform2D>(entity)!;
      final m = interpolatedRenderMatrix(world, entity, source, 1.0);
      expect(identical(m, source.matrix), isTrue);
    });

    test(
      'no PreviousTransform2D → matrix returned unchanged even at alpha < 1',
      () {
        final bare = world.spawn()
          ..insert(Transform2D.from(3, 4))
          ..insert(
            GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, 3, 4, 1),
          );
        final source = world.get<GlobalTransform2D>(bare.entity)!;
        final m = interpolatedRenderMatrix(world, bare.entity, source, 0.5);
        expect(identical(m, source.matrix), isTrue);
      },
    );

    test('teleport: snapTo makes the next extract show no motion', () {
      final prev = world.get<PreviousTransform2D>(entity)!;
      // Player teleports to a new place.
      world.get<Transform2D>(entity)!.translation.setValues(500, 600);
      world
          .get<GlobalTransform2D>(entity)!
          .matrix
          .setValues(1, 0, 0, 0, 1, 0, 500, 600, 1);
      prev.snapTo(world.get<Transform2D>(entity)!);

      // Even at alpha 0, the extracted position matches the current
      // position — no smear from wherever the entity used to be.
      final m = interpolatedRenderMatrix(
        world,
        entity,
        world.get<GlobalTransform2D>(entity)!,
        0.0,
      );
      expect(m.storage[6], 500.0);
      expect(m.storage[7], 600.0);
    });
  });

  group('SnapshotPreviousTransformSystem', () {
    test('copies Transform2D into PreviousTransform2D each run', () async {
      final world = World();
      final e = world.spawn()
        ..insert(Transform2D.from(1, 2))
        ..insert(PreviousTransform2D());

      await const SnapshotPreviousTransformSystem().run(world);
      var prev = world.get<PreviousTransform2D>(e.entity)!;
      expect(prev.translation.x, 1.0);
      expect(prev.translation.y, 2.0);

      world.get<Transform2D>(e.entity)!.translation.setValues(30, 40);
      await const SnapshotPreviousTransformSystem().run(world);
      prev = world.get<PreviousTransform2D>(e.entity)!;
      expect(prev.translation.x, 30.0);
      expect(prev.translation.y, 40.0);
    });
  });

  group('FixedTimestep.alpha wiring', () {
    test(
      'sanity: adding stepSeconds*0.5 to the accumulator yields alpha 0.5',
      () {
        final ft = FixedTimestep();
        _setAlpha(ft, 0.5);
        expect(ft.alpha, closeTo(0.5, 1e-6));
      },
    );
  });
}
