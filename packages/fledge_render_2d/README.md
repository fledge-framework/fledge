# fledge_render_2d

2D rendering for [Fledge](https://fledge-framework.dev) games: sprites, texture atlases, animation and transforms, plus the render infrastructure (RenderPlugin, Extractors, RenderWorld, FledgeRenderView) the other render packages build on.

[![pub package](https://img.shields.io/pub/v/fledge_render_2d.svg)](https://pub.dev/packages/fledge_render_2d)

## Installation

```yaml
dependencies:
  fledge_render_2d: ^0.7.2
```

## Quick Start

`RenderPlugin` sets up extraction and the sprite drawer, but registers no extractor and no per-frame systems. A sprite game needs, at minimum:

```dart
import 'dart:ui' show Color;

import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:vector_math/vector_math.dart';

App buildApp() {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const CameraPlugin()) // optional: a camera to follow
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);

  // Nothing is drawn without an extractor.
  app.world.getResource<Extractors>()!.register(SpriteExtractor());

  // kSolidColorTexture only draws once a 1×1 white pixel is registered
  // under its id. Real textures go into the same Assets<Texture> store.
  app.world.getResource<Assets<Texture>>()!.addWithId(
    const HandleId(kSolidColorTextureId),
    Texture(createSolidColorImageSync(const Color(0xFFFFFFFF)), 1, 1),
  );

  app.world.spawn()
    ..insert(Transform2D.from(100, 200))
    ..insert(GlobalTransform2D())
    ..insert(Sprite(
      texture: kSolidColorTexture,
      color: const Color(0xFF00DD00),
      customSize: Vector2(32, 32),
    ));

  return app;
}
```

Also add `AnimateSystemWithResource` (and an `AnimationTime` resource you update each frame) for sprite animation, and `SnapshotPreviousTransformSystem` in `Schedules.fixedFirst` if you use `PreviousTransform2D` interpolation.

`FledgeRenderView` paints the scene; it doesn't tick. Tick the app from your widget (e.g. a `Ticker` calling `await app.tick()`) and pass a listenable that changes once a frame as `repaint`:

```dart
FledgeRenderView(app: app, repaint: frameNotifier)
```

## Transforms

`Transform2D` holds a local `translation`, `rotation`, `scale` and `skew` (a horizontal shear: a point moves `skew` × its scaled y along x, before rotation), applied scale, skew, rotate, translate. A drop shadow lying on the ground is the sprite's silhouette flipped about its base (`Sprite.flipY`), squashed and skewed:

```dart
world.spawn()
  ..insert(Transform2D(translation: Vector2(x, y), scale: Vector2(1, 0.45), skew: 0.6))
  ..insert(GlobalTransform2D())
  ..insert(Sprite(texture: tex, anchor: Vector2(0.5, 1), flipY: true, color: shade));
```

Scenery that never moves can carry `StaticTransform`: it's computed once, then skipped by transform propagation and culled through a spatial grid, so per-frame cost follows what's on screen, not what's loaded. Its transform must not change after spawning (debug builds throw); its sprite and visibility may. See [Transforms](https://fledge-framework.dev/docs/rendering/transforms#static-scenery).

## Directional sprites

`Orientation` tracks one of four cardinal `Direction`s. For 8-, 16- or N-view sprites, `Facing` holds a continuous angle (radians, `0` = +x, clockwise on screen like `Transform2D.rotation`) and picks the view:

```dart
final facing = Facing()..updateFromVector(vx, vy);
final view = facing.viewIndex(16); // 0 = right, 4 = down, 8 = left, 12 = up
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/rendering/overview) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
