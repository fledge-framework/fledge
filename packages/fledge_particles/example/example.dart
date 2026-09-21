import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_particles/fledge_particles.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

/// Minimal fledge_particles example.
///
/// [ParticlePlugin] installs the emit / update / reap systems and
/// registers the [ParticleExtractor] on top of [RenderPlugin]'s
/// pipeline (particles are drawn through the standard sprite path
/// via `ExtractedSprite`, in the reserved `DrawLayer.particles`
/// range).
///
/// Attach a [ParticleEmitter] alongside `Transform2D` +
/// `GlobalTransform2D`; here we use the [ParticleEmitterPresets.fire]
/// preset for a steady flame.
void main() async {
  final app = App()
    ..addPlugin(const WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const ParticlePlugin());

  // Placeholder texture — in a real game this is a ready
  // `Handle<Texture>` lifted through `TextureHandle.fromAsset`.
  const spark = TextureHandle(id: 0, width: 8, height: 8);

  app.world.spawn()
    ..insert(Transform2D.from(0, 0))
    ..insert(GlobalTransform2D.identity())
    ..insert(ParticleEmitterPresets.fire(texture: spark, emitRate: 60));

  await app.tick();
}
