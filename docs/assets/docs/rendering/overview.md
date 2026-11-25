# Rendering Overview

`fledge_render_2d` draws 2D games into a Flutter widget. It owns sprites,
texture atlases, sprite animation, 2D transforms and the render plumbing that
the other render packages (`fledge_camera_2d`, `fledge_lighting_2d`,
`fledge_particles`, `fledge_ui`, `fledge_tiled`, `fledge_debug`) plug into.

```yaml
dependencies:
  fledge_render_2d: ^0.6.0
  fledge_camera_2d: ^0.6.0   # almost always wanted alongside it
```

It needs Flutter 3.50+ (Dart 3.14+). Desktop (Windows, macOS, Linux) is the
supported target; web and mobile are best-effort. `FileTextureLoader` uses
`dart:io`, so on web load textures from the asset bundle instead (see
[Textures](/docs/rendering/sprites-animation#textures)).

<!-- snippet-setup
import 'package:vector_math/vector_math.dart';
-->

## What runs each frame

Rendering follows Bevy's two-world split. Your game state lives in the main
`World`. A separate `RenderWorld` holds only what is needed to draw this
frame, and it is **cleared and rebuilt every frame**:

1. Your systems run (`first` through `last`, including the fixed-step chain).
   `TransformPropagateSystem` turns each entity's local `Transform2D` into a
   world-space `GlobalTransform2D`.
2. In `Schedules.extract`, `RenderExtractionSystem` clears the `RenderWorld`
   and calls every registered `Extractor`. `SpriteExtractor` copies each
   visible `Sprite` + `GlobalTransform2D` into an `ExtractedSprite`; the
   lighting, particle and UI packages register their own extractors.
3. `Schedules.render` runs. The built-in pipeline adds nothing to it.
4. When Flutter paints, `FledgeRenderView` reads the `RenderWorld`, sorts the
   sprites into draw order, groups neighbouring sprites that share a texture
   into one batch, and hands each batch to the `SpriteDrawer` resource. The
   default `CanvasSpriteDrawer` draws a batch with `Canvas.drawRawAtlas`.

Painting happens on Flutter's schedule, not inside `App.tick`: the widget
draws whatever the last extract left in the `RenderWorld`. Never keep game
state in the render world. Render-world entities don't survive to the next
frame; only its resources do.

## What RenderPlugin sets up

`RenderPlugin` inserts these resources and one system:

| Added by `RenderPlugin` | What it is |
|---|---|
| `Extractors` | The registry extractors are added to. |
| `RenderWorld` | The per-frame render data. |
| `ViewPasses` | Extra world-space drawing around the sprites (lighting uses it). See [View passes](/docs/rendering/sprites-animation#view-passes). |
| `RenderBackendResource` | Which backend was chosen. |
| `Assets<Texture>` | The texture store sprites are resolved against. |
| `SpriteDrawer` | `CanvasSpriteDrawer` (default) or `GpuSpriteDrawer`. |
| `TransitionCompleted` event | Sent by `TransitionFadeSystem`. |
| `RenderExtractionSystem` | In `Schedules.extract`. |

It does **not** register an extractor or any per-frame system. Nothing is
drawn until you register at least `SpriteExtractor` and run
`TransformPropagateSystem`.

## Minimum wiring

The checklist for a sprite game:

1. `RenderPlugin()`, added before any plugin that registers an extractor
   (`LightingPlugin`, `UiPlugin` and `ParticlePlugin` need its `Extractors`).
2. `extractors.register(SpriteExtractor())` (and `AtlasSpriteExtractor()` if
   you draw `AtlasSprite`s on their own).
3. `TransformPropagateSystem()` in a schedule before anything reads
   `GlobalTransform2D`. The Drifter example uses `Schedules.preUpdate`.
4. `CameraPlugin()` from `fledge_camera_2d` if the view should follow a
   camera. Without a camera, world coordinates are screen pixels.
5. `WallTimePlugin()`: the camera follow, particles, tweens and transitions
   read `WallTime.delta`.
6. Register any textures in `Assets<Texture>`, including the solid-colour
   pixel if you use `kSolidColorTexture`: nothing registers it for you.
7. If you animate with `AnimateSystemWithResource`, insert an `AnimationTime`
   resource and update its `deltaTime` each frame: nothing writes it.
8. If you give entities `PreviousTransform2D` for interpolation, add
   `SnapshotPreviousTransformSystem` to `Schedules.fixedFirst` (see
   [Transforms](/docs/rendering/transforms#smooth-movement-between-fixed-steps)).

Here it is in code:

```dart
App buildApp() {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const CameraPlugin())
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);

  app.world.getResource<Extractors>()!.register(SpriteExtractor());

  // A 1×1 white pixel under the reserved id, so sprites using
  // kSolidColorTexture draw as rectangles tinted by Sprite.color.
  app.world.getResource<Assets<Texture>>()!.addWithId(
    const HandleId(kSolidColorTextureId),
    Texture(createSolidColorImageSync(const Color(0xFFFFFFFF)), 1, 1),
  );

  // A green 32×32 square at (100, 100).
  app.world.spawn()
    ..insert(Transform2D.from(100, 100))
    ..insert(GlobalTransform2D())
    ..insert(Sprite(
      texture: kSolidColorTexture,
      color: const Color(0xFF00DD00),
      customSize: Vector2(32, 32),
    ));

  return app;
}
```

Spawning with a `GlobalTransform2D` up front is optional
(`TransformPropagateSystem` adds one), but it means the sprite is drawn on the
very first frame.

## Driving the app from a widget

`FledgeRenderView` only paints. Your widget ticks the app, typically once per
Flutter frame from a `Ticker`, and tells the view to repaint through its
`repaint` listenable:

```dart
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class GameView extends StatefulWidget {
  const GameView({super.key, required this.app});
  final App app;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView>
    with SingleTickerProviderStateMixin {
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  bool _ticking = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) async {
      if (_ticking) return; // never start a tick before the last one ends
      _ticking = true;
      await widget.app.tick();
      _ticking = false;
      _frame.value++;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FledgeRenderView(
    app: widget.app,
    backgroundColor: const Color(0xFF1A1A2E),
    repaint: _frame,
  );
}
```

`FledgeRenderView` fills the space its parent gives it. `backgroundColor` is
drawn before the sprites (`null` leaves it transparent). Without `repaint`, it
repaints only when the widget rebuilds. Don't use `App.run()` in a Flutter
game: it ticks in a loop as fast as it can, independent of the display.

For steadier movement, time frames by the display rather than a stopwatch:
call `WallTime.useClock` with
`SchedulerBinding.instance.currentSystemFrameTimeStamp` (see
[Time & Fixed Timestep](/docs/scheduling/time)).

## Writing an extractor

An extractor copies what the renderer needs out of the main world. Sprites go
into the render world's sprite list with `addSprite`; anything else (a light,
a UI element) is added as its own entity with `add`. Renderers read sprites
back through `renderWorld.extractedSprites`, not through a query: a
`query1<ExtractedSprite>()` doesn't see sprites added with `addSprite`.

```dart
/// Draws a health bar above every entity with Health, using the
/// solid-colour pixel.
class Health {
  double fraction = 1;
}

class HealthBarExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (entity, health, global)
        in mainWorld.query2<Health, GlobalTransform2D>().iter()) {
      final transform = Matrix3.identity()
        ..setEntry(0, 2, global.x - 16)
        ..setEntry(1, 2, global.y - 20);
      renderWorld.addSprite(ExtractedSprite(
        entity: entity,
        texture: kSolidColorTexture,
        sourceRect: kSolidColorTexture.fullRect,
        transform: transform,
        color: const Color(0xFFE53935),
        sortKey: DrawLayer.foreground.sortKey(),
        layer: DrawLayer.foreground,
        anchor: Vector2(0, 0.5),
        size: Vector2(32 * health.fraction, 4),
      ));
    }
  }
}
```

Register it next to the sprite extractor:
`app.world.getResource<Extractors>()!.register(HealthBarExtractor())`.

`ExtractedSprite` requires `entity`, `texture`, `sourceRect`, `transform` (a
`Matrix3` in world space), `color`, `sortKey`, `anchor` and `size`. The
optional fields are `layer`, `layerSubOrder`, `preciseSubOrder`, `flipFlags`
(`ExtractedSprite.computeFlipFlags(flipX, flipY)`) and `emissive`.
`ComponentExtractor<TSource, TExtracted>` wraps a per-component function for
the simple case.

## Draw order

Sprites are drawn in order of their integer `sortKey`, low to high. The
`DrawLayer` enum splits the key into bands of `DrawLayerExtension
.layerMultiplier` (100,000):

| Layer | Sort key range |
|---|---|
| `background` | 0 – 99,999 |
| `ground` | 100,000 – 199,999 |
| `characters` (the default) | 200,000 – 299,999 |
| `foreground` | 300,000 – 399,999 |
| `particles` | 400,000 – 499,999 |
| `ui` | 500,000+ |

`DrawLayer.characters.sortKey(subOrder: n)` packs a layer and a sub-order.
`SpriteExtractor` uses the sprite's `Sprite.layer`, and for the sub-order
either `Sprite.layerSubOrder` (when non-zero) or the sprite's y position
(`DrawLayerExtension.ySortSubOrder(y)`, which is `y × ySortScale`, with
`ySortScale` = 10, clamped to the band). A sprite further down the screen draws
over one above it, the usual top-down painter's order.

The clamp only leaves room for y from 0 to 9,999.9. So the built-in paths also
store the unclamped value in `ExtractedSprite.preciseSubOrder` and sort by
`ExtractedSprite.sortByDrawOrder`, which breaks integer ties with it. Y-sorting
therefore works at any y, negative included. A custom renderer that sorts by
`sortKey` alone gets the clamped window; use `sortByDrawOrder`.

### Batching

After sorting, the widget merges each run of **neighbouring** sprites that
share a texture into one batch, so painter's order holds across textures. Two
textures interleaved in draw order cost a batch per switch. Packing art that
draws together into one atlas keeps the batch count down. Within a batch, the
canvas drawer issues one `drawRawAtlas` call for every run of unflipped
sprites with uniform scale; a flipped, sheared or non-uniformly scaled sprite
is drawn on its own.

## Culling

`SpriteExtractor` skips sprites well outside the camera's view. It reads
`ActiveCameraView.visibleWorldRect` (the area shown at the last paint, which
`fledge_camera_2d` keeps up to date) and widens it by
`SpriteExtractor.cullMargin` (64 world units) plus each sprite's own size.
Before the first paint, or without a camera, nothing is culled.
`AtlasSpriteExtractor` and the particle extractor don't cull.

Scenery that never moves can carry `StaticTransform`; the extractor keeps
those sprites in a spatial grid and looks only at the cells near the view.
See [Static scenery](/docs/rendering/transforms#static-scenery).

## Backends

`RenderPlugin(backend: RenderBackend.canvas)` is the default and the only
working backend. `RenderBackend.gpu` installs `GpuSpriteDrawer`, a placeholder
for a future `flutter_gpu` path: every draw call throws `UnimplementedError`.
`RenderCapabilities.canvas` / `.gpu` describe the two backends' intended
limits; nothing in the pipeline reads them.

`CanvasSpriteDrawer.paint` is the `Paint` used for every sprite draw. It
starts with `FilterQuality.low` (bilinear); pixel art usually wants
`FilterQuality.none` (see [Pixel Art](/docs/rendering/pixel-art#texture-filtering)).

## Camera-aware drawing in your own widgets

When you draw world-space content yourself (a custom `CustomPainter`, a
minimap, a selection box), use the same camera mapping as the sprites. These
helpers read the `ActiveCameraView` resource, and fall back to world = screen
when there is none:

| Helper | Use |
|---|---|
| `withActiveCameraCanvas(world, canvas, size, body)` | Translate (and scale) the canvas to world space, run `body`, restore. |
| `paintActiveCameraView(world, canvas, size, body, devicePixelRatio:)` | The same, honouring sub-pixel scrolling; what `FledgeRenderView` uses. |
| `activeCameraScreenToWorld(world, size, point)` | A pointer position to world coordinates. |
| `activeCameraWorldToScreen(world, size, point)` | The reverse. |
| `activeCameraVisibleWorldRect(world, size)` | The world rect the widget shows. |
| `activeCameraZoom(world, size)` / `activeCameraCanvasOffset(world, size)` | The raw zoom and offset. |

`size` is the widget's size in logical pixels:

```dart
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/rendering.dart';

/// Rings every entity carrying Selected, in world space.
class Selected {}

class SelectionPainter extends CustomPainter {
  SelectionPainter(this.world, {super.repaint});
  final World world;

  @override
  void paint(Canvas canvas, Size size) {
    withActiveCameraCanvas(world, canvas, size, () {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFFFEB3B);
      for (final (_, _, global)
          in world.query2<Selected, GlobalTransform2D>().iter()) {
        canvas.drawCircle(Offset(global.x, global.y), 20, ring);
      }
    });
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) => true;
}
```

A world-space `ViewPass` is often simpler: it is drawn inside every
`FledgeRenderView`, already in world coordinates.

## Where to next

- [Sprites & Animation](/docs/rendering/sprites-animation): textures, atlases,
  clips, view passes, scene fades.
- [Transforms](/docs/rendering/transforms): hierarchy, interpolation, static
  scenery.
- [Cameras](/docs/rendering/cameras) and [Pixel Art](/docs/rendering/pixel-art).
- [Render Graph (Advanced)](/docs/rendering/render-graph): the opt-in render
  graph, materials and other types the built-in pipeline doesn't use.
- [`fledge_render_2d` API reference](https://pub.dev/documentation/fledge_render_2d/latest/).
