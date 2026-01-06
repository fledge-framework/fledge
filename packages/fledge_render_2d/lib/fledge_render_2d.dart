/// 2D rendering components for Fledge.
///
/// This library provides 2D-specific rendering components:
///
/// - **Transform2D**: Local position, rotation, and scale
/// - **GlobalTransform2D**: Computed world-space transform
/// - **Camera2D**: 2D camera with orthographic projection
/// - **Sprite**: Textured quad rendering
/// - **SpriteBatch**: Efficient batched sprite rendering
///
/// ## Transforms
///
/// Use [Transform2D] for local transforms relative to parent:
///
/// ```dart
/// world.spawn()
///   ..insert(Transform2D(
///     translation: Vector2(100, 200),
///     rotation: math.pi / 4,
///     scale: Vector2.all(2),
///   ));
/// ```
///
/// The [TransformPropagateSystem] computes [GlobalTransform2D] from
/// the entity hierarchy.
///
/// ## Camera
///
/// Create a camera with [Camera2D]:
///
/// ```dart
/// world.spawn()
///   ..insert(Transform2D.from(0, 0))
///   ..insert(Camera2D(
///     projection: OrthographicProjection(viewportHeight: 20),
///   ));
/// ```
///
/// ## Sprites
///
/// Render textured quads with [Sprite]:
///
/// ```dart
/// world.spawn()
///   ..insert(Sprite(texture: playerTexture))
///   ..insert(Transform2D.from(100, 200));
/// ```
///
/// Or use [SpriteBundle] for convenience:
///
/// ```dart
/// SpriteBundle(texture: playerTexture, x: 100, y: 200).spawn(world);
/// ```
///
/// ## dart:ui types
///
/// This package uses standard dart:ui types like [Color], [Rect], [Offset],
/// and [Size]. Import them directly from dart:ui:
///
/// ```dart
/// import 'dart:ui' show Color, Rect;
/// ```
library;

// Transform
export 'src/transform/global_transform.dart';
export 'src/transform/propagate.dart';
export 'src/transform/transform2d.dart';

// Camera
export 'src/camera/camera2d.dart';
export 'src/camera/camera_driver.dart';
export 'src/camera/pixel_perfect.dart';
export 'src/camera/projection.dart';
export 'src/camera/viewport_size.dart';

// Sprite
export 'src/sprite/extracted_sprite.dart';
export 'src/sprite/sprite.dart';
export 'src/sprite/sprite_bundle.dart';
export 'src/sprite/sprite_render_node.dart';

// Batching
export 'src/batch/sprite_batch.dart';

// Atlas (Sprite Sheets)
export 'src/atlas/atlas_extractor.dart';
export 'src/atlas/atlas_layout.dart';
export 'src/atlas/texture_atlas.dart';

// Animation
export 'src/animation/animate_system.dart';
export 'src/animation/animation_clip.dart';
export 'src/animation/animation_player.dart';

// Materials
export 'src/material/material2d.dart';
export 'src/material/shader_material.dart';
export 'src/material/sprite_material.dart';

// Character
export 'src/character/orientation.dart';
