# fledge_camera_2d

2D cameras for [Fledge](https://fledge-framework.dev) games — follow, shake, letterbox, parallax, projections, transitions.

[![pub package](https://img.shields.io/pub/v/fledge_camera_2d.svg)](https://pub.dev/packages/fledge_camera_2d)

## Installation

```yaml
dependencies:
  fledge_camera_2d: ^0.2.0
```

## Quick Start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

final app = App()
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin());

// Spawn a camera that follows the player.
app.world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D.identity())
  ..insert(Camera2D(projection: OrthographicProjection()))
  ..insert(CameraFollow(target: playerEntity, smoothing: 0.15))
  ..insert(CameraShake());
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/camera_2d) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
