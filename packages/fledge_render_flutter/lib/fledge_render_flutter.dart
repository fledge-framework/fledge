/// Flutter integration for Fledge rendering.
///
/// This library provides the platform-specific rendering backends
/// for Fledge, with an abstraction layer supporting both:
///
/// - **Canvas API**: Stable, works everywhere (default)
/// - **flutter_gpu**: Experimental, high-performance (when available)
///
/// ## Quick Start
///
/// ```dart
/// import 'package:fledge_render_flutter/fledge_render_flutter.dart';
///
/// // Select the best available backend
/// final backend = await BackendSelector.selectBest();
///
/// // Use it for rendering
/// final frame = backend.beginFrame(size);
/// frame.drawSpriteBatch(batch);
/// backend.endFrame(frame);
/// ```
///
/// ## Backend Selection
///
/// By default, [BackendSelector.selectBest] tries flutter_gpu first
/// (if available) and falls back to Canvas:
///
/// ```dart
/// // Prefer GPU if available
/// final backend = await BackendSelector.selectBest(preferGpu: true);
///
/// // Force Canvas backend
/// final canvas = CanvasBackend();
/// await canvas.initialize();
/// ```
///
/// ## Creating Textures
///
/// ```dart
/// final texture = await backend.createTextureFromData(
///   TextureDescriptor(width: 256, height: 256),
///   imageData,
/// );
/// ```
library;

// Backend abstraction
export 'src/backend/backend_selector.dart';
export 'src/backend/render_backend.dart';

// Canvas backend
export 'src/canvas/canvas_backend.dart';

// Render layers
export 'src/layer/render_layer.dart';
