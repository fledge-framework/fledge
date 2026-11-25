# fledge_lighting_2d

2D dynamic lighting for [Fledge](https://fledge-framework.dev) — point, directional, and spot lights, plus ambient illumination, drawn by a view pass in every `FledgeRenderView`: a light map that multiplies the sprites (or the older additive modes).

[![pub package](https://img.shields.io/pub/v/fledge_lighting_2d.svg)](https://pub.dev/packages/fledge_lighting_2d)

## Installation

```yaml
dependencies:
  fledge_lighting_2d: ^0.6.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final app = App()
    ..addPlugin(RenderPlugin()) // first: it holds the view passes
    ..addPlugin(
      const LightingPlugin(
        // A night: ambient and lights form a light map that multiplies the
        // sprites, so lamps show the ground in its true colours.
        ambient: AmbientLight(
          color: Color(0xFF101C4C),
          intensity: 0.8,
          blend: AmbientBlend.lightMap,
        ),
      ),
    )
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);
  app.world.getResource<Extractors>()!.register(SpriteExtractor());

  // A lamp: a soft, ground-squashed pool of warm light.
  app.world.spawn()
    ..insert(Transform2D.from(200, 200))
    ..insert(GlobalTransform2D.identity())
    ..insert(Light2D.point(
      color: const Color(0xFFFFD49A),
      radius: 120,
      innerRadius: 18,
      aspect: 0.74,
    ));

  // Any FledgeRenderView of the app is lit; no special widget. (Tick the
  // app from your widget each frame.)
  runApp(FledgeRenderView(app: app));
}
```

`LightingPlugin` throws a `StateError` if `RenderPlugin` wasn't added first. Its default ambient is `AmbientLight.white` (half-lit, drawn under the sprites); `AmbientBlend.lightMap` is the model to use for night scenes. `Light2D.castsShadow` is reserved: there are no shadows yet.

`Sprite(emissive: true)` draws after the lighting at full brightness (lit windows, screens). `LitFledgeRenderView` is deprecated.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/rendering/lighting) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
