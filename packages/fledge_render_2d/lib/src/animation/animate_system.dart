import 'package:fledge_ecs/fledge_ecs.dart';

import '../atlas/texture_atlas.dart';
import '../sprite/sprite.dart';
import 'animation_player.dart';

/// System that updates animation players and applies sprite changes.
///
/// This system:
/// 1. Updates all [AnimationPlayer] components with delta time
/// 2. Updates [AtlasSprite] components to reflect current frame
/// 3. Updates [Sprite] components' source rects from atlases
///
/// Add this system to your app to enable sprite animations:
/// ```dart
/// app.addSystem(AnimateSystem());
/// ```
class AnimateSystem implements System {
  /// Delta time in seconds since last frame.
  ///
  /// This should be set each frame before running the system.
  double deltaTime = 0;

  @override
  SystemMeta get meta => SystemMeta(
        name: 'animate',
        writes: {ComponentId.of<AtlasSprite>(), ComponentId.of<Sprite>()},
        reads: {ComponentId.of<AnimationPlayer>()},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    // Update all animation players
    for (final (entity, player) in world.query1<AnimationPlayer>().iter()) {
      player.update(deltaTime);

      // If entity also has an AtlasSprite, update its index
      final atlasSprite = world.get<AtlasSprite>(entity);
      if (atlasSprite != null) {
        atlasSprite.index = player.currentIndex;
      }

      // If entity has a Sprite, update its source rect from AtlasSprite
      final sprite = world.get<Sprite>(entity);
      if (sprite != null && atlasSprite != null) {
        sprite.sourceRect = atlasSprite.sourceRect;
        sprite.flipX = atlasSprite.flipX;
        sprite.flipY = atlasSprite.flipY;
      }
    }
  }
}

/// Resource to track animation delta time.
///
/// Insert this resource and update it each frame:
/// ```dart
/// app.insertResource(AnimationTime());
///
/// // In your game loop:
/// world.getResource<AnimationTime>()!.deltaTime = dt;
/// ```
class AnimationTime {
  /// Delta time in seconds.
  double deltaTime = 0;
}

/// System that uses AnimationTime resource for delta time.
class AnimateSystemWithResource implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'animate_with_resource',
        writes: {ComponentId.of<AtlasSprite>(), ComponentId.of<Sprite>()},
        reads: {ComponentId.of<AnimationPlayer>()},
        resourceReads: {AnimationTime},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final time = world.getResource<AnimationTime>();
    if (time == null) return;

    final dt = time.deltaTime;

    // Update all animation players
    for (final (entity, player) in world.query1<AnimationPlayer>().iter()) {
      player.update(dt);

      // If entity also has an AtlasSprite, update its index
      final atlasSprite = world.get<AtlasSprite>(entity);
      if (atlasSprite != null) {
        atlasSprite.index = player.currentIndex;
      }

      // If entity has a Sprite, update its source rect from AtlasSprite
      final sprite = world.get<Sprite>(entity);
      if (sprite != null && atlasSprite != null) {
        sprite.sourceRect = atlasSprite.sourceRect;
        sprite.flipX = atlasSprite.flipX;
        sprite.flipY = atlasSprite.flipY;
      }
    }
  }
}
