# Render Graph (Advanced)

`fledge_render_2d` exports a set of render-pipeline building blocks that the
**built-in pipeline doesn't use**: a render graph with typed slots, a staged
render schedule, render layers and materials. They're opt-in. A game that
uses `FledgeRenderView` never touches them, and turning them on doesn't
change what `FledgeRenderView` draws.

Read [Rendering Overview](/docs/rendering/overview) first: the default path
(extract into the `RenderWorld`, then `FledgeRenderView` sorts, batches and
draws) covers sprites, tilemaps, particles, lighting and UI. Reach for these
pieces only for a custom painter or an experiment. For extra world-space
drawing inside the normal view, a
[view pass](/docs/rendering/sprites-animation#view-passes) is simpler.

<!-- snippet-setup
import 'package:fledge_render_2d/fledge_render_2d.dart' as r2d;
-->

## The render graph

A `RenderGraph` holds `RenderNode`s and runs them in dependency order. Nodes
declare input and output **slots** (`SlotInfo(name:, type:, required:)`), and
`addEdge(SlotId(from, 'out'), SlotId(to, 'in'))` connects an output to an
input; the graph sorts nodes so producers run before consumers, and rejects
edges between slots of different `SlotType`s (unless one is
`SlotType.custom`).

```dart
/// Draws a world-space grid every 64 units.
class GridNode extends RenderNode {
  @override
  String get name => 'grid';

  @override
  void run(RenderGraphContext graph, Object context) {
    if (context is! SpriteRenderContext) return;
    final canvas = context.canvas;
    if (canvas == null) return;
    final paint = Paint()..color = const Color(0x22FFFFFF);
    for (var x = 0.0; x <= 2048; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, 2048), paint);
    }
    for (var y = 0.0; y <= 2048; y += 64) {
      canvas.drawLine(Offset(0, y), Offset(2048, y), paint);
    }
  }
}

final graph = RenderGraph()
  ..addNode(GridNode())
  ..addNode(SpriteRenderNode());
```

`execute(context)` checks that every `required` input is connected (throwing
`MissingInputError`), sorts the nodes (`RenderGraphCycleError` on a cycle),
and runs each one. Inside a node, `graph.getInput<T>('slot')` reads an input
and `graph.setOutput('slot', SlotValue(type, value))` writes an output.
`addNodeAfter(node, 'other')` adds a node and connects slots with matching
names and types. Nodes with no edges between them run in insertion order.

**One context for every node.** `execute` hands the same `context` object to
every node. The built-in `SpriteRenderNode` throws unless it gets a
`SpriteRenderContext`, and `CameraDriverNode` (in `fledge_camera_2d`) throws
unless it gets a `CameraDriverContext`, so as shipped those two can't run in
the same graph. Your own nodes should check the context type and skip what
they don't understand, as `GridNode` does.

### Drawing sprites through a graph

`SpriteRenderNode` draws the `SpriteBatches` resource of the render world,
which `SpriteBatchSystem` builds from the extracted sprites (sorted with
`ExtractedSprite.sortByDrawOrder`, contiguous same-texture runs merged, as in
the widget path). Run the batch step after extraction, and execute the graph
from a painter of your own:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/rendering.dart';

/// Builds SpriteBatches each frame, after extraction.
final spriteBatching = FunctionSystem(
  'sprite_batch',
  resourceWrites: {RenderWorld},
  run: (world) {
    // SpriteBatchSystem.run is declared async but does all its work
    // before returning, so the batches exist once the call returns.
    SpriteBatchSystem().run(world, world.getResource<RenderWorld>()!);
  },
);
// app.addSystem(spriteBatching, schedule: Schedules.render);

class GraphPainter extends CustomPainter {
  GraphPainter(this.app, this.graph, {super.repaint});
  final App app;
  final RenderGraph graph;

  @override
  void paint(Canvas canvas, Size size) {
    final renderWorld = app.world.getResource<RenderWorld>()!;
    final drawer = app.world.getResource<SpriteDrawer>()!;
    withActiveCameraCanvas(app.world, canvas, size, () {
      if (drawer is CanvasSpriteDrawer) drawer.beginFrame(canvas);
      try {
        graph.execute(SpriteRenderContext(
          renderWorld: renderWorld,
          drawer: drawer,
          canvas: canvas,
        ));
      } finally {
        if (drawer is CanvasSpriteDrawer) drawer.endFrame();
      }
    });
  }

  @override
  bool shouldRepaint(GraphPainter oldDelegate) => true;
}
```

`SpriteRenderNode` has an optional `view` input of `SlotType.camera`. When a
`CameraView` arrives there, its `viewProjection` matrix is passed to the
drawer, which applies it to the canvas as is. That matrix maps the world to
clip space (−1..1), not to pixels, so a graph that feeds it also has to map
clip space onto the canvas itself. The painter above uses the
`ActiveCameraView` mapping instead and leaves `view` unconnected.

### CameraDriverNode

`CameraDriverNode(RenderSize screenSize)` from `fledge_camera_2d` picks the
lowest-`order` active `Camera2D` and outputs a `CameraView(entity,
viewProjection, viewport)` on its `view` slot. It reads cameras from the
**render world**, and nothing extracts cameras there by default, so you need
an extractor that copies `Camera2D` + `GlobalTransform2D` across. It is the
only code that reads `Camera2D.viewport`; split-screen in the widget path
isn't supported.

## Render schedule and stages

`RenderSchedule` is a standalone, async stage runner, separate from the
app's scheduler:

```dart
Future<void> runRenderStages(World mainWorld, RenderWorld renderWorld) async {
  final schedule = RenderSchedule()
    ..addSyncSystem(RenderStage.prepare, 'prepare', (main, render) {
      // runs after extraction, before queue
    })
    ..addSystem(RenderStage.queue, SpriteBatchSystem());

  // Clears the render world, runs the Extractors resource of mainWorld,
  // then every stage in order.
  await schedule.run(mainWorld, renderWorld);
}
```

Stages run in `RenderStage` order: `extract`, `prepare`, `queue`, `render`,
`cleanup`. A stage holds `RenderSystem`s (`name` plus
`Future<void> run(World mainWorld, RenderWorld renderWorld)`);
`FunctionRenderSystem` and `SyncRenderSystem` wrap closures. Nothing in the
app runs a `RenderSchedule`: if you use one, you call `run` yourself, and
since it's async, not from inside a tick. `ExtractSystem` is the plain
"clear, then run every extractor" step it uses, the same work
`RenderExtractionSystem` does in `Schedules.extract`.

## Render layers

`RenderLayer` is a `paint(Canvas canvas, Size size, RenderWorld renderWorld)`
interface for composing a custom painter, with `CompositeRenderLayer` (a
list), `TransformedRenderLayer` (applies a `Matrix4`), `ClippedRenderLayer`
(clips to a rect) and `ConditionalRenderLayer` (paints when a callback says
so). `FledgeRenderView` doesn't use them.

## Other pieces

- `ExtractComponent<T>` is a marker interface (`T extract()`). Nothing
  discovers components that implement it; register an `Extractor` instead.
- `RenderContext` (screen size, frame number, delta and total time) is an
  interface with no implementation in the framework.
- `RenderCapabilities.canvas` and `.gpu` describe backend limits; nothing
  reads them. The GPU backend itself is a placeholder that throws (see
  [Backends](/docs/rendering/overview#backends)).
- `SpriteInstance`, `SpriteBatch`, `BackendSpriteData` and
  `composeSpriteRSTransform` are the data the batch and drawer pass around;
  implement `SpriteDrawer` (`drawSpriteBatch(texture, batch)`) and insert it
  as the `SpriteDrawer` resource to replace the canvas drawer.

## Materials

`SpriteMaterial`, `ColorMaterial` and `ShaderMaterial` (with `ShaderHandle`,
the `UniformValue` types and the `ShaderEffects` presets such as
`ShaderEffects.grayscale()`) are **data only**. The built-in drawers ignore
materials completely: sprites draw with their `Sprite.color` tint through
`Canvas.drawRawAtlas` with `BlendMode.modulate`, and no shader is ever
compiled or bound. `SpriteMaterial.normalMap` is likewise unused.

Their `BlendMode` enum (`normal`, `additive`, `multiply`, `screen`, `none`)
shares its name with `dart:ui`'s `BlendMode`; prefix or hide one when you
import both:

```dart
final glow = r2d.ColorMaterial(
  color: const Color(0xFFFFE082),
  blendMode: r2d.BlendMode.additive,
);
```

To draw with a real `FragmentProgram` today, do it yourself in a view pass or
a custom painter.

See the [API reference](https://pub.dev/documentation/fledge_render_2d/latest/)
for every member.
