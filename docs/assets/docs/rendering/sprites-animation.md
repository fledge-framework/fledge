# Sprites & Animation

A sprite is a textured rectangle drawn at an entity's `GlobalTransform2D`.
This page covers loading textures, the `Sprite` component, sprite sheets
(texture atlases), frame animation, view passes and scene fades. It assumes
the wiring from [Rendering Overview](/docs/rendering/overview#minimum-wiring):
`RenderPlugin`, `SpriteExtractor` and `TransformPropagateSystem`.

<!-- snippet-setup
import 'package:vector_math/vector_math.dart';

late World world;
late App app;
late TextureHandle playerTexture;
late TextureHandle heroSheet;
-->

## Textures

Sprites name their texture with a `TextureHandle`: an integer id plus the
texture's width and height in pixels. The id points into the
`Assets<Texture>` resource that `RenderPlugin` inserts, where the decoded
`dart:ui` image lives. The canvas drawer looks the id up at draw time; a
handle with nothing registered under it draws nothing.

Load images before the game starts (in `initState`, or before `runApp`),
never by awaiting inside a system. From the Flutter asset bundle, which also
works on web:

```dart
import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/services.dart' show rootBundle;

Future<TextureHandle> loadTexture(App app, String asset) async {
  final data = await rootBundle.load(asset);
  final texture = await decodeTextureBytes(data.buffer.asUint8List());
  final handle = app.world.getResource<Assets<Texture>>()!.add(texture);
  return TextureHandle(
    id: handle.id.id,
    width: texture.width,
    height: texture.height,
  );
}
```

`Assets<Texture>.load(path, const FileTextureLoader())` reads from the file
system instead (desktop only, `dart:io`). It returns a handle immediately and
fills it in when the file is decoded; the size is only known after that, so
build the `TextureHandle` once `handle.isReady`.

### The solid-colour pixel

`kSolidColorTexture` is a `TextureHandle` for a 1×1 texture under the reserved
id `kSolidColorTextureId` (0). Register a white pixel there once and any
sprite using it becomes a rectangle in its `color`, sized by `customSize`:

```dart
app.world.getResource<Assets<Texture>>()!.addWithId(
  const HandleId(kSolidColorTextureId),
  Texture(createSolidColorImageSync(const Color(0xFFFFFFFF)), 1, 1),
);
```

## The Sprite component

```dart
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(Sprite(
    texture: playerTexture,
    anchor: Vector2(0.5, 1), // the transform sits at the sprite's feet
    layer: DrawLayer.characters,
  ));
```

| Field | Default | Meaning |
|---|---|---|
| `texture` | required | The `TextureHandle` to draw. |
| `sourceRect` | `null` (whole texture) | The part of the texture to draw, in texture pixels. |
| `color` | white | Tint, multiplied with the texture. Alpha fades the sprite; a fully transparent sprite is skipped. |
| `anchor` | `(0.5, 0.5)` | The point inside the sprite that sits on the transform, from `(0, 0)` top-left to `(1, 1)` bottom-right. Rotation and scale pivot here too. |
| `customSize` | `null` | Size in world units. Without it, the source rect's size in pixels. |
| `flipX`, `flipY` | `false` | Mirror the sprite in its own space, about the anchor. A rotated sprite stays where it is. |
| `layer`, `layerSubOrder` | `characters`, `0` | Draw order: see [Draw order](/docs/rendering/overview#draw-order). `0` means y-sorted. |
| `emissive` | `false` | Drawn after the view passes, so lighting doesn't darken it. |

`Sprite.region(texture:, region:)` is shorthand for a sprite with a
`sourceRect`. All fields are mutable: change `sourceRect` to switch frames,
`color` to flash on a hit.

### Hiding a sprite

Add a `Visibility` component. It holds a bool, `isVisible`, with `hide()`,
`show()` and `toggle()`:

```dart
final entity = world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(Sprite(texture: playerTexture))
  ..insert(Visibility(false)); // starts hidden

world.get<Visibility>(entity.entity)!.show();
```

### SpriteBundle

`SpriteBundle` inserts a `Sprite`, a `Transform2D` and a `GlobalTransform2D`
(plus `Visibility(false)` when `visible: false`) in one call:

```dart
SpriteBundle(
  texture: playerTexture,
  x: 100,
  y: 200,
  rotation: 0.3,
  scaleX: 2,
  scaleY: 2,
).spawn(world);
```

Use `SpriteBundle.fromComponents(...)` to pass your own components, and
`insertInto(commands)` to add them to an existing entity.

## Texture atlases

A texture atlas (sprite sheet) packs many frames into one texture. Besides
saving memory, sprites sharing a texture batch into one draw call.

```dart
final atlas = TextureAtlas.grid(
  texture: heroSheet,
  columns: 8,
  rows: 4,
  // Optional: cell size (default: texture size / columns, rows),
  // gaps between cells, and the margin before the first cell.
  tileWidth: 32,
  tileHeight: 32,
  paddingX: 1,
  paddingY: 1,
  offsetX: 0,
  offsetY: 0,
  names: {'idle': 0, 'jump': 9},
);

final idle = atlas.createSprite(0);           // a Sprite on frame 0
final jump = atlas.createSpriteByName('jump'); // a Sprite on frame 9
final rect = atlas.getSpriteRect(5);           // frame 5's source rect
```

For sheets packed by a tool, list the rectangles yourself:

```dart
final atlas = TextureAtlas(
  texture: heroSheet,
  layout: TextureAtlasLayout.fromRects([
    const Rect.fromLTWH(0, 0, 32, 48),
    const Rect.fromLTWH(32, 0, 24, 48),
  ]),
);
```

### AtlasSprite

`AtlasSprite` draws one frame of an atlas, chosen by `index`. It has its own
`color`, `flipX`, `flipY`, `anchor`, `layer` and `layerSubOrder`, and
`setByName(name)` for named frames. Swap `atlas` to change sheets (another
outfit) while keeping the frame.

There are two ways to draw it:

- **`AtlasSprite` alone**, drawn by `AtlasSpriteExtractor`. Register it next
  to `SpriteExtractor`. This extractor doesn't cull off-screen sprites, doesn't
  use the `StaticTransform` grid, and has no `emissive` option.
- **`AtlasSprite` with a `Sprite`** on the same entity, drawn by
  `SpriteExtractor`. The animation systems copy the atlas frame's source rect
  and flips into the `Sprite` each frame, so you keep culling and
  `emissive`. Size the `Sprite` (`customSize`) or give it the first frame's
  `sourceRect`.

Don't register `AtlasSpriteExtractor` if your entities carry both
components: they would be drawn twice.

## Animation

An `AnimationClip` is a named list of frames, each an atlas index and a
duration in seconds. An `AnimationPlayer` holds a set of clips and plays one
at a time.

```dart
final player = AnimationPlayer(
  animations: {
    'idle': AnimationClip.fromIndices(
      name: 'idle',
      startIndex: 0,
      endIndex: 3,
      frameDuration: 0.15,
    ),
    'walk': AnimationClip.fromIndexList(
      name: 'walk',
      indices: [8, 9, 10, 9],
      frameDuration: 0.1,
    ),
    'attack': AnimationClip.withDurations(
      name: 'attack',
      indices: [16, 17, 18],
      durations: [0.05, 0.05, 0.3],
      looping: false,
    ),
  },
  initialAnimation: 'idle',
);

world.spawn()
  ..insert(Transform2D.from(100, 100))
  ..insert(AtlasSprite(atlas: TextureAtlas.grid(
    texture: heroSheet,
    columns: 8,
    rows: 4,
  )))
  ..insert(player);
```

`play(name)` switches clip (it does nothing if that clip is already playing,
unless `restart: true`). `pause()`, `resume()`, `stop()` and `toggle()` do
what they say, `speed` scales time, and `progress` / `setProgress` read and
seek. A clip with `looping: false` stops on its last frame; `update` returns
`true` on the frame it finishes, and `isStopped` turns true.

### The animation systems

Each frame an animation system advances every `AnimationPlayer`, writes the
current frame into the entity's `AtlasSprite.index`, and, when the entity also
has a `Sprite`, copies the frame's source rect and flips into it. Neither
system is registered by `RenderPlugin`, and both need to be told the frame
time:

- `AnimateSystem` reads its public `deltaTime` field, which you set before
  every tick. It stays at 0 (nothing moves) unless you do.
- `AnimateSystemWithResource` reads an `AnimationTime` resource. Nothing writes
  that resource for you; copy `WallTime.delta` into it:

```dart
App buildApp() => App()
  ..addPlugin(WallTimePlugin())
  ..insertResource(AnimationTime())
  ..addSystem(
    FunctionSystem(
      'animation_clock',
      resourceReads: {WallTime},
      resourceWrites: {AnimationTime},
      before: [AnimateSystemWithResource.systemName],
      run: (world) {
        world.getResource<AnimationTime>()!.deltaTime =
            world.getResource<WallTime>()!.delta;
      },
    ),
    schedule: Schedules.update,
  )
  ..addSystem(AnimateSystemWithResource(), schedule: Schedules.update);
```

Order your own animation logic (picking a clip from movement, say) with
`before: [AnimateSystemWithResource.systemName]` (or
`AnimateSystem.systemName`).

### Facing

`Orientation` holds one of four `Direction`s and updates from a velocity
(`updateFromVelocity(vx, vy)`, dominant axis wins). `Direction.suffix` gives
`'_down'` and so on, handy for clip names like `'walk_down'`. For 8-, 16- or
any-number-of-view sprites, `Facing` keeps a continuous angle (radians, `0` =
+x, clockwise on screen like `Transform2D.rotation`) and picks the nearest
view:

```dart
final facing = Facing()..updateFromVector(3, 4);
final view = facing.viewIndex(16); // 0 = right, 4 = down, 8 = left, 12 = up
final four = facing.direction;     // the nearest of the four Directions
```

`updateFromVector` ignores a zero vector (and anything shorter than
`minLength`), so a character keeps facing the way it last moved.

## View passes

A `ViewPass` draws world-space content inside every `FledgeRenderView`,
through the same camera mapping as the sprites, so it lines up and scrolls
with them. Add one to the `ViewPasses` resource; the frame is drawn in this
order:

1. every pass's `paintBehind`;
2. the sprites that aren't `emissive`;
3. every pass's `paintOver`;
4. the emissive sprites.

`LightingPlugin` uses this to darken the scene in `paintOver` while lit
windows (emissive sprites) stay bright. A pass of your own:

```dart
/// Tints the whole view red while the player is hurt.
class HurtTint extends ViewPass {
  const HurtTint();

  @override
  void paintOver(World world, Canvas canvas, Rect visibleWorld) {
    canvas.drawRect(visibleWorld, Paint()..color = const Color(0x40FF0000));
  }
}

void addHurtTint(App app) =>
    app.world.getResource<ViewPasses>()!.add(const HurtTint());
```

`visibleWorld` is the world rect the camera shows, and the canvas is already
in world coordinates.

## Scene fades

`TransitionState` (a resource) runs a fade-to-black between scenes:
`idle → fadeOut → loading → fadeIn → idle`. `TransitionFadeSystem` advances
`fadeProgress` (0 = clear, 1 = black) by `WallTime.delta / fadeDuration`, and
sends a `TransitionCompleted` event (carrying `scene` and `metadata`) when the
fade-in ends. Your code handles the `loading` phase and draws the overlay:

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(RenderPlugin()) // registers the TransitionCompleted event
  ..insertResource(TransitionState(fadeDuration: 0.4))
  ..addSystem(const TransitionFadeSystem(), schedule: Schedules.update)
  ..addSystem(
    FunctionSystem(
      'load_scene',
      resourceWrites: {TransitionState},
      after: [TransitionFadeSystem.systemName],
      run: (world) {
        final t = world.getResource<TransitionState>()!;
        if (t.phase != TransitionPhase.loading) return;
        // Despawn the old scene and spawn t.targetScene here
        // (t.metadata carries spawn points and the like).
        t.beginFadeIn();
      },
    ),
    schedule: Schedules.update,
  );

// Somewhere in gameplay:
app.world.getResource<TransitionState>()!.requestTransition(
  'cave',
  metadata: {'spawnX': 40, 'spawnY': 80},
);
```

Draw the fade over the game (a view pass in `paintOver`, or a Flutter widget
on top) with black at `fadeProgress` opacity. If loading needs to await
something, start it in the background, set `isLoadingAsync` so you don't start
it twice, and call `beginFadeIn()` on a later frame when it is done.
`cancel()` only works during `fadeOut`. For camera-level fades and wipes, see
[Cameras](/docs/rendering/cameras#transitions).

See the [API reference](https://pub.dev/documentation/fledge_render_2d/latest/)
for every member.
