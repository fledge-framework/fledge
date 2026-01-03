/// Core render infrastructure for Fledge.
///
/// This library provides the foundational rendering abstractions:
///
/// - **Render Graph**: A DAG-based pipeline for organizing render passes
/// - **Render Context**: Abstract interface for GPU operations
/// - **Render World**: Separate world for render-specific data
/// - **Render Schedule**: Stage-based system scheduling
/// - **Extraction**: Two-world architecture for game/render separation
///
/// ## Render Graph
///
/// The render graph is a directed acyclic graph of [RenderNode]s connected
/// by [Edge]s. Each node performs a specific rendering task and can pass
/// data to subsequent nodes via typed [SlotInfo] slots.
///
/// ```dart
/// final graph = RenderGraph();
/// graph.addNode(CameraDriverNode());
/// graph.addNode(SpriteRenderNode());
/// graph.addEdge(
///   SlotId('camera_driver', 'view'),
///   SlotId('sprite_render', 'view'),
/// );
/// graph.execute(context);
/// ```
///
/// ## Two-World Architecture
///
/// The render system uses a two-world architecture inspired by Bevy:
///
/// - **Main World**: Contains game entities, components, and logic
/// - **Render World**: Contains extracted render data and GPU resources
///
/// Each frame, extractors copy relevant data from main to render world:
///
/// ```dart
/// final renderWorld = RenderWorld();
/// final schedule = RenderSchedule();
///
/// // Add extractors
/// mainWorld.insertResource(Extractors()
///   ..register(SpriteExtractor())
///   ..register(CameraExtractor()));
///
/// // Run render schedule
/// await schedule.run(mainWorld, renderWorld);
/// ```
///
/// ## Usage
///
/// This library is typically used with `fledge_render_2d` for 2D rendering
/// and `fledge_render_flutter` for Flutter integration:
///
/// ```dart
/// import 'package:fledge_render/fledge_render.dart';
/// import 'package:fledge_render_2d/fledge_render_2d.dart';
/// import 'package:fledge_render_flutter/fledge_render_flutter.dart';
/// ```
library fledge_render;

// Graph
export 'src/graph/edge.dart';
export 'src/graph/render_graph.dart';
export 'src/graph/render_node.dart';
export 'src/graph/slot.dart';

// Context
export 'src/context/render_context.dart';

// World
export 'src/world/render_world.dart';

// Extraction
export 'src/extract/draw_layer.dart';
export 'src/extract/extract.dart';
export 'src/extract/extracted_data.dart';

// Stages
export 'src/stages/render_schedule.dart';
export 'src/stages/render_stage.dart';
