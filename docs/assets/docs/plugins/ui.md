# UI

The `fledge_ui` package provides retained-mode game HUD/UI for Fledge — anchor-based layout, containers, text, images, and solid panels painted on top of the sprite pipeline.

Retained-mode means UI entities live in the ECS across frames and are updated in place. `LayoutSystem` walks the UI hierarchy once per frame and writes a `UiComputedRect` on every UI entity; the extractor copies that into the render world; `FledgeUiOverlay` paints the result on top of any Fledge render view.

## Installation

```yaml
dependencies:
  fledge_ui: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/material.dart';

void main() {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const CameraPlugin())
    ..addPlugin(const UiPlugin());

  // Score display in the top-left corner.
  app.world.spawn()
    ..insert(const UiNode())
    ..insert(const UiAnchorComponent(UiAnchor.topLeft))
    ..insert(const UiOffset(x: 12, y: 12))
    ..insert(UiText(text: 'Score: 0', fontSize: 20));

  runApp(FledgeUiOverlay(app: app, child: FledgeRenderView(app: app)));
}
```

## Core concepts

### UiNode

Marker component: this entity is a UI node. Excludes it from world-space sprite extractors (they should filter on `Without<UiNode>` to avoid drawing the UI entity's texture in world space by mistake). `UiExtractor` handles UI entities separately.

### UiSize and UiOffset

`UiSize` is an optional explicit size in logical pixels. If absent, size derives from the node's content — text extent, image size, or the sum of children in a row/column container.

```dart
const UiSize(width: 200, height: 40)
```

`UiOffset` is a screen-space offset from the anchor point. Positive x moves right, positive y moves down (screen coordinates).

```dart
const UiOffset(x: 12, y: 12)
```

### UiAnchor and UiAnchorComponent

`UiAnchor` is a nine-way anchor within the parent's padded interior (or the viewport, for root nodes):

```dart
UiAnchor.topLeft   UiAnchor.topCenter   UiAnchor.topRight
UiAnchor.centerLeft UiAnchor.center     UiAnchor.centerRight
UiAnchor.bottomLeft UiAnchor.bottomCenter UiAnchor.bottomRight
```

The anchor is a point on both the parent's rect and the child's own rect. The child is positioned so those two points coincide, then offset by `UiOffset`. This mirrors the "align + position" model used by Flutter's `Align` widget and CSS.

Attach via `UiAnchorComponent(UiAnchor.topLeft)`. The wrapper exists so that the enum `UiAnchor` — the far more common thing to type — stays short.

### UiContainer

Lays out its children according to a `LayoutMode`:

| Mode | Behaviour |
|------|-----------|
| `LayoutMode.stack` | Children share the same anchored position (last child on top). |
| `LayoutMode.row` | Children laid out left-to-right with `gap` pixels between each. |
| `LayoutMode.column` | Children laid out top-to-bottom with `gap` pixels between each. |

Padding trims the interior rect used for laying out children — the container's outer rect is what gets anchored inside *its* parent.

```dart
world.spawn()
  ..insert(const UiNode())
  ..insert(const UiAnchorComponent(UiAnchor.bottomCenter))
  ..insert(const UiContainer.padded(
    mode: LayoutMode.row,
    gap: 8,
    padding: 12,
  ));
```

Children are discovered through the existing `fledge_ecs` hierarchy (`Parent` / `Children` components).

### UiText

```dart
UiText(
  text: 'Score: 0',
  fontSize: 20,
  color: const Color(0xFFFFFFFF),
  fontFamily: 'Menlo',           // null uses Flutter's platform default
  fontWeight: FontWeight.bold,
  align: TextAlign.left,
)
```

Text is rendered directly on the widget's canvas via `Canvas.drawParagraph` — it bypasses the sprite pipeline, since dart:ui text shaping is a separate concern from atlas draws.

The `text` field is deliberately **mutable** — games update HUD content in place (score counters, lap timers, life bars) without spawning new entities per frame.

### UiImage

A texture-backed UI node:

```dart
world.spawn()
  ..insert(const UiNode())
  ..insert(const UiAnchorComponent(UiAnchor.topRight))
  ..insert(UiImage(
    texture: hudIconHandle,
    tint: const Color(0xFFFFFFFF),
  ));
```

Rendered through the sprite pipeline at `DrawLayer.ui` so the same backend batching path handles UI images and gameplay sprites.

### UiRect

A solid-colour panel — background for dialog boxes, health bars, cards:

```dart
UiRect(color: Color(0xFF202030), borderRadius: 8)
```

With `borderRadius: 0.0`, `UiRect` is rendered by tinting `kSolidColorTexture` (a 1×1 white pixel registered by the render plugin) through the sprite path. With a non-zero radius, the extractor emits a dedicated `ExtractedUiRect` and the widget paints it via `Canvas.drawRRect` — the sprite pipeline has no per-quad geometry override for rounded rects.

## UiPlugin

`UiPlugin` requires `RenderPlugin` to be added first — it registers a `UiExtractor` on the shared `Extractors` resource, and throws a `StateError` if the resource isn't present.

```dart
final app = App()
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin())
  ..addPlugin(const UiPlugin());
```

The plugin adds:

- `LayoutSystem` in `Schedules.postUpdate` — walks the UI hierarchy, writes `UiComputedRect`.
- `UiExtractor` on the shared `Extractors` — mirrors laid-out UI into the render world as `ExtractedUiElement`s.

## FledgeUiOverlay

A widget wrapper that layers a UI paint pass on top of any Fledge render view (`FledgeRenderView`, `LitFledgeRenderView`, or a custom subclass):

```dart
FledgeUiOverlay(
  app: app,
  child: FledgeRenderView(app: app),
)
```

The overlay reads the extracted UI elements from the render world and paints text via `Canvas.drawParagraph`, images and rects via the sprite path, and rounded rects via `Canvas.drawRRect`.

## Common patterns

### Health bar

```dart
final container = world.spawn()
  ..insert(const UiNode())
  ..insert(const UiAnchorComponent(UiAnchor.topLeft))
  ..insert(const UiOffset(x: 12, y: 12))
  ..insert(const UiContainer(mode: LayoutMode.stack))
  ..insert(const UiSize(width: 160, height: 12));

world.spawn()
  ..insert(const UiNode())
  ..insert(Parent(container.entity))
  ..insert(const UiAnchorComponent(UiAnchor.topLeft))
  ..insert(const UiRect(color: Color(0xFF400000)));

final fill = world.spawn()
  ..insert(const UiNode())
  ..insert(Parent(container.entity))
  ..insert(const UiAnchorComponent(UiAnchor.topLeft))
  ..insert(UiSize(width: 160, height: 12))
  ..insert(const UiRect(color: Color(0xFFFF3030)));

// In a system, resize the fill entity to reflect current HP.
world.get<UiSize>(fill.entity).width = 160 * (hp / maxHp);
```

### Score counter

```dart
final entity = world.spawn()
  ..insert(const UiNode())
  ..insert(const UiAnchorComponent(UiAnchor.topRight))
  ..insert(const UiOffset(x: -12, y: 12))
  ..insert(UiText(text: 'Score: 0', fontSize: 24));

// In a system:
world.get<UiText>(entity.entity).text = 'Score: $score';
```

## Placement mode

Since v0.3.0 `fledge_ui` ships a generic placement mode — the state
machine, event vocabulary, validator seam, ghost preview and record
registry a Stardew-adjacent game (furniture, machines, crops) needs
without any per-game rules.

### Overview

- **`PlacementState` resource** — the one placement in progress:
  `mode`, `placeableKey`, `previewTile`, `isValid`, `refusalReason`.
  Written only by `PlacementSystem`.
- **Request events** — `PlacementEnterRequested(key)`,
  `PlacementPreviewRequested(mapKey, x, y)`,
  `PlacementConfirmRequested`, `PlacementCancelRequested`. Sent from
  input systems, HUD widgets, or game systems.
- **Notification events** — `PlacementEntered`, `PlacementPreviewMoved`,
  `PlacementConfirmed`, `PlacementCancelled`.
- **`PlacementValidator`** — game-supplied rule: `bool isValid(world,
  key, tile)` + optional `refusalReason(...)`. Pure reads only;
  declare what it reads via `PlacementAccess` on the plugin's
  `validatorAccess:` parameter.
- **`PlacedEntityRegistry<TRecord>`** — per-map placed records with a
  deterministic `allocateId(prefix)`. Not `Saveable` (that would pull
  `fledge_save` in); the game wraps it in its own saved resource.
- **`PlacementGhost` / `PlacementGhostSystem`** — one world-space
  sprite entity at the preview tile, tinted for validity.

### Setup

```dart
app.addPlugin(PlacementCorePlugin(
  validator: MyValidator(),
  ghost: PlacementGhostConfig(
    tileToWorld: (tile) => (tile.x * 16.0, tile.y * 16.0),
    ghostSpriteFor: (world, key) => Sprite(texture: textureFor(key)),
  ),
));
```

### Placement flow

```dart
// Enter placement mode from a hotbar selection.
world.eventWriter<PlacementEnterRequested>().send(
  const PlacementEnterRequested('chair'),
);

// Update the preview tile from the player's facing direction.
world.eventWriter<PlacementPreviewRequested>().send(
  PlacementPreviewRequested(currentMap.id, tileX, tileY),
);

// Confirm.
world.eventWriter<PlacementConfirmRequested>().send(
  const PlacementConfirmRequested(),
);
```

React to `PlacementConfirmed` in a game system: spawn the entity,
decrement inventory, register a record.

### Run condition

Gate gameplay while placing:

```dart
app.addSystem(
  npcSteeringSystem,
  schedule: Schedules.update,
  runCondition: RunConditions.not(placementActive),
);
```

## Roadmap

- **Phase 7b**: focus + keyboard / gamepad navigation.
- Later: flexbox / grid layouts, theming, retained text-shape caching, animation.

## Components reference

| Component | Description |
|-----------|-------------|
| `UiNode` | Marker: this entity is a UI node. |
| `UiSize` | Optional explicit size in logical pixels. |
| `UiOffset` | Offset from the anchor point. |
| `UiAnchorComponent` | Wraps a `UiAnchor` enum value. |
| `UiContainer` | Row / column / stack layout with padding and gap. |
| `UiText` | A text node with mutable text. |
| `UiImage` | A textured UI node. |
| `UiRect` | A solid-colour panel with optional border radius. |
| `UiComputedRect` | Output of `LayoutSystem` — the entity's screen-space rect. |

## See also

- [2D Rendering](/docs/plugins/render) — `RenderPlugin`, `FledgeRenderView`, `Extractors`.
- [Debug](/docs/plugins/debug) — the debug overlay is a `UiPlugin` client.
- [Plugins Overview](/docs/plugins/overview)
