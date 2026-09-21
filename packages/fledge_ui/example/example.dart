import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';

/// Minimal fledge_ui example.
///
/// [UiPlugin] wires the retained-mode HUD pipeline on top of
/// [RenderPlugin]: a [LayoutSystem] in `Schedules.postUpdate` walks
/// the UI hierarchy and writes each entity's screen-space rect, then
/// [UiExtractor] hands the laid-out nodes to the render world.
///
/// A UI entity carries [UiNode] as its marker, a [UiAnchorComponent]
/// naming which parent-edge it pins to, an optional [UiOffset] +
/// [UiSize], and one of the visual node kinds — [UiText] here.
void main() async {
  final app = App()
    ..addPlugin(const WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const UiPlugin());

  // Top-left HUD counter — 12px inset from each edge.
  app.world.spawn()
    ..insert(const UiNode())
    ..insert(const UiAnchorComponent(UiAnchor.topLeft))
    ..insert(const UiOffset(x: 12, y: 12))
    ..insert(const UiSize(width: 200, height: 20))
    ..insert(UiText(
      text: 'Score: 0',
      fontSize: 14,
      color: const Color(0xFFFFFFFF),
    ));

  await app.tick();
}
