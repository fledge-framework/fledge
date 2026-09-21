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

// Camera view data (owned by the render pipeline).
//
// Camera components (`Camera2D`, `Projection`, `OrthographicProjection`,
// `CameraDriverNode`, follow/shake/parallax/letterbox/transitions) have
// moved to the `fledge_camera_2d` package. Add `CameraPlugin` from
// `package:fledge_camera_2d/fledge_camera_2d.dart` alongside
// `RenderPlugin` in your app.
export 'src/render/extract/camera_view.dart';

// Sprite
export 'src/sprite/extracted_sprite.dart';
export 'src/sprite/sprite.dart';
export 'src/sprite/sprite_bundle.dart';
export 'src/sprite/sprite_render_node.dart';
export 'src/sprite/texture.dart';

// Backend
export 'src/backend/canvas_render_context.dart';
export 'src/backend/gpu_render_context.dart';
export 'src/backend/image_helpers.dart';

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

// Transitions
export 'src/transitions/transition_state.dart';
export 'src/transitions/transition_systems.dart';

// Render infrastructure (previously in fledge_render).
// Graph
export 'src/render/graph/edge.dart';
export 'src/render/graph/render_graph.dart';
export 'src/render/graph/render_node.dart';
export 'src/render/graph/slot.dart';

// Context
export 'src/render/context/render_context.dart';

// World
export 'src/render/world/render_world.dart';

// Extraction
export 'src/render/extract/draw_layer.dart';
export 'src/render/extract/extract.dart';
export 'src/render/extract/extracted_data.dart';

// Stages
export 'src/render/stages/render_schedule.dart';
export 'src/render/stages/render_stage.dart';

// Layers
export 'src/render/layer/render_layer.dart';

// Plugin
export 'src/render/plugin/render_plugin.dart';

// Widget
export 'src/widget/fledge_render_view.dart';
