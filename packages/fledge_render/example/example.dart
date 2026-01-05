// ignore_for_file: avoid_print
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';

// Example extracted component for the render world
class ExtractedSprite with ExtractedData {
  final double x;
  final double y;
  final int textureId;

  const ExtractedSprite({
    required this.x,
    required this.y,
    required this.textureId,
  });
}

// Game world components
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Sprite {
  final int textureId;
  Sprite(this.textureId);
}

// Extractor copies data from main world to render world
class SpriteExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (_, pos, sprite)
        in mainWorld.query2<Position, Sprite>().iter()) {
      renderWorld.spawn().insert(ExtractedSprite(
            x: pos.x,
            y: pos.y,
            textureId: sprite.textureId,
          ));
    }
  }
}

/// Example using RenderPlugin (recommended)
void main() {
  // RenderPlugin sets up Extractors, RenderWorld, and RenderExtractionSystem
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(RenderPlugin());

  // Register extractors
  final extractors = app.world.getResource<Extractors>()!;
  extractors.register(SpriteExtractor());

  // Spawn a game entity
  app.world.spawn()
    ..insert(Position(100, 200))
    ..insert(Sprite(1));

  // Run one tick - this runs game logic AND extraction automatically
  app.tick();

  // Query render world for drawing
  final renderWorld = app.world.getResource<RenderWorld>()!;
  for (final (_, sprite) in renderWorld.query1<ExtractedSprite>().iter()) {
    print('Draw sprite ${sprite.textureId} at (${sprite.x}, ${sprite.y})');
  }
}
