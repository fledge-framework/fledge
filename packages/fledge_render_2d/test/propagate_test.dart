import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// The global transform the old propagation computed: the product of every
/// ancestor's local matrix, root first.
Matrix3 expected(World world, Entity entity) {
  final local = world.get<Transform2D>(entity)!.toMatrix();
  final parent = world.get<Parent>(entity);
  return parent == null ? local : expected(world, parent.entity) * local;
}

// Matrix3 stores 32-bit floats; the two ways round differently.
void expectClose(Matrix3 actual, Matrix3 wanted) {
  for (var i = 0; i < 9; i++) {
    expect(actual.storage[i], closeTo(wanted.storage[i], 1e-5), reason: '$i');
  }
}

void main() {
  late World world;
  late List<Entity> chain;

  setUp(() {
    world = World();
    // A chain four deep, each rotated, scaled and offset.
    chain = [];
    Entity? parent;
    for (var i = 0; i < 4; i++) {
      final t = Transform2D(
        translation: Vector2(10.0 * (i + 1), -3.0 * i),
        rotation: 0.3 * i,
        scale: Vector2(1 + 0.1 * i, 1 - 0.05 * i),
      );
      final e = parent == null
          ? world.spawn().entity
          : world.spawnChild(parent).entity;
      world.insert(e, t);
      chain.add(e);
      parent = e;
    }
  });

  int version(Entity e) => world.get<GlobalTransform2D>(e)!.version;

  test('every node of a deep hierarchy is computed once, as before', () {
    propagateTransforms(world);
    for (final e in chain) {
      expectClose(world.get<GlobalTransform2D>(e)!.matrix, expected(world, e));
      expect(version(e), 1, reason: 'computed once');
    }
  });

  test('an unchanged world recomputes nothing', () {
    propagateTransforms(world);
    propagateTransforms(world);
    propagateTransforms(world);
    for (final e in chain) {
      expect(version(e), 1);
    }
  });

  test('a moved parent carries its children; its siblings above stay', () {
    propagateTransforms(world);
    world.get<Transform2D>(chain[1])!
      ..translation.x += 25
      ..rotation = math.pi / 3;
    propagateTransforms(world);
    expect(version(chain[0]), 1, reason: 'the root did not move');
    for (final e in chain.skip(1)) {
      expect(version(e), 2);
      expectClose(world.get<GlobalTransform2D>(e)!.matrix, expected(world, e));
    }
  });

  test('a re-parented entity follows its new parent', () {
    final other = world.spawn().entity;
    world.insert(other, Transform2D.from(500, 500));
    propagateTransforms(world);
    final leaf = chain.last;
    world.removeParent(leaf);
    world.setParent(leaf, other);
    propagateTransforms(world);
    expectClose(
      world.get<GlobalTransform2D>(leaf)!.matrix,
      expected(world, leaf),
    );
  });

  test('children of a root whose global is set by hand follow it', () {
    final root = world.spawn().entity;
    world.insert(root, GlobalTransform2D());
    final child = world.spawnChild(root).entity;
    world.insert(child, Transform2D.from(5, 0));
    world
        .get<GlobalTransform2D>(root)!
        .matrix
        .setValues(
          1,
          0,
          0,
          0,
          1,
          0,
          100,
          50,
          1, //
        );
    propagateTransforms(world);
    expect(world.get<GlobalTransform2D>(child)!.x, 105);
    world.get<GlobalTransform2D>(root)!.matrix.storage[6] = 200;
    propagateTransforms(world);
    expect(world.get<GlobalTransform2D>(child)!.x, 205);
  });
}
