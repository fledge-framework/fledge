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
    for (final (_, pos, sprite) in mainWorld.query2<Position, Sprite>().iter()) {
      renderWorld.spawn().insert(ExtractedSprite(
            x: pos.x,
            y: pos.y,
            textureId: sprite.textureId,
          ));
    }
  }
}

void main() {
  final world = World();
  final renderWorld = RenderWorld();

  // Register extractors as a resource
  final extractors = Extractors()..register(SpriteExtractor());
  world.insertResource(extractors);

  // Spawn a game entity
  world.spawn()
    ..insert(Position(100, 200))
    ..insert(Sprite(1));

  // Extract to render world (happens each frame)
  final extractSystem = ExtractSystem();
  extractSystem.run(world, renderWorld);

  // Query render world for drawing
  for (final (_, sprite) in renderWorld.query1<ExtractedSprite>().iter()) {
    // ignore: avoid_print
    print('Draw sprite ${sprite.textureId} at (${sprite.x}, ${sprite.y})');
  }
}
