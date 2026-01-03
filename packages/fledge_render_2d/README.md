# fledge_render_2d

2D rendering components for [Fledge](https://fledge-framework.dev) games. Sprites, cameras, animation, and texture atlases.

[![pub package](https://img.shields.io/pub/v/fledge_render_2d.svg)](https://pub.dev/packages/fledge_render_2d)

## Features

- **Transform2D**: Position, rotation, and scale with hierarchy support
- **Camera2D**: Orthographic camera with viewport control
- **Sprites**: Textured quad rendering with materials
- **Texture Atlases**: Sprite sheets with frame-based animation
- **Animation**: Clip-based animation with playback control
- **Pixel Perfect**: Utilities for crisp pixel art rendering

## Installation

```yaml
dependencies:
  fledge_render_2d: ^0.1.0
```

## Transforms

Use `Transform2D` for local transforms relative to parent:

```dart
import 'dart:math' as math;

world.spawn()
  ..insert(Transform2D(
    translation: Vector2(100, 200),
    rotation: math.pi / 4,
    scale: Vector2.all(2),
  ));
```

The `TransformPropagateSystem` computes `GlobalTransform2D` from the entity hierarchy.

## Camera

Create a camera with `Camera2D`:

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(Camera2D(
    projection: OrthographicProjection(viewportHeight: 20),
    pixelPerfect: true,  // Snap to pixels for crisp rendering
  ));
```

## Sprites

Render textured quads with `Sprite`:

```dart
world.spawn()
  ..insert(Sprite(texture: playerTexture))
  ..insert(Transform2D.from(100, 200));
```

Or use `SpriteBundle` for convenience:

```dart
SpriteBundle(texture: playerTexture, x: 100, y: 200).spawn(world);
```

## Texture Atlases

Work with sprite sheets:

```dart
final atlas = TextureAtlas.fromGrid(
  texture: spriteSheet,
  columns: 8,
  rows: 4,
);

world.spawn()
  ..insert(AtlasSprite(atlas: atlas, index: 0))
  ..insert(Transform2D.from(100, 200));
```

## Animation

Create and play animations:

```dart
final walkClip = AnimationClip(
  name: 'walk',
  frameIndices: [0, 1, 2, 3],
  frameDuration: Duration(milliseconds: 100),
);

world.spawn()
  ..insert(AtlasSprite(atlas: characterAtlas, index: 0))
  ..insert(AnimationPlayer(clip: walkClip, autoPlay: true))
  ..insert(Transform2D.from(100, 200));
```

## Character Orientation

Track entity facing direction:

```dart
world.spawn()
  ..insert(Orientation(Direction.right))
  ..insert(Velocity(x: 10, y: 0));

// The Orientation.updateFromVelocity() method updates direction from movement
```

## Documentation

See the [Rendering Guide](https://fledge-framework.dev/docs/guides/rendering) and [Pixel-Perfect Rendering](https://fledge-framework.dev/docs/guides/pixel-perfect-rendering) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_render](https://pub.dev/packages/fledge_render) - Render infrastructure
- [fledge_render_flutter](https://pub.dev/packages/fledge_render_flutter) - Flutter backend
- [fledge_tiled](https://pub.dev/packages/fledge_tiled) - Tilemap rendering

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
