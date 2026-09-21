# fledge_lighting_2d

2D dynamic lighting for [Fledge](https://fledge-framework.dev) — point, directional, and spot lights, plus ambient illumination, drawn via an additive Canvas pass on top of the sprite render view.

[![pub package](https://img.shields.io/pub/v/fledge_lighting_2d.svg)](https://pub.dev/packages/fledge_lighting_2d)

## Installation

```yaml
dependencies:
  fledge_lighting_2d: ^0.2.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/material.dart';

final app = App()
  ..addPlugin(RenderPlugin())
  ..addPlugin(const LightingPlugin(ambient: AmbientLight.dark));

// Torch on the player.
app.world.spawn()
  ..insert(Transform2D.from(200, 200))
  ..insert(GlobalTransform2D.identity())
  ..insert(Light2D.point(
    color: const Color(0xFFFFDD88),
    radius: 180,
    innerRadius: 40,
  ));

runApp(LitFledgeRenderView(app: app));
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/lighting_2d) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
