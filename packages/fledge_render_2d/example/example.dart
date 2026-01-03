import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:vector_math/vector_math.dart';

void main() async {
  final world = World();

  // Spawn a camera
  world.spawn()
    ..insert(Transform2D.from(0, 0))
    ..insert(GlobalTransform2D())
    ..insert(Camera2D(
      projection: OrthographicProjection(viewportHeight: 600),
      pixelPerfect: true,
    ));

  // Spawn a sprite with transform
  world.spawn()
    ..insert(Transform2D(
      translation: Vector2(100, 200),
      rotation: 0.0,
      scale: Vector2.all(1.0),
    ))
    ..insert(GlobalTransform2D())
    ..insert(Sprite(
      texture: _placeholderTexture(),
      color: const Color(0xFFFFFFFF),
    ));

  // Spawn an animated sprite
  final walkClip = AnimationClip.fromIndices(
    name: 'walk',
    startIndex: 0,
    endIndex: 3,
    frameDuration: 0.1,
  );

  world.spawn()
    ..insert(Transform2D.from(200, 200))
    ..insert(GlobalTransform2D())
    ..insert(Sprite(texture: _placeholderTexture()))
    ..insert(AnimationPlayer(
      animations: {'walk': walkClip},
      initialAnimation: 'walk',
    ));

  // Add transform propagation system
  final schedule = Schedule()..addSystem(TransformPropagateSystem());

  await schedule.run(world);

  // ignore: avoid_print
  print('Spawned camera, sprite, and animated sprite');
}

// Placeholder for texture - in real code, load from assets
TextureHandle _placeholderTexture() =>
    TextureHandle(id: 0, width: 32, height: 32);
