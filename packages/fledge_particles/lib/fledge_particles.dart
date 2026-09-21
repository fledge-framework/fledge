/// CPU-driven particle system for Fledge games.
///
/// Provides [ParticleEmitter] components, [ParticleTemplate] recipes,
/// pooled [Particle] instances, and a set of presets (fire, smoke,
/// spark, trail). Emitter output is extracted as
/// `ExtractedSprite` from `fledge_render_2d` and drawn through the
/// existing sprite render path in the reserved `DrawLayer.particles`
/// sort range.
///
/// ## Scheduler placement
///
/// The [ParticlePlugin] installs three systems, each with explicit
/// `before:` / `after:` ordering so
/// `App.checkScheduleOrdering()` returns an empty list for a
/// `ParticlePlugin`-only app:
///
/// - [ParticleEmitSystem] — `Schedules.update`
/// - [ParticleUpdateSystem] — `Schedules.update` (after emit)
/// - [ParticleReapSystem] — `Schedules.postUpdate`
///
/// ## Quick start
///
/// ```dart
/// import 'package:fledge_ecs/fledge_ecs.dart';
/// import 'package:fledge_particles/fledge_particles.dart';
/// import 'package:fledge_render_2d/fledge_render_2d.dart';
///
/// Future<void> main() async {
///   final app = App()
///     ..addPlugin(RenderPlugin())
///     ..addPlugin(const ParticlePlugin());
///
///   app.world.spawn()
///     ..insert(Transform2D.from(100, 100))
///     ..insert(GlobalTransform2D.identity())
///     ..insert(ParticleEmitter.fire(texture: myParticleTexture));
///
///   await app.run();
/// }
/// ```
library;

export 'src/emitter.dart';
export 'src/particle.dart';
export 'src/particle_extractor.dart';
export 'src/particle_plugin.dart';
export 'src/presets.dart';
export 'src/systems.dart';
