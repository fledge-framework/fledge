import 'dart:math' as math;
import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import '../render/camera_view.dart' show ActiveCameraView;
import '../render/extract/draw_layer.dart';
import '../render/extract/extract.dart';
import '../render/world/render_world.dart';
import '../transform/global_transform.dart';
import '../transform/static_transform.dart';
import 'extracted_sprite.dart';
import 'sprite.dart' show Visibility;

/// The extraction both sprite extractors share (`SpriteExtractor` for
/// `Sprite`, `AtlasSpriteExtractor` for `AtlasSprite`): camera culling,
/// the `StaticTransform` grid, visibility, `PreviousTransform2D`
/// interpolation and the layer / Y sort key. A subclass only says how to
/// read its component [C].
///
/// Internal to the package (not exported): the two extractors are the
/// public API.
abstract class CulledSpriteExtractor<C extends Object> extends Extractor {
  /// World units beyond the camera's last view that are still extracted.
  static const double cullMargin = 64;

  /// The quad size [component] draws at, before the transform's scale.
  Vector2 sizeOf(C component);

  /// The tint: a fully transparent one is skipped.
  Color colorOf(C component);

  /// The draw layer.
  DrawLayer layerOf(C component);

  /// The explicit sub-order, or 0 to sort by Y.
  int layerSubOrderOf(C component);

  /// The extracted sprite for [component], with everything the shared
  /// path has already worked out.
  ExtractedSprite build(
    C component, {
    required Entity entity,
    required Matrix3 transform,
    required Vector2 size,
    required int sortKey,
    required double? preciseSubOrder,
  });

  /// How far a sprite drawn with [m] at [size] can reach from its origin,
  /// whatever its anchor.
  static double _reach(Matrix3 m, Vector2 size) {
    final s = m.storage;
    return size.x * math.sqrt(s[0] * s[0] + s[1] * s[1]) +
        size.y * math.sqrt(s[3] * s[3] + s[4] * s[4]);
  }

  /// Whether a sprite drawn with [m] at [size] could reach into [visible]
  /// (allocation-free: it runs for every sprite in the world).
  static bool _onScreen(Rect visible, Matrix3 m, Vector2 size) {
    final reach = _reach(m, size);
    final s = m.storage;
    final x = s[6], y = s[7];
    return x >= visible.left - reach &&
        x < visible.right + reach &&
        y >= visible.top - reach &&
        y < visible.bottom + reach;
  }

  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final alpha = mainWorld.getResource<FixedTimestep>()?.alpha ?? 1.0;
    // Skip what's far off screen. The margin covers camera movement since
    // the last paint and sprites whose art reaches past their anchor.
    final visible = mainWorld
        .getResource<ActiveCameraView>()
        ?.visibleWorldRect
        ?.inflate(cullMargin);

    // What can move: every one, culled one by one.
    for (final (entity, component, globalTransform)
        in mainWorld
            .query2<C, GlobalTransform2D>(
              filter: const Without<TransformFrozen>(),
            )
            .iter()) {
      _extractOne(
        mainWorld,
        renderWorld,
        entity,
        component,
        globalTransform,
        alpha,
        visible,
      );
    }
    _extractFrozen(mainWorld, renderWorld, alpha, visible);
  }

  // Frozen sprites (`StaticTransform` scenery) by where they stand, so a
  // frame only looks at the ones near the view.
  static const double _cell = 256;

  /// Extra reach beyond what was measured at build: a frozen sprite's
  /// texture (or atlas frame) may change and grow.
  static const double _growMargin = 256;

  final Map<int, List<Entity>> _grid = {};
  StaticTransforms? _builtFor;
  int _builtGeneration = -1;
  double _maxReach = 0;

  static int _key(int x, int y) => (x + 0x8000) * 0x10000 + (y + 0x8000);

  void _rebuild(World world, StaticTransforms frozen) {
    _grid.clear();
    _maxReach = 0;
    for (final (entity, component, global)
        in world
            .query2<C, GlobalTransform2D>(filter: const With<TransformFrozen>())
            .iter()) {
      final m = global.matrix.storage;
      (_grid[_key((m[6] / _cell).floor(), (m[7] / _cell).floor())] ??= []).add(
        entity,
      );
      _maxReach = math.max(_maxReach, _reach(global.matrix, sizeOf(component)));
    }
    _builtFor = frozen;
    _builtGeneration = frozen.generation;
  }

  void _extractFrozen(
    World world,
    RenderWorld renderWorld,
    double alpha,
    Rect? visible,
  ) {
    final frozen = world.getResource<StaticTransforms>();
    if (frozen == null) return; // nothing frozen in this world
    if (!identical(frozen, _builtFor) ||
        frozen.generation != _builtGeneration) {
      _rebuild(world, frozen);
    }
    if (visible == null) {
      // No view yet (before the first paint): every frozen sprite.
      for (final (entity, component, global)
          in world
              .query2<C, GlobalTransform2D>(
                filter: const With<TransformFrozen>(),
              )
              .iter()) {
        _extractOne(world, renderWorld, entity, component, global, alpha, null);
      }
      return;
    }
    final area = visible.inflate(_maxReach + _growMargin);
    final x0 = (area.left / _cell).floor(), x1 = (area.right / _cell).floor();
    final y0 = (area.top / _cell).floor(), y1 = (area.bottom / _cell).floor();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final bucket = _grid[_key(x, y)];
        if (bucket == null) continue;
        for (final entity in bucket) {
          // Gone since the grid was built, or the id reused by something
          // that isn't frozen scenery.
          if (!world.isAlive(entity) || !world.has<TransformFrozen>(entity)) {
            continue;
          }
          final component = world.get<C>(entity);
          final global = world.get<GlobalTransform2D>(entity);
          if (component == null || global == null) continue;
          _extractOne(
            world,
            renderWorld,
            entity,
            component,
            global,
            alpha,
            visible,
          );
        }
      }
    }
  }

  /// One sprite, as both paths draw it: culled against [visible], hidden
  /// or transparent ones skipped, interpolated, sorted and added.
  void _extractOne(
    World mainWorld,
    RenderWorld renderWorld,
    Entity entity,
    C component,
    GlobalTransform2D globalTransform,
    double alpha,
    Rect? visible,
  ) {
    // Fully transparent: nothing to draw.
    if (colorOf(component).a == 0) return;
    final size = sizeOf(component);
    // Cull on where it is before the cost of interpolating it: the
    // interpolated position is within a fixed step's movement, well
    // inside the margin.
    if (visible != null && !_onScreen(visible, globalTransform.matrix, size)) {
      return;
    }
    final visibility = mainWorld.get<Visibility>(entity);
    if (visibility != null && !visibility.isVisible) return;

    // Sort key from the draw layer plus a sub-order. The sub-order
    // defaults to Y-position (top-down painter's algorithm) and is clamped
    // into the layer's range so it can't bleed into the next layer
    // bucket. An explicit `layerSubOrder` overrides the Y-based value.
    final renderMatrix = interpolatedRenderMatrix(
      mainWorld,
      entity,
      globalTransform,
      alpha,
    );
    final layerSubOrder = layerSubOrderOf(component);
    final ySorted = layerSubOrder == 0;
    final y = renderMatrix.storage[7];
    final sub = ySorted ? DrawLayerExtension.ySortSubOrder(y) : layerSubOrder;

    renderWorld.addSprite(
      build(
        component,
        entity: entity,
        transform: renderMatrix,
        size: size,
        sortKey: layerOf(component).sortKey(subOrder: sub),
        preciseSubOrder: ySorted ? y * DrawLayerExtension.ySortScale : null,
      ),
    );
  }
}
