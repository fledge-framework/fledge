import 'package:fledge_assets/fledge_assets.dart' show Assets;
import 'package:fledge_ecs/fledge_ecs.dart';

import '../../backend/canvas_render_context.dart' show CanvasSpriteDrawer;
import '../../backend/gpu_render_context.dart' show GpuSpriteDrawer;
import '../../sprite/sprite_render_node.dart' show SpriteDrawer;
import '../../sprite/texture.dart' show Texture;
import '../../transitions/transition_state.dart' show TransitionCompleted;
import '../context/render_context.dart';
import '../extract/extract.dart';
import '../world/render_world.dart';

/// System that extracts render data from the main world to the render world.
///
/// Runs in [Schedules.extract], immediately after the per-frame
/// `first → preUpdate → update → postUpdate → last` chain and before
/// any [Schedules.render] systems. Clears the render world and runs
/// all registered extractors.
///
/// Phase 3 will introduce dedicated render systems inside
/// [Schedules.render]; this extract step is now driven separately
/// from `last`.
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

/// Plugin that sets up render extraction and backend drawer wiring
/// for ECS-based games.
///
/// Registers:
/// - [Extractors] resource for registering component extractors
/// - [RenderWorld] resource for storing extracted render data
/// - [RenderBackendResource] with the selected [backend]
/// - [SpriteDrawer] resource matched to [backend]
///   ([CanvasSpriteDrawer] or [GpuSpriteDrawer])
/// - [RenderExtractionSystem] in [Schedules.extract]
///
/// ## Usage
///
/// ```dart
/// app.addPlugin(RenderPlugin(backend: RenderBackend.canvas));
///
/// // Register extractors in your game plugin
/// final extractors = app.world.getResource<Extractors>()!;
/// extractors.register(SpriteExtractor());
/// extractors.register(ParticleExtractor());
/// ```
///
/// The extraction system runs automatically each frame in
/// [Schedules.extract] — after all game logic (`update`/`postUpdate`/
/// `last`) has completed and before any [Schedules.render] systems —
/// populating the [RenderWorld] with data for rendering.
class RenderPlugin implements Plugin {
  App? _app;

  /// Which rendering backend to install.
  ///
  /// Defaults to [RenderBackend.canvas]. This selection determines
  /// both the [RenderBackendResource] value and which concrete
  /// [SpriteDrawer] is inserted — [CanvasSpriteDrawer] for
  /// [RenderBackend.canvas] and [GpuSpriteDrawer] for
  /// [RenderBackend.gpu].
  final RenderBackend backend;

  /// Creates a render plugin.
  RenderPlugin({this.backend = RenderBackend.canvas});

  @override
  void build(App app) {
    _app = app;

    // Insert core render resources
    app.insertResource(Extractors());
    app.insertResource(RenderWorld());
    app.insertResource(RenderBackendResource(backend));

    // Assets store for textures — the Canvas backend resolves each
    // `TextureHandle` (and, going forward, `Handle<Texture>`) against
    // this store to fetch the underlying `dart:ui.Image`.
    final textures = Assets<Texture>();
    app.insertResource<Assets<Texture>>(textures);

    // Install the matching sprite drawer for the selected backend.
    // Previously lived in a separate `SpriteBackendPlugin` to avoid a
    // package cycle; now that render infra and 2D live in the same
    // package, this can happen inline.
    switch (backend) {
      case RenderBackend.canvas:
        final drawer = CanvasSpriteDrawer()..attachAssets(textures);
        app.insertResource<SpriteDrawer>(drawer);
      case RenderBackend.gpu:
        app.insertResource<SpriteDrawer>(GpuSpriteDrawer());
    }

    // Transition-completion signal, emitted by TransitionFadeSystem
    // when a fade transition finishes. Register it here so apps that
    // use transitions don't have to remember to addEvent themselves.
    app.addEvent<TransitionCompleted>();

    // Extraction runs in its own schedule so render logic isn't
    // interleaved with per-frame `last` cleanup systems.
    app.addSystem(RenderExtractionSystem(), schedule: Schedules.extract);
  }

  @override
  void cleanup() {
    _app?.world.removeResource<Extractors>();
    _app?.world.removeResource<RenderWorld>();
    _app?.world.removeResource<RenderBackendResource>();
    _app?.world.removeResource<SpriteDrawer>();
    _app?.world.removeResource<Assets<Texture>>();
    _app = null;
  }
}
