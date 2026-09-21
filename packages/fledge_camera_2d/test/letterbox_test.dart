import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show RenderSize;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeLetterbox', () {
    test('16:9 target in a 4:3 viewport → horizontal bars', () {
      // 16:9 = 1.777... vs 4:3 = 1.333...
      // Viewport is narrower than target → letterbox (top/bottom bars).
      final rect = computeLetterbox(const RenderSize(800, 600), 16 / 9);
      expect(rect.width, closeTo(800, 1e-6));
      const expectedHeight = 800 / (16 / 9);
      expect(rect.height, closeTo(expectedHeight, 1e-6));
      expect(rect.top, closeTo((600 - expectedHeight) / 2, 1e-6));
    });

    test('4:3 target in a 16:9 viewport → vertical bars', () {
      // Viewport wider than target → pillarbox (left/right bars).
      final rect = computeLetterbox(const RenderSize(1920, 1080), 4 / 3);
      expect(rect.height, closeTo(1080, 1e-6));
      const expectedWidth = 1080 * (4 / 3);
      expect(rect.width, closeTo(expectedWidth, 1e-6));
      expect(rect.left, closeTo((1920 - expectedWidth) / 2, 1e-6));
    });

    test('matching aspect → no bars', () {
      final rect = computeLetterbox(const RenderSize(1600, 900), 16 / 9);
      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.width, closeTo(1600, 1e-6));
      expect(rect.height, closeTo(900, 1e-6));
    });

    test('zero-sized viewport is safe', () {
      final rect = computeLetterbox(const RenderSize(0, 0), 16 / 9);
      expect(rect.width, 0);
      expect(rect.height, 0);
    });

    test('computeGutter returns the black bars', () {
      const viewport = RenderSize(800, 600);
      final game = computeLetterbox(viewport, 16 / 9);
      final gutter = computeGutter(viewport, game);
      expect(gutter, hasLength(2));
      // Horizontal-bar case (viewport narrower than target): bars are
      // on top/bottom.
      expect(gutter[0].top, 0);
      expect(gutter[0].bottom, closeTo(game.top, 1e-6));
      expect(gutter[1].top, closeTo(game.bottom, 1e-6));
      expect(gutter[1].bottom, 600);
    });
  });

  group('OrthographicProjection with LetterboxConfig', () {
    test('projection matrix respects target aspect', () {
      final proj = OrthographicProjection(
        scalingMode: ScalingMode.fixedHeight,
        viewportHeight: 20,
        letterbox: const LetterboxConfig(targetAspect: 16 / 9),
      );
      // Viewport 4:3 (narrower than 16:9) → visible width = height * 16/9.
      final vw = proj.visibleWidth(const RenderSize(800, 600));
      expect(vw, closeTo(20 * 16 / 9, 1e-6));
    });
  });
}
