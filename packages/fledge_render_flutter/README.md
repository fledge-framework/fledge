# fledge_render_flutter

Flutter render backend for [Fledge](https://fledge-framework.dev). Connects Fledge's render system to Flutter's rendering APIs.

[![pub package](https://img.shields.io/pub/v/fledge_render_flutter.svg)](https://pub.dev/packages/fledge_render_flutter)

## Features

- **Canvas Backend**: Stable rendering using Flutter's Canvas API
- **GPU Backend**: Experimental high-performance rendering (flutter_gpu)
- **Backend Selection**: Automatic fallback from GPU to Canvas
- **Texture Management**: Load and manage textures efficiently

## Installation

```yaml
dependencies:
  fledge_render_flutter: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_render_flutter/fledge_render_flutter.dart';

// Select the best available backend
final backend = await BackendSelector.selectBest();

// Use it for rendering
final frame = backend.beginFrame(size);
frame.drawSpriteBatch(batch);
backend.endFrame(frame);
```

## Backend Selection

By default, `BackendSelector.selectBest()` tries flutter_gpu first (if available) and falls back to Canvas:

```dart
// Prefer GPU if available
final backend = await BackendSelector.selectBest(preferGpu: true);

// Force Canvas backend
final canvas = CanvasBackend();
await canvas.initialize();
```

## Creating Textures

```dart
final texture = await backend.createTextureFromData(
  TextureDescriptor(width: 256, height: 256),
  imageData,
);
```

## Render Layers

Organize rendering with layers:

```dart
final layer = RenderLayer(
  name: 'sprites',
  order: 10,
);

backend.submitLayer(layer);
```

## Documentation

See the [Rendering Architecture](https://fledge-framework.dev/docs/guides/rendering) for detailed documentation.

## Related Packages

- [fledge_render](https://pub.dev/packages/fledge_render) - Core render infrastructure
- [fledge_render_2d](https://pub.dev/packages/fledge_render_2d) - 2D rendering components
- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
