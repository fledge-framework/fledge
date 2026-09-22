import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

import 'placement_state.dart';
import 'placement_tile.dart';

/// Marks the one ghost-preview entity (generic core): what it shows and
/// where. Kept up to date by [PlacementGhostSystem].
class PlacementGhost {
  String key;
  PlacementTile tile;
  bool isValid;

  PlacementGhost({
    required this.key,
    required this.tile,
    required this.isValid,
  });

  @override
  String toString() => 'PlacementGhost($key, $tile, valid: $isValid)';
}

/// How the ghost looks and where a tile is in world space — supplied by the
/// game (`PlacementCorePlugin(ghost:)`), stored as a resource.
class PlacementGhostConfig {
  /// World position of [tile] for the ghost's `Transform2D` (the same
  /// anchor the game spawns the real entity at).
  final (double x, double y) Function(PlacementTile tile) tileToWorld;

  /// A fresh sprite for placeable [key] (texture, anchor, draw layer — a
  /// world layer, so the ghost follows the camera), or null to show no
  /// ghost. Its `color` is replaced by [validColor] / [invalidColor].
  final Sprite? Function(World world, String key) ghostSpriteFor;

  /// Tint on a valid tile: the sprite at about half opacity.
  final Color validColor;

  /// Tint on an invalid tile: red, about half opacity.
  final Color invalidColor;

  /// Resources [ghostSpriteFor] reads (declared on the system's meta).
  final Set<Type> resourceReads;

  const PlacementGhostConfig({
    required this.tileToWorld,
    required this.ghostSpriteFor,
    this.validColor = const Color(0x80FFFFFF),
    this.invalidColor = const Color(0x80FF4040),
    this.resourceReads = const {},
  });
}

/// Keeps one world-space ghost entity at the preview tile while placing
/// (generic core): [PlacementGhost] + `Transform2D` + `GlobalTransform2D` +
/// the game's `Sprite` ([PlacementGhostConfig.ghostSpriteFor]) tinted
/// [PlacementGhostConfig.validColor] or [PlacementGhostConfig.invalidColor].
/// It is drawn by the normal sprite extraction, so it follows the camera.
///
/// The ghost appears once there is a preview tile, is rebuilt when the
/// placeable changes, and is despawned when placement ends. Runs only while
/// placing or while a ghost exists.
///
/// Meta note: spawning / despawning the ghost is a structural change, which
/// `SystemMeta` can't express.
class PlacementGhostSystem implements System {
  final Set<Type> spriteResourceReads;
  final List<String> before;
  final List<String> after;

  const PlacementGhostSystem({
    this.spriteResourceReads = const {},
    this.before = const [],
    this.after = const [],
  });

  static const String systemName = 'PlacementGhostSystem';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {
      ComponentId.of<PlacementGhost>(),
      ComponentId.of<Transform2D>(),
      ComponentId.of<GlobalTransform2D>(),
      ComponentId.of<Sprite>(),
    },
    resourceReads: {
      PlacementState,
      PlacementGhostConfig,
      ...spriteResourceReads,
    },
    before: before,
    after: after,
  );

  @override
  RunCondition? get runCondition => _shouldRun;

  static bool _shouldRun(World world) =>
      placementActive(world) ||
      world.query1<PlacementGhost>().iter().isNotEmpty;

  @override
  bool shouldRun(World world) => _shouldRun(world);

  @override
  Future<void> run(World world) {
    final state = world.getResource<PlacementState>();
    final config = world.getResource<PlacementGhostConfig>();
    final ghosts = [
      for (final (entity, ghost) in world.query1<PlacementGhost>().iter())
        (entity, ghost),
    ];
    final key = state?.placeableKey;
    final tile = state?.previewTile;
    if (state == null || config == null || key == null || tile == null) {
      for (final (entity, _) in ghosts) {
        world.despawn(entity);
      }
      return Future.value();
    }

    final (x, y) = config.tileToWorld(tile);
    final color = state.isValid ? config.validColor : config.invalidColor;

    // Keep the ghost if it shows this placeable; otherwise rebuild it.
    Entity? entity;
    for (final (e, ghost) in ghosts) {
      if (entity == null && ghost.key == key) {
        entity = e;
      } else {
        world.despawn(e);
      }
    }
    if (entity == null) {
      final sprite = config.ghostSpriteFor(world, key);
      if (sprite == null) return Future.value();
      final transform = Transform2D.from(x, y);
      world.spawn()
        ..insert(PlacementGhost(key: key, tile: tile, isValid: state.isValid))
        ..insert(transform)
        ..insert(GlobalTransform2D(transform.toMatrix()))
        ..insert(sprite..color = color);
      return Future.value();
    }

    final ghost = world.get<PlacementGhost>(entity)!
      ..tile = tile
      ..isValid = state.isValid;
    assert(ghost.key == key);
    final transform = world.get<Transform2D>(entity);
    if (transform != null) {
      transform.translation
        ..x = x
        ..y = y;
      world.get<GlobalTransform2D>(entity)?.matrix = transform.toMatrix();
    }
    world.get<Sprite>(entity)?.color = color;
    return Future.value();
  }
}
