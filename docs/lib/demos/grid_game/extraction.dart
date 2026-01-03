import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';

import 'components.dart';
import 'resources.dart';

// Re-export the fledge_render classes for convenience
export 'package:fledge_render/fledge_render.dart'
    show RenderWorld, Extractor, Extractors, ExtractSystem, ExtractedData, SortableExtractedData;

/// Entity type for rendering differentiation.
enum GridEntityType {
  player,
  collectible,
  tile,
}

/// Extracted render data for a grid entity.
///
/// Contains pre-computed pixel coordinates and all data needed for rendering,
/// with no references to game logic components.
///
/// This is the render-world equivalent of GridPosition + TileColor + markers.
/// Uses [ExtractedData] mixin to indicate this is render-world data.
class ExtractedGridEntity with ExtractedData {
  /// Pre-computed pixel X coordinate.
  final double pixelX;

  /// Pre-computed pixel Y coordinate.
  final double pixelY;

  /// Tile size in pixels.
  final double size;

  /// Render color.
  final Color color;

  /// Entity type (determines how to draw).
  final GridEntityType entityType;

  const ExtractedGridEntity({
    required this.pixelX,
    required this.pixelY,
    required this.size,
    required this.color,
    required this.entityType,
  });

  /// Convenience getter for the pixel rectangle.
  Rect get rect => Rect.fromLTWH(pixelX, pixelY, size, size);
}

/// Extractor that transforms grid entities into render-ready data.
///
/// For each entity with GridPosition + TileColor:
/// 1. Converts grid coordinates to pixel coordinates
/// 2. Determines entity type from marker components
/// 3. Spawns an ExtractedGridEntity in the render world
class GridEntityExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final config = mainWorld.getResource<GridConfig>();
    if (config == null) return;

    // Query all entities with position and color
    for (final (entity, gridPos, tileColor)
        in mainWorld.query2<GridPosition, TileColor>().iter()) {
      // Convert grid position to pixel position
      final pixelX = gridPos.x * (config.tileSize + config.gap);
      final pixelY = gridPos.y * (config.tileSize + config.gap);

      // Determine entity type from marker components
      GridEntityType entityType;
      if (mainWorld.has<Player>(entity)) {
        entityType = GridEntityType.player;
      } else if (mainWorld.has<Collectible>(entity)) {
        entityType = GridEntityType.collectible;
      } else {
        entityType = GridEntityType.tile;
      }

      // Spawn extracted entity in render world
      renderWorld.spawn().insert(ExtractedGridEntity(
            pixelX: pixelX,
            pixelY: pixelY,
            size: config.tileSize,
            color: tileColor.color,
            entityType: entityType,
          ));
    }
  }
}

/// Extracted grid configuration for the render world.
///
/// Copied from main world's GridConfig so the painter doesn't need
/// to access the main world at all.
class ExtractedGridConfig {
  final int width;
  final int height;
  final double tileSize;
  final double gap;
  final double totalWidth;
  final double totalHeight;

  const ExtractedGridConfig({
    required this.width,
    required this.height,
    required this.tileSize,
    required this.gap,
    required this.totalWidth,
    required this.totalHeight,
  });

  factory ExtractedGridConfig.from(GridConfig config) {
    return ExtractedGridConfig(
      width: config.width,
      height: config.height,
      tileSize: config.tileSize,
      gap: config.gap,
      totalWidth: config.totalWidth,
      totalHeight: config.totalHeight,
    );
  }
}

/// Extractor for grid configuration.
///
/// Copies grid config from main world to render world as a resource.
class GridConfigExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final config = mainWorld.getResource<GridConfig>();
    if (config == null) return;

    renderWorld.insertResource(ExtractedGridConfig.from(config));
  }
}

/// Extracted score for display.
class ExtractedScore {
  final int value;

  const ExtractedScore(this.value);
}

/// Extractor for game score.
class ScoreExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final score = mainWorld.getResource<GameScore>();
    renderWorld.insertResource(ExtractedScore(score?.value ?? 0));
  }
}
