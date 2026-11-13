import 'dart:ui' show Canvas, Rect;

import 'package:fledge_ecs/fledge_ecs.dart' show World;

/// World-space drawing that [FledgeRenderView] does around the sprites:
/// lighting, fog, screen-wide tints, debug overlays.
///
/// A pass draws through the same camera path as the sprites (including
/// `ActiveCameraView.subpixelScroll`'s offscreen frame), so whatever it
/// draws lines up with them exactly and scrolls with them. Plugins add
/// their passes to the [ViewPasses] resource that `RenderPlugin` inserts;
/// they then apply to every `FledgeRenderView` showing the app, with no
/// special widget.
///
/// The frame is drawn in this order:
///
/// 1. every pass's [paintBehind];
/// 2. every sprite that isn't emissive (`Sprite.emissive`);
/// 3. every pass's [paintOver];
/// 4. the emissive sprites, untouched by what [paintOver] drew.
///
/// So a lighting pass that darkens the scene in [paintOver] leaves lit
/// windows, screens and glowing signs at full brightness.
abstract class ViewPass {
  /// Const constructor for subclasses.
  const ViewPass();

  /// Draws under every sprite. [visibleWorld] is the world-space area the
  /// camera shows; [canvas] is already in world coordinates.
  void paintBehind(World world, Canvas canvas, Rect visibleWorld) {}

  /// Draws over the ordinary sprites and under the emissive ones.
  void paintOver(World world, Canvas canvas, Rect visibleWorld) {}
}

/// The [ViewPass]es every `FledgeRenderView` of an app draws, in order.
/// Inserted by `RenderPlugin`.
class ViewPasses {
  final List<ViewPass> _passes = [];

  /// The passes, in the order they were added.
  List<ViewPass> get passes => List.unmodifiable(_passes);

  /// Adds [pass] after the ones already there (no-op if it's already in).
  void add(ViewPass pass) {
    if (!_passes.contains(pass)) _passes.add(pass);
  }

  /// Removes [pass]; returns whether it was there.
  bool remove(ViewPass pass) => _passes.remove(pass);
}
