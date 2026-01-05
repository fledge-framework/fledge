import 'package:fledge_ecs/fledge_ecs.dart';

import '../extract/extract.dart';
import '../world/render_world.dart';

/// System that extracts render data from the main world to the render world.
///
/// Runs at [CoreStage.last] after all game logic has completed.
/// Clears the render world and runs all registered extractors.
class RenderExtractionSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'renderExtraction',
        resourceReads: {Extractors},
        resourceWrites: {RenderWorld},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final extractors = world.getResource<Extractors>();
    final renderWorld = world.getResource<RenderWorld>();

    if (extractors == null || renderWorld == null) return Future.value();

    // Clear previous frame's render data
    renderWorld.clear();

    // Run all extractors to populate render world
    for (final extractor in extractors.all) {
      extractor.extract(world, renderWorld);
    }

    return Future.value();
  }
}

/// Plugin that sets up render extraction for ECS-based games.
///
/// Registers:
/// - [Extractors] resource for registering component extractors
/// - [RenderWorld] resource for storing extracted render data
/// - [RenderExtractionSystem] at [CoreStage.last]
///
/// ## Usage
///
/// ```dart
/// app.addPlugin(RenderPlugin());
///
/// // Register extractors in your game plugin
/// final extractors = app.world.getResource<Extractors>()!;
/// extractors.register(SpriteExtractor());
/// extractors.register(ParticleExtractor());
/// ```
///
/// The extraction system runs automatically at the end of each frame,
/// populating the [RenderWorld] with data for rendering.
class RenderPlugin implements Plugin {
  App? _app;

  @override
  void build(App app) {
    _app = app;

    // Insert core render resources
    app.insertResource(Extractors());
    app.insertResource(RenderWorld());

    // Add extraction system at end of frame
    app.addSystem(RenderExtractionSystem(), stage: CoreStage.last);
  }

  @override
  void cleanup() {
    _app?.world.removeResource<Extractors>();
    _app?.world.removeResource<RenderWorld>();
    _app = null;
  }
}
