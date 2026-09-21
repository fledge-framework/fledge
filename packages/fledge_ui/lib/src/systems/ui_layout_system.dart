import 'dart:ui' show Rect;

import 'package:fledge_camera_2d/fledge_camera_2d.dart' show ViewportSize;
import 'package:fledge_ecs/fledge_ecs.dart';

import '../components/ui_anchor.dart';
import '../components/ui_container.dart';
import '../components/ui_image.dart';
import '../components/ui_node.dart';
import '../components/ui_rect.dart';
import '../components/ui_text.dart';

/// Approximation used when a [UiText] has no explicit [UiSize].
///
/// Real text shaping is deferred to the paint thread (see the widget
/// overlay), which would be too expensive to run for every node in
/// the main-world layout pass. The heuristic below produces a
/// reasonable fallback for short single-line HUD strings; games that
/// need tight fit should supply a [UiSize] on the text entity.
const double _kApproximateGlyphWidthFactor = 0.55;
const double _kApproximateLineHeightFactor = 1.2;

/// Walks the UI hierarchy each frame and writes a [UiComputedRect] on
/// every entity that carries [UiNode].
///
/// Runs in `Schedules.postUpdate` — after `TransformPropagateSystem`
/// and camera systems, so the [ViewportSize] resource is up-to-date
/// for the frame being rendered. The extractor then reads the
/// computed rect in `Schedules.extract`.
///
/// Algorithm:
///
/// 1. Find every root UI node (a [UiNode] with no [Parent]).
/// 2. For each root, recursively size + place the entity within the
///    viewport rect.
/// 3. Containers with children delegate their interior layout to the
///    appropriate mode ([LayoutMode.stack], [LayoutMode.row], or
///    [LayoutMode.column]).
class LayoutSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'ui_layout',
    reads: {
      ComponentId.of<UiNode>(),
      ComponentId.of<UiSize>(),
      ComponentId.of<UiOffset>(),
      ComponentId.of<UiAnchorComponent>(),
      ComponentId.of<UiContainer>(),
      ComponentId.of<UiText>(),
      ComponentId.of<UiImage>(),
      ComponentId.of<UiRect>(),
      ComponentId.of<Parent>(),
      ComponentId.of<Children>(),
    },
    writes: {ComponentId.of<UiComputedRect>()},
    resourceReads: {ViewportSize},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final viewport = world.getResource<ViewportSize>();
    if (viewport == null) return;

    final viewportRect = Rect.fromLTWH(0, 0, viewport.width, viewport.height);

    // Find root UI nodes — UiNode entities with no Parent. Materialise
    // to a list because we mutate archetypes while inserting
    // UiComputedRect on entities that don't have one yet.
    final roots = <Entity>[];
    for (final (entity, _) in world.query1<UiNode>().iter()) {
      if (world.get<Parent>(entity) == null) {
        roots.add(entity);
      }
    }

    for (final root in roots) {
      _layoutNode(world, root, viewportRect);
    }
  }

  /// Recursively size + place [node] inside [parentRect] and write its
  /// [UiComputedRect].
  void _layoutNode(World world, Entity node, Rect parentRect) {
    final size = _resolveSize(world, node, parentRect);
    final anchor =
        world.get<UiAnchorComponent>(node)?.anchor ?? UiAnchor.topLeft;
    final offset = world.get<UiOffset>(node) ?? const UiOffset();

    final (anx, any) = anchor.normalized;
    // Anchor semantics: the child's anchor point sits on the parent's
    // anchor point. topLeft → child (0,0) sits at parent topLeft;
    // center → child centre sits at parent centre; etc.
    final left =
        parentRect.left + parentRect.width * anx - size.width * anx + offset.x;
    final top =
        parentRect.top + parentRect.height * any - size.height * any + offset.y;

    final rect = Rect.fromLTWH(left, top, size.width, size.height);
    _writeComputedRect(world, node, rect);

    // If this node is a container, lay out its children inside the
    // padded interior.
    final container = world.get<UiContainer>(node);
    if (container == null) return;

    final children = world.get<Children>(node);
    if (children == null || children.isEmpty) return;

    final interior = Rect.fromLTWH(
      rect.left + container.paddingLeft,
      rect.top + container.paddingTop,
      (rect.width - container.horizontalPadding).clamp(0.0, double.infinity),
      (rect.height - container.verticalPadding).clamp(0.0, double.infinity),
    );

    switch (container.mode) {
      case LayoutMode.stack:
        for (final child in children.children) {
          _layoutNode(world, child, interior);
        }
      case LayoutMode.row:
        _layoutRow(world, children.children.toList(), interior, container.gap);
      case LayoutMode.column:
        _layoutColumn(
          world,
          children.children.toList(),
          interior,
          container.gap,
        );
    }
  }

  /// Row layout: pack children left-to-right using each child's own
  /// intrinsic size, ignoring the row's cross-axis anchor. Each child
  /// gets a slot rect of its own size positioned at the current x
  /// cursor, vertically anchored inside [interior].
  void _layoutRow(
    World world,
    List<Entity> children,
    Rect interior,
    double gap,
  ) {
    var x = interior.left;
    for (final child in children) {
      final size = _resolveSize(world, child, interior);
      // Slot rect that this child anchors inside — its own size,
      // positioned at the current x cursor and spanning the full
      // interior height so vertical anchors work as expected.
      final slot = Rect.fromLTWH(x, interior.top, size.width, interior.height);
      _layoutNode(world, child, slot);
      x += size.width + gap;
    }
  }

  /// Mirror of [_layoutRow] for column layout.
  void _layoutColumn(
    World world,
    List<Entity> children,
    Rect interior,
    double gap,
  ) {
    var y = interior.top;
    for (final child in children) {
      final size = _resolveSize(world, child, interior);
      final slot = Rect.fromLTWH(interior.left, y, interior.width, size.height);
      _layoutNode(world, child, slot);
      y += size.height + gap;
    }
  }

  /// Insert or update the [UiComputedRect] on [node].
  void _writeComputedRect(World world, Entity node, Rect rect) {
    final existing = world.get<UiComputedRect>(node);
    if (existing == null) {
      world.insert(node, UiComputedRect(rect));
    } else {
      existing.rect = rect;
    }
  }

  /// Resolve an entity's size, falling back to content extents when
  /// no explicit [UiSize] is provided.
  ///
  /// Resolution order:
  ///
  /// 1. Explicit [UiSize] on the entity.
  /// 2. If a [UiContainer]: sum of children's intrinsic sizes plus
  ///    gaps and padding (row/column) or the tightest single-child
  ///    fit (stack).
  /// 3. If a [UiText]: approximate glyph-based extents.
  /// 4. If a [UiImage]: source-rect (or texture) dimensions.
  /// 5. If a [UiRect]: the parent's full interior — solid panels
  ///    default to filling their slot.
  /// 6. Fallback: the parent's rect dimensions.
  _Size _resolveSize(World world, Entity node, Rect parentRect) {
    final explicit = world.get<UiSize>(node);
    if (explicit != null) {
      return _Size(explicit.width, explicit.height);
    }

    final container = world.get<UiContainer>(node);
    if (container != null) {
      return _containerIntrinsicSize(world, node, container, parentRect);
    }

    final text = world.get<UiText>(node);
    if (text != null) {
      return _approximateTextSize(text);
    }

    final image = world.get<UiImage>(node);
    if (image != null) {
      final src = image.sourceRect;
      if (src != null) {
        return _Size(src.width, src.height);
      }
      return _Size(
        image.texture.width.toDouble(),
        image.texture.height.toDouble(),
      );
    }

    // UiRect with no explicit size fills its slot — matches the
    // "panel behind children" pattern common in HUDs.
    if (world.get<UiRect>(node) != null) {
      return _Size(parentRect.width, parentRect.height);
    }

    return _Size(parentRect.width, parentRect.height);
  }

  _Size _containerIntrinsicSize(
    World world,
    Entity node,
    UiContainer container,
    Rect parentRect,
  ) {
    final children = world.get<Children>(node);
    if (children == null || children.isEmpty) {
      return _Size(container.horizontalPadding, container.verticalPadding);
    }

    final childList = children.children.toList();

    switch (container.mode) {
      case LayoutMode.stack:
        var w = 0.0;
        var h = 0.0;
        for (final child in childList) {
          final size = _resolveSize(world, child, parentRect);
          if (size.width > w) w = size.width;
          if (size.height > h) h = size.height;
        }
        return _Size(
          w + container.horizontalPadding,
          h + container.verticalPadding,
        );
      case LayoutMode.row:
        var w = 0.0;
        var h = 0.0;
        for (var i = 0; i < childList.length; i++) {
          final size = _resolveSize(world, childList[i], parentRect);
          w += size.width;
          if (i > 0) w += container.gap;
          if (size.height > h) h = size.height;
        }
        return _Size(
          w + container.horizontalPadding,
          h + container.verticalPadding,
        );
      case LayoutMode.column:
        var w = 0.0;
        var h = 0.0;
        for (var i = 0; i < childList.length; i++) {
          final size = _resolveSize(world, childList[i], parentRect);
          h += size.height;
          if (i > 0) h += container.gap;
          if (size.width > w) w = size.width;
        }
        return _Size(
          w + container.horizontalPadding,
          h + container.verticalPadding,
        );
    }
  }

  _Size _approximateTextSize(UiText text) {
    // Coarse but stable — good enough for HUD-scale strings. Games
    // that need pixel-perfect text bounds should supply UiSize.
    final estWidth =
        text.text.length * text.fontSize * _kApproximateGlyphWidthFactor;
    final estHeight = text.fontSize * _kApproximateLineHeightFactor;
    return _Size(estWidth, estHeight);
  }
}

/// Internal size type — kept private because the public API surfaces
/// this through [UiSize] and [UiComputedRect].
class _Size {
  final double width;
  final double height;
  const _Size(this.width, this.height);
}
