import 'package:fledge_ecs/fledge_ecs.dart';

import '../../sprite/extracted_sprite.dart';
import '../world/render_world.dart';

/// Base class for component extractors.
///
/// Extractors copy data from the main world to the render world each frame.
/// This enables the two-world architecture where game logic and rendering
/// are decoupled. Register them on the [Extractors] resource that
/// `RenderPlugin` inserts; `RenderExtractionSystem` clears the
/// [RenderWorld] and runs every registered extractor in `Schedules.extract`.
///
/// Sprites go into the render world with [RenderWorld.addSprite]; any
/// other render data is added as its own entity with [RenderWorld.add] and
/// read back with [RenderWorld.query1]:
///
/// ```dart
/// class Health {
///   double current = 10, max = 10;
/// }
///
/// class ExtractedHealthBar {
///   final double x, y, fraction;
///   const ExtractedHealthBar(this.x, this.y, this.fraction);
/// }
///
/// class HealthBarExtractor extends Extractor {
///   @override
///   void extract(World mainWorld, RenderWorld renderWorld) {
///     for (final (_, health, transform)
///         in mainWorld.query2<Health, GlobalTransform2D>().iter()) {
///       renderWorld.add(
///         ExtractedHealthBar(
///           transform.x,
///           transform.y,
///           health.current / health.max,
///         ),
///       );
///     }
///   }
/// }
///
/// // Once, after adding RenderPlugin:
/// app.world.getResource<Extractors>()!.register(HealthBarExtractor());
///
/// // In a render system or widget painter:
/// final renderWorld = app.world.getResource<RenderWorld>()!;
/// for (final (_, bar) in renderWorld.query1<ExtractedHealthBar>().iter()) {
///   // draw bar
/// }
/// ```
abstract class Extractor {
  /// Extract data from the main world to the render world.
  ///
  /// Called once per frame during the extract stage.
  void extract(World mainWorld, RenderWorld renderWorld);
}

/// Type-safe extractor for a specific component type.
///
/// Calls the function for every main-world entity with a [TSource]
/// component and adds what it returns to the render world: an
/// [ExtractedSprite] with [RenderWorld.addSprite], anything else as its own
/// entity, stored as [TExtracted].
///
/// Example (with the `Health` / `ExtractedHealthBar` types from
/// [Extractor]'s example):
/// ```dart
/// final extractor = ComponentExtractor<Health, ExtractedHealthBar>(
///   (world, entity, health) {
///     final transform = world.get<GlobalTransform2D>(entity);
///     return ExtractedHealthBar(
///       transform?.x ?? 0,
///       transform?.y ?? 0,
///       health.current / health.max,
///     );
///   },
/// );
/// app.world.getResource<Extractors>()!.register(extractor);
/// ```
class ComponentExtractor<TSource, TExtracted> extends Extractor {
  final TExtracted Function(World world, Entity entity, TSource component)
  _extractFn;
  final QueryFilter? _filter;

  /// Creates a component extractor.
  ///
  /// The [extract] function is called for each entity with the source component.
  /// An optional [filter] can be provided to narrow the query.
  ComponentExtractor(
    TExtracted Function(World world, Entity entity, TSource component)
    extract, {
    this._filter,
  }) : _extractFn = extract;

  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (entity, component)
        in mainWorld.query1<TSource>(filter: _filter).iter()) {
      final extracted = _extractFn(mainWorld, entity, component);
      // Sprites go in the render world's sprite list; anything else is an
      // entity.
      if (extracted is ExtractedSprite) {
        renderWorld.addSprite(extracted);
      } else {
        renderWorld.world.spawnOne<TExtracted>(extracted);
      }
    }
  }
}

/// Registry of extractors.
///
/// Manages the collection of extractors that run during the extract phase.
class Extractors {
  final List<Extractor> _extractors = [];

  /// All registered extractors.
  List<Extractor> get all => List.unmodifiable(_extractors);

  /// Register an extractor.
  void register(Extractor extractor) {
    _extractors.add(extractor);
  }

  /// Remove an extractor.
  bool remove(Extractor extractor) {
    return _extractors.remove(extractor);
  }

  /// Remove all extractors of a specific type.
  void removeWhere(bool Function(Extractor) test) {
    _extractors.removeWhere(test);
  }

  /// Clear all extractors.
  void clear() {
    _extractors.clear();
  }

  /// The number of registered extractors.
  int get length => _extractors.length;

  /// Whether there are no registered extractors.
  bool get isEmpty => _extractors.isEmpty;

  /// Whether there are registered extractors.
  bool get isNotEmpty => _extractors.isNotEmpty;
}

/// System that syncs entities from main world to render world.
///
/// This system runs during the extract stage and:
/// 1. Clears the render world of previous frame's data
/// 2. Runs all registered extractors
///
/// Example:
/// ```dart
/// final extractSystem = ExtractSystem();
/// extractSystem.run(mainWorld, renderWorld);
/// ```
class ExtractSystem {
  /// Run extraction from main world to render world.
  ///
  /// Clears the render world and runs all registered extractors.
  void run(World mainWorld, RenderWorld renderWorld) {
    // Clear render world for fresh extraction
    renderWorld.clear();

    // Get extractors from main world resources
    final extractors = mainWorld.getResource<Extractors>();
    if (extractors == null) return;

    // Run all extractors
    for (final extractor in extractors.all) {
      extractor.extract(mainWorld, renderWorld);
    }
  }
}

/// Interface for components that know how to build their own render
/// data.
///
/// Nothing discovers these automatically: extract them like any other
/// component, e.g. with a [ComponentExtractor].
///
/// Example:
/// ```dart
/// class Marker implements ExtractComponent<ExtractedMarker> {
///   final Color color;
///   const Marker(this.color);
///
///   @override
///   ExtractedMarker extract() => ExtractedMarker(color);
/// }
///
/// app.world.getResource<Extractors>()!.register(
///   ComponentExtractor<Marker, ExtractedMarker>((_, _, m) => m.extract()),
/// );
/// ```
abstract class ExtractComponent<TExtracted> {
  /// Extract render data from this component.
  TExtracted extract();
}
