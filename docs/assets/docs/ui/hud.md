# HUD

`fledge_ui` draws a game HUD from ECS entities: anchored text, images and
solid panels, laid out in rows, columns and stacks, painted over the game
view. It's retained-mode: UI entities live across frames and you update them
in place (change a score's text, swap a panel's size).

```yaml
dependencies:
  fledge_render_2d: ^0.7.0
  fledge_camera_2d: ^0.7.0
  fledge_ui: ^0.7.0
```

Flutter 3.50+ (Dart 3.14+); desktop first, web and mobile best-effort.
Setup:

- `RenderPlugin` before `UiPlugin` (it throws a `StateError` otherwise).
- Layout fills the `ViewportSize` resource (from `fledge_camera_2d`).
  `CameraPlugin` inserts it, and `UiPlugin` inserts it too if it's missing,
  so the camera plugin is optional and the order of the two doesn't matter.
- Keep `ViewportSize` equal to the size of the widget the HUD is painted in.
  It defaults to 1280×720 and nothing updates it for you.

`fledge_ui` is for display: its nodes aren't focusable and don't take clicks.
Build menus and dialogs from Flutter widgets over the game; see
[Controller Menus](/docs/ui/controller-menus) for making them work on a pad.
The same package's placement mode (dropping hotbar items into the world) is
covered in [Placement](/docs/gameplay/placement).

<!-- snippet-setup
late World world;
late TextureHandle heartTexture;

class ScoreLabel {}

class Score {
  int value = 0;
}
-->

## Quick start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/widgets.dart';

App buildApp() {
  final app = App()
    ..addPlugin(RenderPlugin())
    ..addPlugin(const CameraPlugin())
    ..addPlugin(const UiPlugin());

  // The score, 12 px in from the top-left corner.
  app.world.spawn()
    ..insert(const UiNode())
    ..insert(const UiAnchorComponent(UiAnchor.topLeft))
    ..insert(const UiOffset(x: 12, y: 12))
    ..insert(UiText(text: 'Score: 0', fontSize: 20));

  return app;
}

/// The game view with the HUD painted on top, keeping ViewportSize in step
/// with the space the view gets.
Widget gameWithHud(App app) => LayoutBuilder(
  builder: (context, constraints) {
    app.world.getResource<ViewportSize>()!.updateFromSize(
      constraints.biggest,
    );
    return FledgeUiOverlay(app: app, child: FledgeRenderView(app: app));
  },
);
```

`FledgeUiOverlay` is a `Stack`: its `child` (any render view) first, then a
`CustomPaint` that draws the UI. It reads fresh data whenever it paints. Like
`FledgeRenderView`, it takes an optional `repaint` listenable: pass the same
once-a-frame notifier you give the render view (see
[Rendering Overview](/docs/rendering/overview)) and the HUD repaints every
frame without a rebuild. Without it, it repaints only when rebuilt.

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/widgets.dart';

/// [frame] is bumped once a frame, after each `App.tick()`.
Widget gameWithHud(App app, ValueNotifier<int> frame) => FledgeUiOverlay(
  app: app,
  repaint: frame,
  child: FledgeRenderView(app: app, repaint: frame),
);
```

## The pipeline

1. `LayoutSystem` (`Schedules.postUpdate`) walks the UI tree from each root
   and writes a `UiComputedRect` (screen-space, logical pixels) on every
   `UiNode`.
2. `UiExtractor` (registered by `UiPlugin`) turns each laid-out node into an
   `ExtractedUiText`, `ExtractedUiImage` or `ExtractedUiRect` in the render
   world.
3. `FledgeUiOverlay` paints them in screen space: the camera doesn't move or
   zoom the HUD.

Write HUD changes in `update`, or anywhere before
`LayoutSystem.systemName`, so they're laid out the same frame:

```dart
final updateScore = FunctionSystem(
  'update_score_label',
  resourceReads: {Score},
  writes: {ComponentId.of<UiText>()},
  before: [LayoutSystem.systemName],
  run: (world) {
    final score = world.getResource<Score>()!.value;
    for (final (_, text) in world
        .query1<UiText>(filter: const With<ScoreLabel>())
        .iter()) {
      text.text = 'Score: $score';
    }
  },
);
```

## Nodes

Every UI entity carries `UiNode`. The rest is optional:

| Component | Meaning |
|---|---|
| `UiAnchorComponent(UiAnchor.x)` | Where the node sits in its parent (default `topLeft`). |
| `UiOffset(x:, y:)` | Moves it from the anchor, in logical pixels; +y is down. |
| `UiSize(width:, height:)` | An explicit size. Without it, the size comes from the content. |
| `UiContainer(...)` | Lays out the node's children. |
| `UiText`, `UiImage`, `UiRect` | What it draws (one of them; a node with none draws nothing). |

`UiAnchor` has the nine positions `topLeft`, `topCenter`, `topRight`,
`centerLeft`, `center`, `centerRight`, `bottomLeft`, `bottomCenter` and
`bottomRight`. The anchor names a point on both rects: `bottomRight` puts the
node's bottom-right corner on the parent's bottom-right corner, then
`UiOffset` moves it (use negative offsets to come in from the right or
bottom). A root node's parent rect is the viewport, `(0, 0)` to
`ViewportSize`.

### Text

```dart
world.spawn()
  ..insert(const UiNode())
  ..insert(const UiAnchorComponent(UiAnchor.topRight))
  ..insert(const UiOffset(x: -12, y: 12))
  ..insert(const UiSize(width: 160, height: 24))
  ..insert(UiText(
    text: 'Best: 0',
    fontSize: 16,
    color: const Color(0xFFFFD700),
    fontWeight: FontWeight.bold,
    align: TextAlign.right,
    fontFamily: null, // the platform default
  ))
  ..insert(ScoreLabel());
```

`text` is mutable; the other fields are final, so replace the component to
restyle. Without a `UiSize`, the node is sized by an **estimate**
(`0.55 × fontSize` per character, `1.2 × fontSize` tall), because real text
shaping only happens when painting. Give text that must fit (right-aligned,
centred, in a tight row) a `UiSize`. Text is laid out to the node's width
and wraps past it.

### Images

`UiImage(texture:, sourceRect:, tint:)` draws a texture (or the `sourceRect`
part of it) stretched to the node's rect. Without a `UiSize`, the node is the
source rect's (or the texture's) size in pixels. The overlay draws it with
`Canvas.drawImageRect`, not the sprite pipeline, resolving the texture through
the `CanvasSpriteDrawer`; if the texture can't be resolved, it fills the rect
with the tint instead. The tint multiplies the image's colour and alpha:
white leaves it unchanged, `Color(0x80FFFFFF)` fades it to half, and
`Color(0xFFFF4040)` reddens it.

```dart
world.spawn()
  ..insert(const UiNode())
  ..insert(const UiAnchorComponent(UiAnchor.bottomLeft))
  ..insert(const UiOffset(x: 12, y: -12))
  ..insert(UiImage(
    texture: heartTexture,
    sourceRect: const Rect.fromLTWH(0, 0, 16, 16),
  ))
  ..insert(const UiSize(width: 32, height: 32));
```

### Panels

`UiRect(color:, borderRadius:)` fills the node's rect, drawn with
`Canvas.drawRect` (or `drawRRect` when `borderRadius` > 0). It doesn't need
`kSolidColorTexture`. Without a `UiSize`, a `UiRect` fills its parent's
interior, which makes a panel behind its siblings easy.

## Containers and hierarchy

UI children use the ECS hierarchy (`Parent` / `Children`), so build trees with
`world.spawnChild(parent)` or `world.setParent(child, parent)`. A
`UiContainer` lays its children out inside its rect minus padding:

| `LayoutMode` | Children are |
|---|---|
| `stack` (default) | Each anchored in the whole interior, on top of each other. |
| `row` | Packed left to right, `gap` apart; each gets a slot as wide as itself and as tall as the interior, and its anchor places it vertically in that slot. |
| `column` | Packed top to bottom, the same way across. |

Padding is per side (`paddingLeft`, `paddingTop`, `paddingRight`,
`paddingBottom`), or the same on all four with `UiContainer.padded(padding:)`.
A container without a `UiSize` sizes itself to its children: the sum along a
row or column plus gaps, or the largest child for a stack, plus padding.

A health bar: a dark panel with a coloured fill, centred at the bottom.

```dart
void spawnHealthBar(World world) {
  final bar = world.spawn()
    ..insert(const UiNode())
    ..insert(const UiAnchorComponent(UiAnchor.bottomCenter))
    ..insert(const UiOffset(y: -16))
    ..insert(const UiSize(width: 204, height: 16))
    ..insert(const UiContainer.padded(padding: 2))
    ..insert(const UiRect(color: Color(0xCC000000), borderRadius: 4));

  world.spawnChild(bar.entity)
    ..insert(const UiNode())
    ..insert(const UiAnchorComponent(UiAnchor.centerLeft))
    ..insert(const UiSize(width: 200, height: 12))
    ..insert(const UiRect(color: Color(0xFFE53935), borderRadius: 2));
}

/// Shrinks the fill to [fraction] of full width. UiSize is immutable:
/// insert a new one.
void setHealth(World world, Entity fill, double fraction) {
  world.insert(fill, UiSize(width: 200 * fraction, height: 12));
}
```

`UiSize`, `UiOffset`, `UiAnchorComponent`, `UiContainer`, `UiImage` and
`UiRect` are all immutable; change them by inserting a replacement.

## Draw order

There's no z-index. Elements are drawn in the order `UiExtractor` meets them
as it walks the ECS, which groups entities by their component set and then
roughly follows spawn order. In practice, spawn a panel before what sits on
it. All UI draws over the game view, since the overlay is a separate layer
above it.

## Reference

| Type | Kind |
|---|---|
| `UiPlugin` | Adds `LayoutSystem` (`postUpdate`) and registers `UiExtractor`. |
| `UiNode`, `UiAnchorComponent`, `UiOffset`, `UiSize`, `UiContainer` | Layout components. |
| `UiText`, `UiImage`, `UiRect` | Visual components. |
| `UiComputedRect` | Layout output (screen-space `Rect`), written each frame. |
| `ExtractedUiText`, `ExtractedUiImage`, `ExtractedUiRect` | Render-world data, all `ExtractedUiElement`s. |
| `FledgeUiOverlay` | The widget that paints them over a child. |

Full signatures are in the
[API reference](https://pub.dev/documentation/fledge_ui/latest/).
