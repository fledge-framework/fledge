import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_save/fledge_save.dart';
import 'package:fledge_tiled/fledge_tiled.dart';

import 'actions.dart';
import 'components.dart';
import 'extraction.dart';
import 'resources.dart';
import 'systems/input_movement_system.dart';
import 'systems/pickup_collection_system.dart';
import 'systems/save_load_system.dart';
import 'systems/velocity_apply_system.dart';

/// Player collider half-width — used both for spawning and resolution.
const double kPlayerHalfSize = 10;

/// Pickup collider radius.
const double kPickupRadius = 8;

/// Collision layer bits. Solid bit comes from the framework, game bits
/// start at `CollisionLayers.gameLayersStart`.
abstract class Layers {
  static const int solid = CollisionLayers.solid;
  static const int player = CollisionLayers.gameLayersStart << 0;
  static const int pickup = CollisionLayers.gameLayersStart << 1;
}

/// Build the fully-wired Fledge `App` for Drifter.
///
/// Note: this does **not** spawn player/walls/pickups — the widget calls
/// [spawnScene] after the first tick so `TransformPropagateSystem` and
/// render extractors can observe the entities.
App buildApp({SaveConfig? saveConfig}) {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(InputPlugin.simple(
      context: InputContext(name: 'gameplay', map: buildInputMap()),
    ))
    ..addPlugin(PhysicsPlugin())
    ..addPlugin(SavePlugin(
      config: saveConfig ?? const SaveConfig(gameDirectory: 'Drifter'),
    ))
    ..insertResource(const GameBounds())
    ..insertResource(RunScore())
    ..insertResource(HighScore()) // auto-discovered via Saveable mixin
    ..insertResource(LoadRequested())
    ..insertResource(ResetRequested())
    // preUpdate — runs before every update-stage physics system:
    //  - TransformPropagateSystem: GlobalTransform2D fresh before anyone reads it.
    //  - SaveLoadSystem: converts input actions to save/load/reset flags.
    //  - InputMovementSystem: MUST run before CollisionResolutionSystem so
    //    resolution clamps *this* frame's velocity, not last frame's.
    //    Putting this in CoreStage.update next to physics looks innocent
    //    but silently lets the player walk through walls: the scheduler
    //    orders within a stage by conflict + insertion order, and the
    //    physics plugin was added first, so it wins the velocity race.
    ..addSystem(TransformPropagateSystem(), stage: CoreStage.preUpdate)
    ..addSystem(SaveLoadSystem(), stage: CoreStage.preUpdate)
    ..addSystem(InputMovementSystem(), stage: CoreStage.preUpdate)
    ..addSystem(VelocityApplySystem(), stage: CoreStage.update)
    ..addSystem(PickupCollectionSystem(), stage: CoreStage.update);

  // Register render extractors.
  final extractors = app.world.getResource<Extractors>()!;
  extractors
    ..register(DrifterEntityExtractor())
    ..register(GameBoundsExtractor());

  return app;
}

/// Spawn the initial scene into [app] — outer walls, a central player,
/// and a handful of pickups. Idempotent: callers should [clearScene]
/// first if they want a fresh layout.
void spawnScene(App app, {int pickupCount = 5, int seed = 0}) {
  final world = app.world;
  final bounds = world.getResource<GameBounds>()!;
  world.getResource<RunScore>()?.reset();

  _spawnPerimeter(world, bounds);
  _spawnPlayer(world, bounds);
  _spawnPickups(world, bounds, pickupCount, Random(seed));
}

/// Despawn everything the game logic spawned. Resources + plugins stay.
void clearScene(App app) {
  final world = app.world;
  final toKill = <Entity>[];
  for (final (entity, _) in world.query1<Transform2D>().iter()) {
    toKill.add(entity);
  }
  for (final e in toKill) {
    world.despawn(e);
  }
}

void _spawnPlayer(World world, GameBounds bounds) {
  // GlobalTransform2D is populated by TransformPropagateSystem; no need
  // to insert it manually.
  world.spawn()
    ..insert(Transform2D.from(bounds.width / 2, bounds.height / 2))
    ..insert(Velocity.stationary())
    ..insert(Collider.single(RectangleShape(
      x: -kPlayerHalfSize,
      y: -kPlayerHalfSize,
      width: kPlayerHalfSize * 2,
      height: kPlayerHalfSize * 2,
    )))
    ..insert(const CollisionConfig(
      layer: Layers.player,
      mask: Layers.solid | Layers.pickup,
    ))
    ..insert(const Player());
}

void _spawnPerimeter(World world, GameBounds bounds) {
  const t = 8.0; // wall thickness
  final w = bounds.width;
  final h = bounds.height;
  // top, bottom, left, right
  final rects = <(double, double, double, double)>[
    (0, 0, w, t),
    (0, h - t, w, t),
    (0, 0, t, h),
    (w - t, 0, t, h),
    // Obstacle below the spawn so collision resolution is visible.
    // Stays clear of the player spawn at (w/2, h/2) — otherwise the
    // player would spawn overlapping the wall and get frozen in place.
    (w * 0.3, h * 0.7, w * 0.4, t),
  ];
  for (final (x, y, width, height) in rects) {
    world.spawn()
      ..insert(Transform2D.from(x, y))
      ..insert(Collider.single(
        RectangleShape(x: 0, y: 0, width: width, height: height),
      ))
      ..insert(const CollisionConfig.solid())
      ..insert(const Wall());
  }
}

void _spawnPickups(World world, GameBounds bounds, int count, Random rng) {
  const margin = 24.0;
  for (var i = 0; i < count; i++) {
    final x = margin + rng.nextDouble() * (bounds.width - margin * 2);
    final y = margin + rng.nextDouble() * (bounds.height - margin * 2);
    world.spawn()
      ..insert(Transform2D.from(x, y))
      ..insert(Collider.single(RectangleShape(
        x: -kPickupRadius,
        y: -kPickupRadius,
        width: kPickupRadius * 2,
        height: kPickupRadius * 2,
      )))
      ..insert(const CollisionConfig(
        layer: Layers.pickup,
        mask: Layers.player,
        isSensor: true,
      ))
      ..insert(const Pickup());
  }
}
