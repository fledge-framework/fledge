import 'package:fledge_ecs/fledge_ecs.dart';

import '../world/render_world.dart';

/// Base class for component extractors.
///
/// Extractors copy data from the main world to the render world each frame.
/// This enables the two-world architecture where game logic and rendering
/// are decoupled.
///
/// Example:
/// ```dart
/// class SpriteExtractor extends Extractor {
///   @override
///   void extract(World mainWorld, RenderWorld renderWorld) {
///     for (final (entity, sprite, transform) in
///         mainWorld.query2<Sprite, GlobalTransform2D>().iter()) {
///       renderWorld.spawn()
///         ..insert(ExtractedSprite(
///           entity: entity,
///           texture: sprite.texture,
///           transform: transform.matrix,
///         ));
///     }
///   }
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
/// Provides a simplified API for extracting single components.
///
/// Example:
/// ```dart
/// final extractor = ComponentExtractor<Sprite, ExtractedSprite>(
///   (world, entity, sprite) => ExtractedSprite(sprite),
/// );
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
    QueryFilter? filter,
  })  : _extractFn = extract,
        _filter = filter;

  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (entity, component)
        in mainWorld.query1<TSource>(filter: _filter).iter()) {
      final extracted = _extractFn(mainWorld, entity, component);
      renderWorld.spawn()..insert(extracted);
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

/// Marker trait for components that should be automatically extracted.
///
/// Components implementing this trait can be auto-discovered by the
/// extraction system.
///
/// Example:
/// ```dart
/// class Sprite implements ExtractComponent<ExtractedSprite> {
///   @override
///   ExtractedSprite extract() => ExtractedSprite(this);
/// }
/// ```
abstract class ExtractComponent<TExtracted> {
  /// Extract render data from this component.
  TExtracted extract();
}
