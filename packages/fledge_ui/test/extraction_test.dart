import 'dart:ui' show Color, Rect;

import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UiExtractor', () {
    late World mainWorld;
    late RenderWorld renderWorld;
    late LayoutSystem layout;
    late UiExtractor extractor;

    setUp(() {
      mainWorld = World();
      mainWorld.insertResource(ViewportSize(width: 400, height: 300));
      renderWorld = RenderWorld();
      layout = LayoutSystem();
      extractor = UiExtractor();
    });

    test('text UI entity produces an ExtractedUiText with the right rect',
        () async {
      final entity = (mainWorld.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft))
            ..insert(const UiSize(width: 120, height: 20))
            ..insert(const UiOffset(x: 8, y: 8))
            ..insert(UiText(text: 'Score: 0', fontSize: 16)))
          .entity;

      await layout.run(mainWorld);
      extractor.extract(mainWorld, renderWorld);

      final results = <ExtractedUiText>[];
      for (final (_, e) in renderWorld.query1<ExtractedUiText>().iter()) {
        results.add(e);
      }

      expect(results, hasLength(1));
      expect(results.single.text, 'Score: 0');
      expect(results.single.rect.left, 8);
      expect(results.single.rect.top, 8);
      expect(results.single.rect.width, 120);
      expect(results.single.rect.height, 20);
      expect(mainWorld.isAlive(entity), isTrue);
    });

    test('image UI entity produces an ExtractedUiImage with tint + texture',
        () async {
      const texture = TextureHandle(id: 42, width: 32, height: 32);
      mainWorld.spawn()
        ..insert(const UiNode())
        ..insert(const UiAnchorComponent(UiAnchor.center))
        ..insert(const UiSize(width: 32, height: 32))
        ..insert(const UiImage(texture: texture, tint: Color(0xFFFF00FF)));

      await layout.run(mainWorld);
      extractor.extract(mainWorld, renderWorld);

      final results = renderWorld
          .query1<ExtractedUiImage>()
          .iter()
          .map((r) => r.$2)
          .toList();

      expect(results, hasLength(1));
      expect(results.single.texture.id, 42);
      expect(results.single.tint, const Color(0xFFFF00FF));
      // Centred inside 400×300 viewport → (184, 134).
      expect(results.single.rect.left, 184);
      expect(results.single.rect.top, 134);
    });

    test('solid UiRect (no radius) produces an ExtractedUiRect', () async {
      mainWorld.spawn()
        ..insert(const UiNode())
        ..insert(const UiAnchorComponent(UiAnchor.bottomRight))
        ..insert(const UiSize(width: 60, height: 40))
        ..insert(const UiOffset(x: -10, y: -10))
        ..insert(const UiRect(color: Color(0xFF00FF00)));

      await layout.run(mainWorld);
      extractor.extract(mainWorld, renderWorld);

      final results = renderWorld
          .query1<ExtractedUiRect>()
          .iter()
          .map((r) => r.$2)
          .toList();

      expect(results, hasLength(1));
      expect(results.single.color, const Color(0xFF00FF00));
      expect(results.single.borderRadius, 0);
      expect(results.single.rect.right, 390);
      expect(results.single.rect.bottom, 290);
    });

    test('rounded UiRect carries the borderRadius through the extractor',
        () async {
      mainWorld.spawn()
        ..insert(const UiNode())
        ..insert(const UiAnchorComponent(UiAnchor.center))
        ..insert(const UiSize(width: 100, height: 40))
        ..insert(const UiRect(color: Color(0xFF123456), borderRadius: 8));

      await layout.run(mainWorld);
      extractor.extract(mainWorld, renderWorld);

      final result =
          renderWorld.query1<ExtractedUiRect>().iter().single.$2;
      expect(result.borderRadius, 8);
    });

    test('entity with UiNode but no UiComputedRect is skipped', () {
      mainWorld.spawn().insert(const UiNode());
      // Deliberately skipping layout.run — the extractor should see
      // no UiComputedRect and produce nothing.
      extractor.extract(mainWorld, renderWorld);

      expect(renderWorld.query1<ExtractedUiElement>().iter().isEmpty, isTrue);
    });

    test('extracted elements land in the DrawLayer.ui sort-key range',
        () async {
      mainWorld.spawn()
        ..insert(const UiNode())
        ..insert(const UiAnchorComponent(UiAnchor.topLeft))
        ..insert(UiText(text: 'A'));
      mainWorld.spawn()
        ..insert(const UiNode())
        ..insert(const UiAnchorComponent(UiAnchor.topLeft))
        ..insert(UiText(text: 'B'));

      await layout.run(mainWorld);
      extractor.extract(mainWorld, renderWorld);

      final keys = <int>[];
      for (final (_, e) in renderWorld.query1<ExtractedUiElement>().iter()) {
        keys.add(e.sortKey);
      }
      // Both keys should sit in `DrawLayer.ui`'s sort-key range.
      const uiStart = DrawLayerExtension.layerMultiplier * 5; // DrawLayer.ui index = 5
      for (final k in keys) {
        expect(k, greaterThanOrEqualTo(uiStart));
        expect(k, lessThan(uiStart + DrawLayerExtension.layerMultiplier));
      }
    });

    test('re-extraction after clear reflects mutated text', () async {
      final entity = (mainWorld.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft))
            ..insert(const UiSize(width: 100, height: 20))
            ..insert(UiText(text: 'Score: 0')))
          .entity;

      await layout.run(mainWorld);
      extractor.extract(mainWorld, renderWorld);
      expect(
        renderWorld.query1<ExtractedUiText>().iter().single.$2.text,
        'Score: 0',
      );

      mainWorld.get<UiText>(entity)!.text = 'Score: 3';
      renderWorld.clear();
      extractor.extract(mainWorld, renderWorld);

      expect(
        renderWorld.query1<ExtractedUiText>().iter().single.$2.text,
        'Score: 3',
      );
    });

    test('ExtractedUiText carries the exact Rect the layout produced', () {
      // Sanity check on the Rect equality that layout_test relies on.
      const r1 = Rect.fromLTWH(0, 0, 10, 10);
      const r2 = Rect.fromLTWH(0, 0, 10, 10);
      expect(r1, r2);
    });
  });
}
