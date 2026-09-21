import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Extractors;

import 'particle_extractor.dart';
import 'systems.dart';

/// Plugin that wires the particle system into an [App].
///
/// Adds three systems with explicit `before:` / `after:` ordering:
///
/// 1. [ParticleEmitSystem] — `Schedules.update`. Spawns new particles.
/// 2. [ParticleUpdateSystem] — `Schedules.update`, after emit.
///    Advances live particles.
/// 3. [ParticleReapSystem] — `Schedules.postUpdate`. Reclaims dead
///    particles from every emitter's pool.
///
/// Registers [ParticleExtractor] on the [Extractors] resource so
/// particles are extracted as `ExtractedSprite` and drawn through the
/// existing sprite render path in the reserved `DrawLayer.particles`
/// sort range.
///
/// Requires `RenderPlugin` (from `fledge_render_2d`) to be added
/// first — that plugin owns the [Extractors] resource. Add the two
/// together:
///
/// ```dart
/// final app = App()
///   ..addPlugin(RenderPlugin())
///   ..addPlugin(const ParticlePlugin());
/// ```
class ParticlePlugin implements Plugin {
  /// Creates a particle plugin.
  const ParticlePlugin();

  @override
  void build(App app) {
    app
      ..addSystem(ParticleEmitSystem(), schedule: Schedules.update)
      ..addSystem(ParticleUpdateSystem(), schedule: Schedules.update)
      ..addSystem(ParticleReapSystem(), schedule: Schedules.postUpdate);

    // Registering the extractor is optional — if the app doesn't use
    // RenderPlugin (e.g. a headless test) the particle systems still
    // run, they just don't feed the render world.
    final extractors = app.world.getResource<Extractors>();
    extractors?.register(ParticleExtractor());
  }

  @override
  void cleanup() {}
}
