import 'dart:math';
import 'dart:ui' show Color, TextAlign;

import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_save/fledge_save.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:vector_math/vector_math.dart';

import 'actions.dart';
import 'components.dart';
import 'resources.dart';
import 'systems/hud_update_system.dart';
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
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const CameraPlugin())
    ..addPlugin(InputPlugin.simple(
      context: InputContext(name: 'gameplay', map: buildInputMap()),
    ))
    ..addPlugin(PhysicsPlugin())
    ..addPlugin(SavePlugin(
      config: saveConfig ?? const SaveConfig(gameDirectory: 'Drifter'),
    ))
    ..addPlugin(const UiPlugin())
    // DebugPlugin's default config paints FPS + entity count +
    // `checkScheduleOrdering()` output. AABB / collider / camera-
    // frustum gizmos are opt-in — flip a flag on `DebugConfig` from
    // a debug menu (or the widget below) to enable them.
    ..addPlugin(const DebugPlugin())
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
    //    Putting this in Schedules.update next to physics looks innocent
    //    but silently lets the player walk through walls: the scheduler
    //    orders within a schedule by conflict + insertion order, and the
    //    physics plugin was added first, so it wins the velocity race.
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate)
    ..addSystem(SaveLoadSystem(), schedule: Schedules.preUpdate)
    ..addSystem(InputMovementSystem(), schedule: Schedules.preUpdate)
    ..addSystem(VelocityApplySystem(), schedule: Schedules.update)
    ..addSystem(PickupCollectionSystem(), schedule: Schedules.update)
    // HudUpdateSystem writes UiText.text before LayoutSystem runs in
    // postUpdate, so the extractor sees this frame's text.
    ..addSystem(HudUpdateSystem(), schedule: Schedules.update);

  // Register the generic sprite extractor — no game-specific
  // extraction is needed anymore. `Sprite` + `GlobalTransform2D` on
  // an entity is now the whole rendering contract.
  app.world.getResource<Extractors>()!.register(SpriteExtractor());

  // Register a 1×1 white pixel under the reserved solid-colour
  // handle. Drifter's sprites tint this via `Sprite.color`, so
  // walls/player/pickups get their colour without a real atlas.
  // Post-Phase 5: registration goes through `Assets<Texture>` so
  // hot-reload and ref-count paths work uniformly. The legacy
  // `TextureHandle` value type in `Sprite.texture` is a compile-only
  // shim onto the same asset store.
  final textures = app.world.getResource<Assets<Texture>>()!;
  textures.addWithId(
    const HandleId(kSolidColorTextureId, debugLabel: 'solid_color'),
    Texture(createSolidColorImageSync(const Color(0xFFFFFFFF)), 1, 1),
  );

  return app;
}

/// Spawn the initial scene into [app] — outer walls, a central player,
/// a handful of pickups, and a follow camera. Idempotent: callers
/// should [clearScene] first if they want a fresh layout.
void spawnScene(App app, {int pickupCount = 5, int seed = 0}) {
  final world = app.world;
  final bounds = world.getResource<GameBounds>()!;
  world.getResource<RunScore>()?.reset();

  _spawnPerimeter(world, bounds);
  final player = _spawnPlayer(world, bounds);
  _spawnPickups(world, bounds, pickupCount, Random(seed));
  _spawnCamera(world, bounds, player);
  _spawnHud(world);
}

/// Despawn everything the game logic spawned. Resources + plugins stay.
void clearScene(App app) {
  final world = app.world;
  final toKill = <Entity>{};
  for (final (entity, _) in world.query1<Transform2D>().iter()) {
    toKill.add(entity);
  }
  // HUD entities are pure UI (no Transform2D) — collect them too so
  // resetting the scene doesn't stack duplicate labels on top of the
  // canvas each time.
  for (final (entity, _) in world.query1<UiNode>().iter()) {
    toKill.add(entity);
  }
  for (final e in toKill) {
    world.despawn(e);
  }
}

Entity _spawnPlayer(World world, GameBounds bounds) {
  // `GlobalTransform2D` is inserted up-front so the entity's
  // archetype is stable before extraction runs. Relying on
  // `TransformPropagateSystem` to add it lazily during the same tick
  // can silently drop entities from `query2<Sprite, GlobalTransform2D>`
  // because the propagate pass mutates archetypes mid-iteration.
  final player = world.spawn()
    ..insert(Transform2D.from(bounds.width / 2, bounds.height / 2))
    ..insert(GlobalTransform2D())
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
    // The player is a green square. The old painter drew a rounded
    // rect with an outline; the sprite pipeline draws a plain
    // rect — an acceptable visual regression for Phase 3e. Anchor
    // defaults to (0.5, 0.5), matching the transform-at-centre
    // convention used by the collider.
    ..insert(Sprite(
      texture: kSolidColorTexture,
      color: const Color(0xFF00DD00),
      customSize: Vector2(kPlayerHalfSize * 2, kPlayerHalfSize * 2),
      layer: DrawLayer.characters,
    ))
    ..insert(const Player());
  return player.entity;
}

/// Spawn a camera that follows [player].
///
/// Drifter's world is 480×320 in world units (== screen pixels), so
/// the camera doesn't currently transform what's on screen (the
/// `FledgeRenderView` draws in raw world space). The camera is
/// spawned so `CameraFollowSystem` from `fledge_camera_2d` has
/// something to update — this is the Phase 6a integration point.
void _spawnCamera(World world, GameBounds bounds, Entity player) {
  world.spawn()
    ..insert(Transform2D.from(bounds.width / 2, bounds.height / 2))
    ..insert(GlobalTransform2D())
    ..insert(Camera2D(
      projection: OrthographicProjection(viewportHeight: bounds.height),
    ))
    // Smooth follow — 0.15 damping gives a soft catch-up that stays
    // out of the player's way during quick reversals.
    ..insert(CameraFollow(target: player, smoothing: 0.15));
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
      ..insert(GlobalTransform2D())
      ..insert(Collider.single(
        RectangleShape(x: 0, y: 0, width: width, height: height),
      ))
      ..insert(const CollisionConfig.solid())
      // Walls anchor at (0, 0) since their transform sits at the
      // rectangle's top-left — matches how the collider is
      // constructed (RectangleShape starts at 0,0 and extends
      // right/down). Ground layer so walls always render below
      // player/pickups.
      ..insert(Sprite(
        texture: kSolidColorTexture,
        color: const Color(0xFF4CAF50),
        customSize: Vector2(width, height),
        anchor: Vector2(0, 0),
        layer: DrawLayer.ground,
      ))
      ..insert(const Wall());
  }
}

/// Spawn the in-canvas HUD.
///
/// Two `UiText` labels: a live score in the top-left and a best score
/// in the top-right. Both carry marker components ([ScoreLabel] /
/// [HighScoreLabel]) that [HudUpdateSystem] uses to keep their text in
/// sync with the current run.
void _spawnHud(World world) {
  world.spawn()
    ..insert(const UiNode())
    ..insert(const UiAnchorComponent(UiAnchor.topLeft))
    ..insert(const UiOffset(x: 8, y: 8))
    ..insert(const UiSize(width: 160, height: 22))
    ..insert(UiText(
      text: 'Score: 0',
      fontSize: 16,
      color: const Color(0xFFFFD700),
    ))
    ..insert(const ScoreLabel());

  world.spawn()
    ..insert(const UiNode())
    ..insert(const UiAnchorComponent(UiAnchor.topRight))
    ..insert(const UiOffset(x: -8, y: 8))
    ..insert(const UiSize(width: 160, height: 22))
    ..insert(UiText(
      text: 'Best: 0',
      fontSize: 16,
      color: const Color(0xFFFFD700),
      align: TextAlign.right,
    ))
    ..insert(const HighScoreLabel());
}

void _spawnPickups(World world, GameBounds bounds, int count, Random rng) {
  const margin = 24.0;
  for (var i = 0; i < count; i++) {
    final x = margin + rng.nextDouble() * (bounds.width - margin * 2);
    final y = margin + rng.nextDouble() * (bounds.height - margin * 2);
    world.spawn()
      ..insert(Transform2D.from(x, y))
      ..insert(GlobalTransform2D())
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
      // Pickups become gold squares — the old painter drew circles
      // with a highlight, but we no longer synthesise that in the
      // sprite pipeline. Characters layer so they draw over walls.
      ..insert(Sprite(
        texture: kSolidColorTexture,
        color: const Color(0xFFFFD700),
        customSize: Vector2(kPickupRadius * 2, kPickupRadius * 2),
        layer: DrawLayer.characters,
      ))
      ..insert(const Pickup());
  }
}
