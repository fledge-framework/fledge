import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';

import 'components.dart';
import 'resources.dart';

// Re-export the fledge_render plumbing the game widget needs.
export 'package:fledge_render/fledge_render.dart' show RenderWorld, Extractor;

/// Visual kind of an extracted entity. The painter branches on this.
enum VisualKind { player, wall, pickup }

/// Render-ready snapshot of one world entity.
///
/// Immutable; built fresh every frame. The painter never touches the
/// main world — rendering is decoupled from game logic via this type,
/// exactly like Bevy's render-world extraction.
class ExtractedEntity with ExtractedData {
  final Rect rect;
  final VisualKind kind;
  const ExtractedEntity({required this.rect, required this.kind});
}

class ExtractedGameBounds {
  final double width;
  final double height;
  const ExtractedGameBounds(this.width, this.height);
}

/// Copies `GameBounds` from main-world resource to render-world resource.
class GameBoundsExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final b = mainWorld.getResource<GameBounds>();
    if (b == null) return;
    renderWorld.insertResource(ExtractedGameBounds(b.width, b.height));
  }
}

/// Walks each marker-component query and emits an `ExtractedEntity` with
/// pre-computed pixel rects so the painter is dumb and fast.
class DrifterEntityExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    // Player — a square centred on the transform.
    for (final (_, t, _) in mainWorld.query2<Transform2D, Player>().iter()) {
      renderWorld.spawn().insert(ExtractedEntity(
            rect: Rect.fromCenter(
              center: Offset(t.translation.x, t.translation.y),
              width: 20,
              height: 20,
            ),
            kind: VisualKind.player,
          ));
    }

    // Walls — transform is the top-left, collider bounds give the size.
    for (final (_, t, collider, _)
        in mainWorld.query3<Transform2D, Collider, Wall>().iter()) {
      final bounds = collider.bounds;
      renderWorld.spawn().insert(ExtractedEntity(
            rect: Rect.fromLTWH(
              t.translation.x + bounds.left,
              t.translation.y + bounds.top,
              bounds.width,
              bounds.height,
            ),
            kind: VisualKind.wall,
          ));
    }

    // Pickups — drawn as circles centred on the transform.
    for (final (_, t, _) in mainWorld.query2<Transform2D, Pickup>().iter()) {
      renderWorld.spawn().insert(ExtractedEntity(
            rect: Rect.fromCenter(
              center: Offset(t.translation.x, t.translation.y),
              width: 16,
              height: 16,
            ),
            kind: VisualKind.pickup,
          ));
    }
  }
}
