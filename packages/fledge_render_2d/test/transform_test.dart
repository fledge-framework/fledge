import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('Transform2D', () {
    test('default values', () {
      final transform = Transform2D();

      expect(transform.translation.x, equals(0));
      expect(transform.translation.y, equals(0));
      expect(transform.rotation, equals(0));
      expect(transform.scale.x, equals(1));
      expect(transform.scale.y, equals(1));
    });

    test('Transform2D.from creates translation-only transform', () {
      final transform = Transform2D.from(100, 200);

      expect(transform.translation.x, equals(100));
      expect(transform.translation.y, equals(200));
      expect(transform.rotation, equals(0));
    });

    test('toMatrix applies translation', () {
      final transform = Transform2D(translation: Vector2(10, 20));
      final matrix = transform.toMatrix();

      // Translation is in elements [6] and [7]
      expect(matrix[6], equals(10));
      expect(matrix[7], equals(20));
    });

    test('toMatrix applies rotation', () {
      final transform = Transform2D(rotation: math.pi / 2); // 90 degrees
      final matrix = transform.toMatrix();

      // For 90 degree rotation:
      // cos(90) ≈ 0, sin(90) = 1
      expect(matrix[0], closeTo(0, 1e-10)); // cos
      expect(matrix[1], closeTo(1, 1e-10)); // sin
      expect(matrix[3], closeTo(-1, 1e-10)); // -sin
      expect(matrix[4], closeTo(0, 1e-10)); // cos
    });

    test('toMatrix applies scale', () {
      final transform = Transform2D(scale: Vector2(2, 3));
      final matrix = transform.toMatrix();

      expect(matrix[0], equals(2)); // scale x
      expect(matrix[4], equals(3)); // scale y
    });

    test('rotationDegrees getter/setter', () {
      final transform = Transform2D();

      transform.setRotationDegrees(90);
      expect(transform.rotationDegrees, closeTo(90, 1e-10));

      transform.setRotationDegrees(45);
      expect(transform.rotationDegrees, closeTo(45, 1e-10));
    });

    test('clone creates independent copy', () {
      final original = Transform2D(
        translation: Vector2(1, 2),
        rotation: 0.5,
        scale: Vector2(3, 4),
      );

      final copy = original.clone();
      copy.translation.x = 100;
      copy.rotation = 1.5;
      copy.scale.x = 100;

      expect(original.translation.x, equals(1));
      expect(original.rotation, equals(0.5));
      expect(original.scale.x, equals(3));
    });

    test('translate moves position', () {
      final transform = Transform2D.from(10, 20);
      transform.translate(5, -5);

      expect(transform.translation.x, equals(15));
      expect(transform.translation.y, equals(15));
    });
  });

  group('GlobalTransform2D', () {
    test('identity is at origin', () {
      final global = GlobalTransform2D.identity();

      expect(global.x, equals(0));
      expect(global.y, equals(0));
    });

    test('translation getter reads from matrix', () {
      final matrix = Matrix3.identity();
      matrix[6] = 50;
      matrix[7] = 100;

      final global = GlobalTransform2D(matrix);

      expect(global.translation.x, equals(50));
      expect(global.translation.y, equals(100));
    });

    test('transformPoint applies full transform', () {
      final transform = Transform2D(
        translation: Vector2(10, 0),
        rotation: math.pi / 2,
      );
      final global = GlobalTransform2D(transform.toMatrix());

      final result = global.transformPoint(Vector2(1, 0));

      // Rotate (1,0) by 90 degrees -> (0,1), then translate by (10,0) -> (10,1)
      expect(result.x, closeTo(10, 1e-10));
      expect(result.y, closeTo(1, 1e-10));
    });

    test('clone creates independent copy', () {
      final matrix = Matrix3.identity();
      matrix[6] = 100;
      final original = GlobalTransform2D(matrix);
      final copy = original.clone();

      copy.matrix[6] = 999;

      expect(original.x, equals(100));
    });
  });

  group('TransformPropagateSystem', () {
    test('updates root entities', () async {
      final world = World();

      final entity = world.spawn()..insert(Transform2D.from(50, 100));

      final system = TransformPropagateSystem();
      await system.run(world);

      final global = world.get<GlobalTransform2D>(entity.entity);
      expect(global, isNotNull);
      expect(global!.x, equals(50));
      expect(global.y, equals(100));
    });

    test('propagates to children', () async {
      final world = World();

      final parent = world.spawn()..insert(Transform2D.from(10, 20));

      final child = world.spawnChild(parent.entity)
        ..insert(Transform2D.from(5, 5));

      final system = TransformPropagateSystem();
      await system.run(world);

      final childGlobal = world.get<GlobalTransform2D>(child.entity);
      expect(childGlobal, isNotNull);
      expect(childGlobal!.x, closeTo(15, 1e-10)); // 10 + 5
      expect(childGlobal.y, closeTo(25, 1e-10)); // 20 + 5
    });

    test('propagates multiple levels', () async {
      final world = World();

      final root = world.spawn()..insert(Transform2D.from(100, 0));

      final child = world.spawnChild(root.entity)
        ..insert(Transform2D.from(10, 0));

      final grandchild = world.spawnChild(child.entity)
        ..insert(Transform2D.from(1, 0));

      final system = TransformPropagateSystem();
      await system.run(world);

      final grandchildGlobal = world.get<GlobalTransform2D>(grandchild.entity);
      expect(grandchildGlobal, isNotNull);
      expect(grandchildGlobal!.x, closeTo(111, 1e-10)); // 100 + 10 + 1
    });
  });
}
