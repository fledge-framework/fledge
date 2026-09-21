import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show DrawLayer, DrawLayerExtension, Extractor, RenderWorld;

import '../components/ui_image.dart';
import '../components/ui_node.dart';
import '../components/ui_rect.dart';
import '../components/ui_text.dart';
import 'extracted_ui_element.dart';

/// Extracts UI entities into the render world as
/// [ExtractedUiElement]s.
///
/// Runs on the shared `Extractors` registry — register it once from
/// [UiPlugin.build]. For each UI entity with a [UiComputedRect]:
///
/// - [UiText] → [ExtractedUiText].
/// - [UiImage] → [ExtractedUiImage].
/// - [UiRect] → [ExtractedUiRect] (the widget's paint pass switches
///   between `drawRect` and `drawRRect` based on `borderRadius`).
///
/// Entities without [UiComputedRect] are silently skipped — the
/// layout system runs in `postUpdate`, before extract, so this should
/// only happen when a UI entity was spawned after the layout pass and
/// hasn't been laid out yet.
///
/// Sort keys start at `DrawLayer.ui.sortKey()` and increment per
/// element in extraction order. That gives HUDs a stable draw order
/// (later-added = drawn on top) without games having to hand-tune
/// z-indices.
class UiExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    var seq = 0;
    for (final (entity, _) in mainWorld.query1<UiNode>().iter()) {
      final computed = mainWorld.get<UiComputedRect>(entity);
      if (computed == null) continue;

      // Cap the sub-order at the layer's range so subsequent layers
      // (there aren't any above `ui`, but the guard costs nothing)
      // can't be pushed into.
      final subOrder = seq.clamp(0, DrawLayerExtension.layerMultiplier - 1);
      final sortKey = DrawLayer.ui.sortKey(subOrder: subOrder);
      seq++;

      final text = mainWorld.get<UiText>(entity);
      if (text != null) {
        renderWorld.spawn().insert(
          ExtractedUiText(
            rect: computed.rect,
            sortKey: sortKey,
            text: text.text,
            fontSize: text.fontSize,
            color: text.color,
            fontFamily: text.fontFamily,
            fontWeight: text.fontWeight,
            align: text.align,
          ),
        );
        continue;
      }

      final image = mainWorld.get<UiImage>(entity);
      if (image != null) {
        renderWorld.spawn().insert(
          ExtractedUiImage(
            rect: computed.rect,
            sortKey: sortKey,
            texture: image.texture,
            sourceRect: image.sourceRect,
            tint: image.tint,
          ),
        );
        continue;
      }

      final rect = mainWorld.get<UiRect>(entity);
      if (rect != null) {
        renderWorld.spawn().insert(
          ExtractedUiRect(
            rect: computed.rect,
            sortKey: sortKey,
            color: rect.color,
            borderRadius: rect.borderRadius,
          ),
        );
        continue;
      }

      // Containers with no visual — no extracted output. Their
      // computed rect is only used to lay out their children, which
      // we've already visited via the ECS iteration order.
    }
  }
}
