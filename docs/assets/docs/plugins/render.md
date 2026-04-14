# 2D Rendering

The `fledge_render_2d` package provides 2D game components for Fledge: transforms, sprites, cameras, texture atlases, and animation.

> For core render infrastructure (RenderPlugin, Extractors, RenderWorld, RenderLayer), see [Render Infrastructure](/docs/plugins/render_plugin).

## Installation

```yaml
dependencies:
  fledge_render: ^0.1.0     # Core infrastructure
  fledge_render_2d: ^0.1.0  # 2D components
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

void main() async {
  final app = App()
    .addPlugin(TimePlugin())
    .addPlugin(RenderPlugin())  // Sets up extraction automatically
    // Add 2D render systems
    .addSystem(TransformPropagateSystem())
    .addSystem(AnimateSystemWithResource());

  // Register extractors
  final extractors = app.world.getResource<Extractors>()!;
  extractors.register(SpriteExtractor());

  // Spawn a camera
  app.world.spawn()
    ..insert(Transform2D.from(0, 0))
    ..insert(GlobalTransform2D())
    ..insert(Camera2D());

  // Spawn a sprite
  app.world.spawn()
    ..insert(Transform2D.from(100, 200))
    ..insert(GlobalTransform2D())
    ..insert(Sprite(texture: playerTexture));

  await app.run();
}
```

## Transform2D

`Transform2D` represents local position, rotation, and scale relative to parent entities.

### Creating Transforms

```dart
// Full constructor
Transform2D(
  translation: Vector2(100, 200),
  rotation: math.pi / 4,  // 45 degrees in radians
  scale: Vector2(2, 2),
)

// Convenience for position-only
Transform2D.from(100, 200)

// Identity (origin, no rotation, scale 1)
Transform2D.identity()
```

### Modifying Transforms

```dart
final transform = entity.get<Transform2D>()!;

// Direct property access
transform.translation.x += 10;
transform.rotation = math.pi;
transform.scale.setValues(2, 2);

// Helper methods
transform.translate(10, 5);           // Add to position
transform.rotate(math.pi / 4);        // Add to rotation
transform.setRotationDegrees(90);     // Set in degrees
transform.setUniformScale(2.0);       // Set scale uniformly
```

### GlobalTransform2D

`GlobalTransform2D` is computed from the entity hierarchy. It represents the final world-space transform.

```dart
// Read-only - computed by TransformPropagateSystem
final global = entity.get<GlobalTransform2D>()!;
print('World position: (${global.x}, ${global.y})');

// Get as matrix for rendering
final matrix = global.matrix;
```

Add `TransformPropagateSystem` to your app to automatically compute global transforms from the parent-child hierarchy.

## Sprites

`Sprite` is the primary component for rendering textured quads.

### Basic Sprite

```dart
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(Sprite(texture: myTexture));
```

### Sprite Options

```dart
Sprite(
  texture: myTexture,
  sourceRect: Rect.fromLTWH(0, 0, 32, 32),  // Sub-region of texture
  color: Color(0xFFFF0000),                   // Tint color
  flipX: true,                                 // Horizontal flip
  flipY: false,                                // Vertical flip
  anchor: Vector2(0.5, 0.5),                  // Center anchor (default)
  customSize: Vector2(64, 64),                // Override size
)
```

### Anchor Points

The anchor determines the sprite's pivot point:

| Anchor | Position |
|--------|----------|
| `Vector2(0, 0)` | Top-left |
| `Vector2(0.5, 0.5)` | Center (default) |
| `Vector2(0.5, 1.0)` | Bottom-center |
| `Vector2(1, 1)` | Bottom-right |

### Visibility

Hide entities from rendering without removing them:

```dart
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(Sprite(texture: myTexture))
  ..insert(Visibility(true));

// Toggle visibility
entity.get<Visibility>()!.toggle();
entity.get<Visibility>()!.hide();
entity.get<Visibility>()!.show();
```

### SpriteBundle

Convenience for spawning sprites with common components:

```dart
SpriteBundle(
  texture: playerTexture,
  x: 100,
  y: 200,
  anchor: Vector2(0.5, 1.0),
).spawn(world);
```

## Cameras

`Camera2D` defines the viewable area of the world.

### Transform2D vs GlobalTransform2D

Cameras use both transform types for different purposes:

| Transform | When to Use | Example |
|-----------|-------------|---------|
| `Transform2D` | **Setting** camera position (local coordinates) | Moving camera, following player |
| `GlobalTransform2D` | **Reading** camera position for rendering (world coordinates) | Screen-to-world conversion, visibility culling |

`GlobalTransform2D` is automatically computed by `TransformPropagateSystem` from the entity hierarchy. Always use `GlobalTransform2D` when you need the camera's actual world position for rendering calculations.

### Creating a Camera

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))       // Local position (modifiable)
  ..insert(GlobalTransform2D())           // World position (computed)
  ..insert(Camera2D(
    projection: OrthographicProjection(viewportHeight: 20),
  ));
```

### Orthographic Projection

```dart
OrthographicProjection(
  viewportHeight: 20,    // World units visible vertically
  near: -100,            // Near clip plane
  far: 100,              // Far clip plane
)
```

The viewport width is calculated automatically from the aspect ratio.

### Scaling Modes

Control how the projection adapts to different screen sizes:

```dart
OrthographicProjection(
  scalingMode: ScalingMode.fixedHeight,  // Default
  viewportHeight: 20,
)
```

| Mode | Description |
|------|-------------|
| `fixedHeight` | Fixed viewport height, width adjusts to aspect ratio (default) |
| `fixedWidth` | Fixed viewport width, height adjusts to aspect ratio |
| `fixedVertical` | Same as `fixedHeight` |
| `none` | No automatic scaling |

### Pixel-Perfect Rendering

For pixel art games where one world unit should equal one screen pixel:

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D())
  ..insert(Camera2D(
    projection: OrthographicProjection.pixelPerfect(),
    pixelPerfect: true,
  ));
```

Use the snap utilities to prevent sub-pixel rendering artifacts:

```dart
// Snap a position to the nearest pixel
final snapped = snapVector2ToPixel(position);

// Or use the extension method
final snapped = position.snappedToPixel;

// Snap in place
position.snapToPixel();
```

### Following a Target

Move the camera to follow a player:

```dart
class CameraFollowSystem implements System {
  @override
  Future<void> run(World world) async {
    // Get player position
    final (_, playerTransform) = world
      .query1<Transform2D>(filter: const With<Player>())
      .iter()
      .first;

    // Update camera position
    for (final (_, cameraTransform, _) in
        world.query2<Transform2D, Camera2D>().iter()) {
      cameraTransform.translation
        ..x = playerTransform.translation.x
        ..y = playerTransform.translation.y;
    }
  }
}
```

### Screen to World Conversion

Convert mouse clicks to world coordinates:

```dart
// Get camera entity and its GlobalTransform2D (world-space position)
final (cameraEntity, camera) = world.query1<Camera2D>().iter().first;
final cameraTransform = world.get<GlobalTransform2D>(cameraEntity)!;

final worldPos = camera.screenToWorld(
  Vector2(mouseX, mouseY),
  cameraTransform,
  RenderSize(screenWidth, screenHeight),
);
```

> **Note**: Use `GlobalTransform2D` (not `Transform2D`) for screen/world conversions. `GlobalTransform2D` contains the computed world-space position after parent transforms are applied.

### Split-Screen

Multiple cameras with viewports:

```dart
// Player 1 - left half
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D())
  ..insert(Camera2D(
    viewport: Viewport(x: 0, y: 0, width: 0.5, height: 1),
    order: 0,
  ));

// Player 2 - right half
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D())
  ..insert(Camera2D(
    viewport: Viewport(x: 0.5, y: 0, width: 0.5, height: 1),
    order: 1,
  ));
```

### Using Camera with CustomPainter

To render only what's visible to the camera, you need to:
1. Calculate the camera's visible world bounds
2. Apply the camera transform to the canvas
3. Cull entities outside the visible area

**Step 1: Get visible world bounds**

```dart
Rect getVisibleBounds(
  Camera2D camera,
  GlobalTransform2D cameraTransform,
  Size screenSize,
) {
  final renderSize = RenderSize(screenSize.width, screenSize.height);

  // Get visible dimensions in world units
  final visibleWidth = camera.projection.visibleWidth(renderSize);
  final visibleHeight = camera.projection.visibleHeight(renderSize);

  // Camera position is the center of the view
  final left = cameraTransform.x - visibleWidth / 2;
  final top = cameraTransform.y - visibleHeight / 2;

  return Rect.fromLTWH(left, top, visibleWidth, visibleHeight);
}
```

**Step 2: Apply camera transform to canvas**

```dart
void applyCameraTransform(
  Canvas canvas,
  Size size,
  Camera2D camera,
  GlobalTransform2D cameraTransform,
) {
  final renderSize = RenderSize(size.width, size.height);

  // Get visible dimensions
  final visibleWidth = camera.projection.visibleWidth(renderSize);
  final visibleHeight = camera.projection.visibleHeight(renderSize);

  // Calculate scale from world units to screen pixels
  final scaleX = size.width / visibleWidth;
  final scaleY = size.height / visibleHeight;

  // Transform: translate to center, then scale, then offset by camera position
  canvas.translate(size.width / 2, size.height / 2);
  canvas.scale(scaleX, -scaleY);  // Flip Y for screen coordinates
  canvas.translate(-cameraTransform.x, -cameraTransform.y);
}
```

**Step 3: Complete CustomPainter example**

```dart
class GamePainter extends CustomPainter {
  final World world;

  GamePainter(this.world);

  @override
  void paint(Canvas canvas, Size size) {
    // Get the active camera
    final cameraQuery = world.query2<Camera2D, GlobalTransform2D>().iter();
    if (cameraQuery.isEmpty) return;

    final (cameraEntity, camera, cameraTransform) = cameraQuery.first;

    // Calculate visible bounds for culling
    final visibleBounds = getVisibleBounds(camera, cameraTransform, size);

    // Add margin to avoid popping at edges
    final cullBounds = visibleBounds.inflate(64);

    // Save canvas state before transforming
    canvas.save();

    // Apply camera transform
    applyCameraTransform(canvas, size, camera, cameraTransform);

    // Draw only visible sprites
    for (final (_, sprite, transform) in
        world.query2<Sprite, GlobalTransform2D>().iter()) {

      // Simple point-in-rect culling
      if (!cullBounds.contains(Offset(transform.x, transform.y))) {
        continue;  // Skip - not visible
      }

      // Draw the sprite at its world position
      drawSprite(canvas, sprite, transform);
    }

    // Restore canvas state
    canvas.restore();
  }

  void drawSprite(Canvas canvas, Sprite sprite, GlobalTransform2D transform) {
    final srcRect = sprite.effectiveSourceRect;
    final spriteSize = sprite.size;

    // Calculate destination rect centered on anchor
    final dstRect = Rect.fromCenter(
      center: Offset(transform.x, transform.y),
      width: spriteSize.x,
      height: spriteSize.y,
    );

    // Draw (assuming you have the image from TextureHandle)
    // canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
```

**Efficient AABB culling for sprites**

For better culling accuracy, use the sprite's actual bounding box:

```dart
bool isVisible(Sprite sprite, GlobalTransform2D transform, Rect cullBounds) {
  final size = sprite.size;
  final anchor = sprite.anchor;

  // Calculate world-space bounding box
  final left = transform.x - size.x * anchor.x;
  final top = transform.y - size.y * anchor.y;
  final spriteBounds = Rect.fromLTWH(left, top, size.x, size.y);

  // Check overlap with visible area
  return cullBounds.overlaps(spriteBounds);
}
```

**Using the view-projection matrix directly**

For more complex rendering or when using raw transforms:

```dart
void paintWithMatrix(Canvas canvas, Size size, World world) {
  // Get camera with GlobalTransform2D (world-space position)
  final cameraQuery = world.query2<Camera2D, GlobalTransform2D>().iter();
  if (cameraQuery.isEmpty) return;
  final (_, camera, cameraTransform) = cameraQuery.first;

  final renderSize = RenderSize(size.width, size.height);

  // Get view-projection matrix (requires GlobalTransform2D, not Transform2D)
  final vpMatrix = camera.viewProjectionMatrix(cameraTransform, renderSize);

  // Convert to Flutter Matrix4 for canvas
  final matrix = Matrix4.identity()
    ..setEntry(0, 0, vpMatrix.entry(0, 0))
    ..setEntry(1, 1, vpMatrix.entry(1, 1))
    ..setEntry(0, 3, vpMatrix.entry(0, 3))
    ..setEntry(1, 3, vpMatrix.entry(1, 3));

  // Apply to canvas (note: requires additional screen-space conversion)
  canvas.transform(matrix.storage);
}
```

## Texture Atlas

Load sprite sheets and texture atlases for efficient batching.

### Grid Layout (Most Common)

For regular sprite sheets with uniform tiles:

```dart
final atlas = TextureAtlas.grid(
  texture: sheetTexture,
  columns: 8,
  rows: 4,
  tileWidth: 32,   // Optional: auto-calculated if omitted
  tileHeight: 32,  // Optional: auto-calculated if omitted
);
```

### Custom Layout

For non-uniform atlases, use `TextureAtlasLayout`:

```dart
final atlas = TextureAtlas(
  texture: sheetTexture,
  layout: TextureAtlasLayout.fromRects([
    Rect.fromLTWH(0, 0, 32, 32),    // Index 0
    Rect.fromLTWH(32, 0, 32, 32),   // Index 1
    Rect.fromLTWH(0, 32, 48, 48),   // Index 2 (different size)
    Rect.fromLTWH(48, 32, 32, 64),  // Index 3 (different size)
  ]),
  names: {  // Optional: named lookup
    'idle': 0,
    'walk': 1,
    'jump': 2,
    'attack': 3,
  },
);
```

### Using Atlas Sprites

```dart
// Get sprite rect by index
final region = atlas.getSpriteRect(0);

// Get sprite rect by name (if names were provided)
final jumpRect = atlas.getSpriteRectByName('jump');

// Use createSprite for convenience
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(atlas.createSprite(0));

// Or create sprite manually with region
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(Sprite.region(
    texture: atlas.texture,
    region: region,
  ));
```

### AtlasSprite Component

For entities using atlas-based sprites, use `AtlasSprite` instead of `Sprite`:

```dart
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(AtlasSprite(
    atlas: atlas,
    index: 0,
    color: Color(0xFFFFFFFF),
    flipX: false,
    flipY: false,
  ));

// Change sprite by name
entity.get<AtlasSprite>()!.setByName('jump');
```

`AtlasSprite` is the component used by `AnimationPlayer` — animation updates change the `index` to show different frames. Register `AtlasSpriteExtractor` to extract these to the render world.

## Animation

Animate sprites with frame-based animation clips. Animation frames reference sprite indices in a texture atlas.

### Creating Animation Clips

```dart
// From a range of indices (most common)
final walkClip = AnimationClip.fromIndices(
  name: 'walk',
  startIndex: 0,
  endIndex: 3,
  frameDuration: 0.1,
  looping: true,
);

// From a list of specific indices
final jumpClip = AnimationClip.fromIndexList(
  name: 'jump',
  indices: [4, 5, 6, 5, 4],  // Can repeat frames
  frameDuration: 0.15,
  looping: false,
);

// With variable durations per frame
final idleClip = AnimationClip.withDurations(
  name: 'idle',
  indices: [0, 1, 2, 1],
  durations: [0.5, 0.1, 0.5, 0.1],  // Different timing per frame
  looping: true,
);

// Manual frame construction
final customClip = AnimationClip(
  name: 'custom',
  frames: [
    AnimationFrame(index: 0, duration: 0.2),
    AnimationFrame(index: 1, duration: 0.1),
    AnimationFrame(index: 2, duration: 0.3),
  ],
  looping: true,
);
```

### Animation Player

```dart
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(Sprite(texture: spriteSheet))
  ..insert(AnimationPlayer(
    animations: {
      'walk': walkClip,
      'idle': idleClip,
      'jump': jumpClip,
    },
    initialAnimation: 'idle',  // Optional: start playing immediately
  ));

// Control playback
final player = entity.get<AnimationPlayer>()!;
player.play('walk');           // Switch animation
player.play('walk', restart: true);  // Restart even if already playing
player.pause();
player.resume();
player.stop();                 // Stop and reset to beginning
player.toggle();               // Toggle play/pause

// Query state
print(player.currentAnimation);  // 'walk'
print(player.currentIndex);      // Current sprite index
print(player.isPlaying);         // true/false
print(player.progress);          // 0.0 to 1.0
```

Add `AnimateSystemWithResource` to your app to update sprite source rects each frame (uses `Time` resource for delta time).

## Character Orientation

The `Orientation` component tracks which direction a character is facing, useful for selecting directional animation clips.

### Direction Enum

| Value | Description |
|-------|-------------|
| `right` | Facing right (+X) |
| `up` | Facing up (-Y) |
| `left` | Facing left (-X) |
| `down` | Facing down (+Y) |

### Usage

```dart
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(Orientation(Direction.down));

// Update from velocity (returns true if direction changed)
final orientation = entity.get<Orientation>()!;
if (orientation.updateFromVelocity(velocity.x, velocity.y)) {
  // Direction changed — switch animation clip
  final dir = orientation.direction;
  player.play('walk${dir.suffix}');  // e.g., 'walk_right'
}

// Static helpers
final dir = Direction.fromVelocity(vx, vy);  // returns null if stationary
final opposite = Direction.right.opposite;     // Direction.left
```

## Materials

Materials control how sprites are rendered — blend modes, tinting, and shader effects.

### Blend Modes

| Mode | Description |
|------|-------------|
| `normal` | Standard alpha blending (default) |
| `additive` | Additive blending (glow effects) |
| `multiply` | Multiply blending (shadows) |
| `screen` | Screen blending (lightening) |
| `none` | No blending (opaque) |

### SpriteMaterial

```dart
SpriteMaterial(
  texture: myTexture,
  tint: Color(0xFFFF0000),        // Red tint
  blendMode: BlendMode.additive,  // Glow effect
  alphaThreshold: 0.1,            // Discard nearly-transparent pixels
)
```

### ColorMaterial

For solid-color shapes without a texture:

```dart
ColorMaterial(
  color: Color(0xFF00FF00),
  blendMode: BlendMode.normal,
)
```

### ShaderMaterial

Apply custom shader programs with uniforms:

```dart
final material = ShaderMaterial(
  shader: myShader,
  texture: myTexture,
  blendMode: BlendMode.normal,
);

// Set uniforms
material.setFloat('time', elapsedTime);
material.setVec2('resolution', screenWidth, screenHeight);
material.setVec4('tintColor', 1.0, 0.5, 0.0, 1.0);
```

### ShaderEffects

Pre-built shader material factories for common effects:

```dart
// Grayscale
ShaderEffects.grayscale(shader: shader, texture: texture, intensity: 0.8)

// Outline
ShaderEffects.outline(shader: shader, texture: texture, thickness: 2.0, r: 1, g: 0, b: 0)

// Glow
ShaderEffects.glow(shader: shader, texture: texture, intensity: 1.5, radius: 3.0)

// Pixelation
ShaderEffects.pixelate(shader: shader, texture: texture, pixelSize: 4)

// Dissolve
ShaderEffects.dissolve(shader: shader, texture: texture, threshold: 0.5, edgeWidth: 0.1)

// Wave distortion
ShaderEffects.waveDistortion(shader: shader, texture: texture, time: t, amplitude: 0.1)

// Color tint
ShaderEffects.colorTint(shader: shader, texture: texture, r: 1, g: 0.5, b: 0)
```

## Scene Transitions

`fledge_render_2d` provides a phase-based transition system for smooth scene changes with fade effects.

### TransitionState

The `TransitionState` resource manages fade animations between scenes:

```dart
// Insert the resource
app.insertResource(TransitionState(fadeDuration: 0.3));

// Request a transition
final transition = world.getResource<TransitionState>()!;
transition.requestTransition(
  'level2',  // Target scene (any Object type)
  metadata: {'spawnX': 100, 'spawnY': 200},  // Optional data
);
```

### Transition Phases

Transitions progress through four phases:

```
idle → fadeOut → loading → fadeIn → idle
```

| Phase | Description |
|-------|-------------|
| `idle` | No transition in progress |
| `fadeOut` | Screen fading to black |
| `loading` | Screen is black, load new scene |
| `fadeIn` | Screen fading back in |

### Using Transitions

```dart
@system
void sceneTransitionSystem(World world) {
  final transition = world.getResource<TransitionState>();
  if (transition == null || !transition.isTransitioning) return;

  // Handle loading phase
  if (transition.phase == TransitionPhase.loading && !transition.isLoadingAsync) {
    transition.isLoadingAsync = true;

    // Load new scene
    final targetScene = transition.targetScene as String;
    final spawnX = transition.metadata?['spawnX'] as int?;

    loadScene(targetScene).then((_) {
      transition.beginFadeIn();
      transition.isLoadingAsync = false;
    });
  }
}
```

### TransitionFadeSystem

The built-in `TransitionFadeSystem` handles fade animations automatically:

```dart
app.addSystem(TransitionFadeSystem());
```

This system:
- Advances `fadeProgress` during `fadeOut` (0.0 → 1.0)
- Calls `beginLoading()` when fade out completes
- Advances `fadeProgress` during `fadeIn` (1.0 → 0.0)
- Calls `complete()` when fade in completes

### Rendering the Fade Overlay

In your Flutter widget:

```dart
Widget build(BuildContext context) {
  final transition = world.getResource<TransitionState>();

  return Stack(
    children: [
      // Game content
      GameWidget(),

      // Fade overlay
      if (transition != null && transition.isTransitioning)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(
                transition.fadeProgress.clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
    ],
  );
}
```

### Custom Fade Duration

```dart
// Per-transition duration
TransitionState(fadeDuration: 0.5)  // 500ms fades

// Or modify at runtime
transition.fadeDuration = 1.0;  // Slow dramatic fade
```

### Canceling Transitions

Transitions can be canceled during the fade out phase:

```dart
if (transition.phase == TransitionPhase.fadeOut) {
  transition.cancel();  // Returns to idle
}
```

## Components Reference

| Component | Description |
|-----------|-------------|
| `Transform2D` | Local position, rotation, scale |
| `GlobalTransform2D` | Computed world-space transform |
| `Sprite` | Textured quad rendering |
| `Camera2D` | 2D orthographic camera |
| `AnimationPlayer` | Frame-based animation |
| `AtlasSprite` | Atlas-based sprite with index/name lookup |
| `Orientation` | Character facing direction |
| `Visibility` | Show/hide entities |
| `TransitionState` | Scene transition phase and fade progress |

## Resources Reference

| Resource | Description |
|----------|-------------|
| `ViewportSize` | Tracks viewport dimensions |
| `AnimationTime` | Delta time for animation updates |

## Systems Reference

| System | Description |
|--------|-------------|
| `TransformPropagateSystem` | Computes `GlobalTransform2D` from parent-child hierarchy |
| `AnimateSystem` | Updates animations (requires manual delta time) |
| `AnimateSystemWithResource` | Updates animations (uses `AnimationTime` resource) |
| `TransitionFadeSystem` | Advances fade progress during scene transitions |

## See Also

- [Render Infrastructure](/docs/plugins/render_plugin) - RenderPlugin, Extractors, RenderWorld, RenderLayer
- [Two-World Architecture](/docs/guides/two-world-architecture) - Extraction system details
- [Tiled Tilemaps](/docs/plugins/tiled) - Tilemap rendering integration
- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
