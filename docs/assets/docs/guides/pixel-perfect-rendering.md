# Pixel-Perfect Rendering

When building 2D pixel art games or tile-based games, you may encounter visual artifacts like **tile seams** - thin lines appearing between tiles as the camera moves. This happens due to floating-point precision when camera positions don't align to whole pixels.

## The Problem

Consider a tilemap where tiles are 48x48 pixels and should form a seamless grid:

```
Expected:                     Actual (with seams):
┌────┬────┬────┐             ┌────┐ ┌────┐ ┌────┐
│    │    │    │             │    │ │    │ │    │
├────┼────┼────┤             ├────┤ ├────┤ ├────┤
│    │    │    │             │    │ │    │ │    │
└────┴────┴────┘             └────┘ └────┘ └────┘
```

The seams appear because:

1. **Camera position** is a floating-point value (e.g., `64.3`, not `64.0`)
2. **Canvas translation** by fractional amounts causes sub-pixel rendering
3. **Tiles at grid positions** like `(0, 48, 96)` render at `(0.3, 48.3, 96.3)`
4. **GPU interpolation** creates visible gaps between adjacent tiles

## The Solution

Snap the camera position to whole pixel boundaries. Fledge provides utilities in `fledge_render_2d` to help:

### 1. Enable Pixel-Perfect Mode on Camera

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D())
  ..insert(Camera2D(pixelPerfect: true));  // Enable pixel-perfect mode
```

### 2. Snap Camera Position in Your Follow System

Use the `snapToPixel()` extension method on `Vector2`:

```dart
import 'package:fledge_render_2d/fledge_render_2d.dart';

class CameraFollowSystem extends System {
  @override
  Future<void> run(World world) async {
    // Get player position
    final (_, playerTransform) = world
        .query1<Transform2D>(filter: const With<Player>())
        .iter()
        .first;

    // Update camera
    for (final (_, cameraTransform, camera) in world
        .query2<Transform2D, Camera2D>()
        .iter()) {

      // Copy player position to camera
      cameraTransform.translation
        ..x = playerTransform.translation.x
        ..y = playerTransform.translation.y;

      // Snap to pixels if pixel-perfect mode is enabled
      if (camera.pixelPerfect) {
        cameraTransform.translation.snapToPixel();
      }
    }
  }
}
```

## Pixel-Perfect Utilities

`fledge_render_2d` provides these utilities in `pixel_perfect.dart`:

### Functions

```dart
/// Snap a double value to the nearest integer (pixel).
double snapToPixel(double value);

/// Snap a Vector2 position to the nearest pixel.
Vector2 snapVector2ToPixel(Vector2 position);

/// Snap a Vector2 position to pixels, modifying in place.
void snapVector2ToPixelInPlace(Vector2 position);
```

### Extension Methods

```dart
extension PixelPerfectVector2 on Vector2 {
  /// Returns a new Vector2 snapped to pixel boundaries.
  Vector2 get snappedToPixel;

  /// Snaps this Vector2 to pixel boundaries in place.
  void snapToPixel();
}
```

## When to Use Pixel-Perfect Rendering

**Use pixel-perfect mode for:**

- Pixel art games where visual precision matters
- Tile-based games (RPGs, platformers, strategy games)
- Any game with grid-aligned graphics
- Retro-style games with crisp pixels

**You may skip pixel-perfect mode for:**

- Games with smooth, non-pixel-art graphics
- Games where sub-pixel movement adds smoothness
- High-resolution games where 1-pixel differences are imperceptible

## Additional Considerations

### Sprite Rendering

If you're also seeing seams on animated sprites, ensure sprite positions are snapped too:

```dart
// In your sprite extraction or rendering
final snappedX = position.x.roundToDouble();
final snappedY = position.y.roundToDouble();
```

### Texture Filtering

For pixel art, use nearest-neighbor filtering instead of bilinear:

```dart
// In Flutter's canvas
final paint = Paint()
  ..filterQuality = FilterQuality.none;  // Nearest-neighbor
```

### Tile Extrusion

Another technique (used at the asset level) is **tile extrusion** - adding a 1-pixel border around each tile in your tileset that duplicates the edge pixels. This prevents edge bleeding during texture sampling.

## Complete Example

Here's a complete camera setup with pixel-perfect rendering:

```dart
// In your game plugin
class GamePlugin implements Plugin {
  @override
  void build(App app) {
    // ... other systems ...
    app.addSystem(CameraFollowSystem());
  }

  static void spawnCamera(World world) {
    world.spawn()
      ..insert(Transform2D.from(0, 0))
      ..insert(GlobalTransform2D())
      ..insert(Camera2D(pixelPerfect: true));
  }
}

// Camera follow system
class CameraFollowSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'camera_follow',
    reads: {ComponentId.of<Transform2D>(), ComponentId.of<Camera2D>()},
  );

  @override
  Future<void> run(World world) async {
    final playerQuery = world
        .query1<Transform2D>(filter: const With<Player>())
        .iter();
    if (playerQuery.isEmpty) return;

    final (_, playerTransform) = playerQuery.first;

    for (final (_, cameraTransform, camera) in world
        .query2<Transform2D, Camera2D>()
        .iter()) {
      cameraTransform.translation
        ..x = playerTransform.translation.x
        ..y = playerTransform.translation.y;

      if (camera.pixelPerfect) {
        cameraTransform.translation.snapToPixel();
      }
    }
  }
}
```

## See Also

- [Two-World Architecture](/docs/guides/two-world-architecture) - Extraction and rendering
- [Tiled Tilemaps](/docs/plugins/tiled) - Working with tilemaps
