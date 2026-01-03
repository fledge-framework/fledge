import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import '../transform/global_transform.dart';
import '../transform/transform2d.dart';
import 'sprite.dart';

/// Convenience bundle for spawning sprite entities.
///
/// Groups commonly used components for sprite rendering:
/// - [Sprite] - The sprite component
/// - [Transform2D] - Local transform
/// - [GlobalTransform2D] - Computed global transform
/// - [Visibility] - Optional visibility control
///
/// Example:
/// ```dart
/// final bundle = SpriteBundle(
///   texture: playerTexture,
///   x: 100,
///   y: 200,
/// );
/// bundle.spawn(world);
/// ```
class SpriteBundle {
  /// The sprite component.
  final Sprite sprite;

  /// The local transform.
  final Transform2D transform;

  /// The global transform (usually identity, computed by propagation).
  final GlobalTransform2D globalTransform;

  /// Optional visibility component.
  final Visibility? visibility;

  /// Creates a sprite bundle.
  SpriteBundle({
    required TextureHandle texture,
    double x = 0,
    double y = 0,
    double rotation = 0,
    double scaleX = 1,
    double scaleY = 1,
    Color color = const Color(0xFFFFFFFF),
    Vector2? anchor,
    bool visible = true,
  })  : sprite = Sprite(
          texture: texture,
          color: color,
          anchor: anchor,
        ),
        transform = Transform2D(
          translation: Vector2(x, y),
          rotation: rotation,
          scale: Vector2(scaleX, scaleY),
        ),
        globalTransform = GlobalTransform2D(),
        visibility = visible ? null : Visibility(false);

  /// Creates a sprite bundle from existing components.
  SpriteBundle.fromComponents({
    required this.sprite,
    required this.transform,
    GlobalTransform2D? globalTransform,
    this.visibility,
  }) : globalTransform = globalTransform ?? GlobalTransform2D();

  /// Spawn an entity with all bundle components.
  ///
  /// Returns the [EntityCommands] for further customization.
  EntityCommands spawn(World world) {
    final entity = world.spawn()
      ..insert(sprite)
      ..insert(transform)
      ..insert(globalTransform);

    if (visibility != null) {
      entity.insert(visibility!);
    }

    return entity;
  }

  /// Insert all bundle components into an existing entity.
  void insertInto(EntityCommands commands) {
    commands
      ..insert(sprite)
      ..insert(transform)
      ..insert(globalTransform);

    if (visibility != null) {
      commands.insert(visibility!);
    }
  }
}
