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
/// `RenderPlugin` (from `fledge_render_2d`) owns the [Extractors]
/// resource. The plugins can be added in either order: if `RenderPlugin`
/// isn't there yet, the extractor is registered on the first tick (in
/// `Schedules.startup`). Without `RenderPlugin` at all (a headless
/// simulation or test) the particle systems still run; nothing is drawn.
///
/// ```dart
/// final app = App()
///   ..addPlugin(RenderPlugin())
///   ..addPlugin(const ParticlePlugin());
/// ```
class ParticlePlugin implements Plugin {
  /// Creates a particle plugin.
  const ParticlePlugin();

  /// The `SystemMeta.name` of the one-shot startup system that registers
  /// [ParticleExtractor] when `RenderPlugin` was added after this plugin.
  static const String registerExtractorSystemName =
      'particle_register_extractor';

  @override
  void build(App app) {
    app
      ..addSystem(ParticleEmitSystem(), schedule: Schedules.update)
      ..addSystem(ParticleUpdateSystem(), schedule: Schedules.update)
      ..addSystem(ParticleReapSystem(), schedule: Schedules.postUpdate);

    // Register now if RenderPlugin is already in. Otherwise wait for the
    // first tick, so the plugins can be added in either order; with no
    // RenderPlugin even then (headless), the particles just aren't drawn.
    if (!_registerExtractor(app.world)) {
      app.addSystem(
        FunctionSystem(
          registerExtractorSystemName,
          resourceWrites: {Extractors},
          run: _registerExtractor,
        ),
        schedule: Schedules.startup,
      );
    }
  }

  /// Registers a [ParticleExtractor] unless one already is. Returns
  /// whether the [Extractors] registry exists.
  static bool _registerExtractor(World world) {
    final extractors = world.getResource<Extractors>();
    if (extractors == null) return false;
    if (!extractors.all.any((e) => e is ParticleExtractor)) {
      extractors.register(ParticleExtractor());
    }
    return true;
  }

  @override
  void cleanup() {}
}
