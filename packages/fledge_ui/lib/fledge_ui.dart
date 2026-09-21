/// Retained-mode game HUD/UI for Fledge.
///
/// Phase 7 of the restructure: anchor-based layout with containers,
/// text, images, and solid panels painted on top of the sprite
/// pipeline.
///
/// ## Contents
///
/// - [UiNode], [UiSize], [UiOffset], [UiComputedRect] — foundational
///   components every UI entity carries.
/// - [UiAnchor], [UiAnchorComponent] — anchor within the parent's
///   rect.
/// - [UiContainer], [LayoutMode] — row / column / stack layout.
/// - [UiText], [UiImage], [UiRect] — visual node kinds.
/// - [LayoutSystem] — walks the UI hierarchy and computes screen
///   rects (runs in `Schedules.postUpdate`).
/// - [UiExtractor], [ExtractedUiElement] / [ExtractedUiImage] /
///   [ExtractedUiRect] / [ExtractedUiText] — main→render-world
///   handoff.
/// - [FledgeUiOverlay] — widget wrapper that layers the UI paint pass
///   on top of a game render view.
/// - [UiPlugin] — wires the layout system and extractor.
///
/// Focus, keyboard, and gamepad navigation are deliberately out of
/// scope for this phase — see the phase 7b plan.
library;

export 'src/components/ui_anchor.dart';
export 'src/components/ui_container.dart';
export 'src/components/ui_image.dart';
export 'src/components/ui_node.dart';
export 'src/components/ui_rect.dart';
export 'src/components/ui_text.dart';
export 'src/extraction/extracted_ui_element.dart';
export 'src/extraction/ui_extractor.dart';
export 'src/systems/ui_layout_system.dart';
export 'src/ui_plugin.dart';
export 'src/widgets/ui_render_view.dart';
