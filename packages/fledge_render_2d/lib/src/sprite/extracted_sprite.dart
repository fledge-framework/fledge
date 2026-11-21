import 'dart:math' as math;
import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import '../render/camera_view.dart' show ActiveCameraView;
import '../render/extract/draw_layer.dart';
import '../render/extract/extract.dart';
import '../render/extract/extracted_data.dart';
import '../render/world/render_world.dart';
import '../transform/global_transform.dart';
import '../transform/previous_transform.dart';
import '../transform/static_transform.dart';
import '../transform/transform2d.dart';
import 'sprite.dart';

/// Extracted sprite data for the render world.
///
/// This component is created during extraction and contains all the
/// data needed to render a sprite, pre-computed for efficiency.
///
/// Implements [SortableExtractedData] for draw ordering based on [sortKey].
///
/// The [sortKey] is derived from [layer] and a sub-order (Y-position by
/// default, or [layerSubOrder] when non-zero) via
/// [DrawLayerExtension.sortKey]. The sub-order is clamped into the layer's
/// range so a Y-based sub-order cannot bleed into the next layer.
///
/// Because that clamp only leaves room for y = 0..9,999.9, draw order is
/// the composite `(sortKey, preciseSubOrder)`: see [compareDrawOrder]
/// and [sortByDrawOrder], which every framework sprite path uses.
class ExtractedSprite with ExtractedData, SortableExtractedData {
  /// The original entity (for debugging/identification).
  final Entity entity;

  /// The texture to render.
  final TextureHandle texture;

  /// Source rectangle in texture coordinates.
  final Rect sourceRect;

  /// World-space transformation matrix.
  final Matrix3 transform;

  /// Tint color.
  final Color color;

  /// Sort key for draw ordering.
  ///
  /// Computed from [layer] and a sub-order (Y-position by default, or
  /// [layerSubOrder] when non-zero) using [DrawLayerExtension.sortKey].
  @override
  final int sortKey;

  /// Draw layer this sprite belongs to.
  final DrawLayer layer;

  /// Explicit sub-order within [layer], or 0 to use Y-based sub-order.
  final int layerSubOrder;

  /// Unclamped, full-precision sub-order used to break ties between
  /// sprites with an equal [sortKey], or `null` to fall back to the
  /// sub-order packed into [sortKey] (`sortKey % layerMultiplier`).
  ///
  /// Uses the same units as the packed sub-order. Y-sorted extractors
  /// set it to `y * DrawLayerExtension.ySortScale` (no clamp, no
  /// truncation), so sprites outside the integer key's 0..9,999.9 Y
  /// window, or closer than 0.1 px apart, still order by position.
  /// Never consulted when the [sortKey]s differ, so it cannot move a
  /// sprite across layers.
  final double? preciseSubOrder;

  /// Flip flags packed as bits.
  final int flipFlags;

  /// Anchor point.
  final Vector2 anchor;

  /// Sprite size.
  final Vector2 size;

  /// Whether it's drawn after the view passes, at full brightness
  /// (`Sprite.emissive`).
  final bool emissive;

  /// Creates extracted sprite data.
  const ExtractedSprite({
    required this.entity,
    required this.texture,
    required this.sourceRect,
    required this.transform,
    required this.color,
    required this.sortKey,
    this.layer = DrawLayer.characters,
    this.layerSubOrder = 0,
    this.preciseSubOrder,
    this.flipFlags = 0,
    required this.anchor,
    required this.size,
    this.emissive = false,
  });

  /// Whether the sprite is flipped horizontally.
  bool get flipX => (flipFlags & 1) != 0;

  /// Whether the sprite is flipped vertically.
  bool get flipY => (flipFlags & 2) != 0;

  /// Compute flip flags from booleans.
  static int computeFlipFlags(bool flipX, bool flipY) {
    return (flipX ? 1 : 0) | (flipY ? 2 : 0);
  }

  /// The tie-breaking sub-order: [preciseSubOrder], or the sub-order
  /// packed into [sortKey] when that is `null`.
  double get effectiveSubOrder =>
      preciseSubOrder ??
      (sortKey % DrawLayerExtension.layerMultiplier).toDouble();

  /// Draw-order comparator: [sortKey] first, then [effectiveSubOrder].
  ///
  /// A strict refinement of comparing [sortKey] alone: any two sprites
  /// whose keys differ order exactly as before, so layers always
  /// dominate. Only sprites whose integer keys tie (e.g. two Y-sorted
  /// sprites both clamped at y > 9,999.9 or y < 0) are separated by
  /// their precise sub-order. Returns 0 for a full tie; use
  /// [sortByDrawOrder] for a stable sort.
  static int compareDrawOrder(ExtractedSprite a, ExtractedSprite b) {
    final byKey = a.sortKey.compareTo(b.sortKey);
    if (byKey != 0) return byKey;
    return a.effectiveSubOrder.compareTo(b.effectiveSubOrder);
  }

  /// Sort [sprites] in place into draw order ([compareDrawOrder]).
  ///
  /// Stable: sprites with an identical composite key keep their
  /// relative order (render-world extraction order), so equal-key
  /// sprites don't swap from frame to frame.
  static void sortByDrawOrder(List<ExtractedSprite> sprites) {
    final n = sprites.length;
    if (n < 2) return;
    final copy = List<ExtractedSprite>.of(sprites);
    final order = List<int>.generate(n, (i) => i);
    order.sort((i, j) {
      final c = compareDrawOrder(copy[i], copy[j]);
      return c != 0 ? c : i.compareTo(j);
    });
    for (var i = 0; i < n; i++) {
      sprites[i] = copy[order[i]];
    }
  }
}

/// Extractor for sprite components.
///
/// Copies sprite data from the main world to the render world,
/// computing final render data. Entities carrying
/// [PreviousTransform2D] have their translation lerped between the
/// snapshot and the current `Transform2D` by
/// `FixedTimestep.alpha` so 60 Hz simulation stays smooth on higher-
/// refresh displays.
class SpriteExtractor extends Extractor {
  /// World units beyond the camera's last view that are still extracted.
  static const double cullMargin = 64;

  /// Whether a sprite drawn with [m] at [size] could reach into [visible]
  /// (allocation-free: it runs for every sprite in the world).
  static bool _onScreen(Rect visible, Matrix3 m, Vector2 size) {
    final s = m.storage;
    final reach =
        size.x * math.sqrt(s[0] * s[0] + s[1] * s[1]) +
        size.y * math.sqrt(s[3] * s[3] + s[4] * s[4]);
    final x = s[6], y = s[7];
    return x >= visible.left - reach &&
        x < visible.right + reach &&
        y >= visible.top - reach &&
        y < visible.bottom + reach;
  }

  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final alpha = _interpolationAlpha(mainWorld);
    // Skip what's far off screen. The margin covers camera movement since
    // the last paint and sprites whose art reaches past their anchor.
    final visible = mainWorld
        .getResource<ActiveCameraView>()
        ?.visibleWorldRect
        ?.inflate(cullMargin);

    // What can move: every one, culled one by one.
    for (final (entity, sprite, globalTransform)
        in mainWorld
            .query2<Sprite, GlobalTransform2D>(
              filter: const Without<TransformFrozen>(),
            )
            .iter()) {
      _extractOne(
        mainWorld,
        renderWorld,
        entity,
        sprite,
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
  /// texture may change (a building site's stage art) and grow.
  static const double _growMargin = 256;

  final Map<int, List<Entity>> _grid = {};
  StaticTransforms? _builtFor;
  int _builtGeneration = -1;
  double _maxReach = 0;

  static int _key(int x, int y) => (x + 0x8000) * 0x10000 + (y + 0x8000);

  static double _reach(Matrix3 m, Vector2 size) {
    final s = m.storage;
    return size.x * math.sqrt(s[0] * s[0] + s[1] * s[1]) +
        size.y * math.sqrt(s[3] * s[3] + s[4] * s[4]);
  }

  void _rebuild(World world, StaticTransforms frozen) {
    _grid.clear();
    _maxReach = 0;
    for (final (entity, sprite, global)
        in world
            .query2<Sprite, GlobalTransform2D>(
              filter: const With<TransformFrozen>(),
            )
            .iter()) {
      final m = global.matrix.storage;
      (_grid[_key((m[6] / _cell).floor(), (m[7] / _cell).floor())] ??= []).add(
        entity,
      );
      _maxReach = math.max(_maxReach, _reach(global.matrix, sprite.size));
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
      for (final (entity, sprite, global)
          in world
              .query2<Sprite, GlobalTransform2D>(
                filter: const With<TransformFrozen>(),
              )
              .iter()) {
        _extractOne(world, renderWorld, entity, sprite, global, alpha, null);
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
          final sprite = world.get<Sprite>(entity);
          final global = world.get<GlobalTransform2D>(entity);
          if (sprite == null || global == null) continue;
          _extractOne(
            world,
            renderWorld,
            entity,
            sprite,
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
    Sprite sprite,
    GlobalTransform2D globalTransform,
    double alpha,
    Rect? visible,
  ) {
    // Fully transparent: nothing to draw.
    if (sprite.color.a == 0) return;
    final size = sprite.size;
    // Cull on where it is before the cost of interpolating it: the
    // interpolated position is within a fixed step's movement, well
    // inside the margin.
    if (visible != null && !_onScreen(visible, globalTransform.matrix, size)) {
      return;
    }
    final visibility = mainWorld.get<Visibility>(entity);
    if (visibility != null && !visibility.isVisible) return;

    // Compute sort key from the sprite's draw layer plus a sub-order.
    // The sub-order defaults to Y-position (top-down painter's algorithm)
    // and is clamped into the layer's range so it can't bleed into the next
    // layer bucket. An explicit `layerSubOrder` overrides the Y-based value.
    final layer = sprite.layer;
    final renderMatrix = interpolatedRenderMatrix(
      mainWorld,
      entity,
      globalTransform,
      alpha,
    );
    final ySorted = sprite.layerSubOrder == 0;
    final y = renderMatrix.storage[7];
    final sub = ySorted
        ? DrawLayerExtension.ySortSubOrder(y)
        : sprite.layerSubOrder;
    final sortKey = layer.sortKey(subOrder: sub);

    renderWorld.addSprite(
      ExtractedSprite(
        entity: entity,
        texture: sprite.texture,
        sourceRect: sprite.effectiveSourceRect,
        transform: renderMatrix,
        color: sprite.color,
        sortKey: sortKey,
        layer: layer,
        layerSubOrder: sprite.layerSubOrder,
        preciseSubOrder: ySorted ? y * DrawLayerExtension.ySortScale : null,
        flipFlags: ExtractedSprite.computeFlipFlags(sprite.flipX, sprite.flipY),
        anchor: sprite.anchor.clone(),
        size: size,
        emissive: sprite.emissive,
      ),
    );
  }
}

/// Return `FixedTimestep.alpha` if a `FixedTimestep` resource is
/// installed, otherwise 1.0 (no interpolation).
double _interpolationAlpha(World world) {
  final ft = world.getResource<FixedTimestep>();
  return ft?.alpha ?? 1.0;
}

/// Compute the render-time transform matrix for [entity], applying
/// translation interpolation when the entity carries a
/// [PreviousTransform2D] snapshot. If the entity has no snapshot, or
/// [alpha] is at 1.0, [globalTransform.matrix] is returned unchanged.
///
/// Only translation is interpolated; rotation/scale stays at the
/// current step's values. This matches the common use case (moving
/// player / NPC on a static parent) and avoids the SLERP cost for
/// rotation. The result is a *new* Matrix3 for the interpolated
/// case so mutating it does not affect the source `GlobalTransform2D`.
Matrix3 interpolatedRenderMatrix(
  World world,
  Entity entity,
  GlobalTransform2D globalTransform,
  double alpha,
) {
  if (alpha >= 1.0) return globalTransform.matrix;
  final prev = world.get<PreviousTransform2D>(entity);
  if (prev == null) return globalTransform.matrix;
  final current = world.get<Transform2D>(entity);
  if (current == null) return globalTransform.matrix;

  // Interpolate LOCAL translation. Only correct for root entities;
  // see PreviousTransform2D's docstring.
  final ix =
      prev.translation.x + (current.translation.x - prev.translation.x) * alpha;
  final iy =
      prev.translation.y + (current.translation.y - prev.translation.y) * alpha;

  // Rebuild the matrix from the current rotation/scale + interpolated
  // translation. Cheaper than cloning and rewriting the storage.
  final result = globalTransform.matrix.clone();
  result.storage[6] = ix;
  result.storage[7] = iy;
  return result;
}
