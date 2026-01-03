import 'dart:ui';

import 'package:flutter/material.dart' hide Color;

import 'extraction.dart';

/// Custom painter that renders the grid game from the render world.
///
/// This painter demonstrates the two-world architecture:
/// - It queries ONLY the [RenderWorld], never the main game world
/// - It uses pre-computed [ExtractedGridEntity] data (pixel positions ready)
/// - Game logic components (GridPosition, Player, etc.) are not visible here
///
/// Benefits of this approach:
/// - Rendering code is decoupled from game logic
/// - Data is GPU-optimized (pixel coords pre-computed)
/// - The painter doesn't need to know about grid coordinates
class GridGamePainter extends CustomPainter {
  final RenderWorld renderWorld;

  /// Tracks the last known state hash for repaint optimization.
  int _lastStateHash = 0;

  GridGamePainter(this.renderWorld);

  @override
  void paint(Canvas canvas, Size size) {
    final config = renderWorld.getResource<ExtractedGridConfig>();
    if (config == null) return;

    final paint = Paint()..style = PaintingStyle.fill;

    _drawGridBackground(canvas, config, paint);
    _drawEntities(canvas, config, paint);
  }

  /// Draws all extracted entities.
  ///
  /// Note: We query ExtractedGridEntity from the render world.
  /// The pixel coordinates are already computed - no grid math needed!
  void _drawEntities(Canvas canvas, ExtractedGridConfig config, Paint paint) {
    for (final (_, extracted)
        in renderWorld.query1<ExtractedGridEntity>().iter()) {
      paint.color = extracted.color;

      switch (extracted.entityType) {
        case GridEntityType.player:
          _drawPlayer(canvas, extracted.rect, paint);
        case GridEntityType.collectible:
          _drawCollectible(canvas, extracted, paint);
        case GridEntityType.tile:
          _drawTile(canvas, extracted.rect, paint);
      }
    }
  }

  /// Draws the player entity with rounded corners and border.
  void _drawPlayer(Canvas canvas, Rect rect, Paint paint) {
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    // Fill
    canvas.drawRRect(rRect, paint);

    // Border
    paint
      ..color = const Color(0xFF00AA00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rRect, paint);
    paint.style = PaintingStyle.fill;
  }

  /// Draws a collectible as a circle with shine effect.
  void _drawCollectible(
      Canvas canvas, ExtractedGridEntity extracted, Paint paint) {
    final center = extracted.rect.center;
    final radius = extracted.size / 2 - 2;

    // Main circle
    canvas.drawCircle(Offset(center.dx, center.dy), radius, paint);

    // Shine effect
    paint.color = const Color(0xFFFFE55C);
    canvas.drawCircle(
      Offset(center.dx - radius / 3, center.dy - radius / 3),
      radius / 4,
      paint,
    );
  }

  /// Draws a regular tile with slight rounding.
  void _drawTile(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      paint,
    );
  }

  /// Draws the grid background and empty cell placeholders.
  void _drawGridBackground(
      Canvas canvas, ExtractedGridConfig config, Paint paint) {
    // Draw background
    paint.color = const Color(0xFF1A1A2E);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, config.totalWidth, config.totalHeight),
      paint,
    );

    // Draw grid cell backgrounds (empty cells)
    paint.color = const Color(0xFF252540);
    for (var x = 0; x < config.width; x++) {
      for (var y = 0; y < config.height; y++) {
        final px = x * (config.tileSize + config.gap);
        final py = y * (config.tileSize + config.gap);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(px, py, config.tileSize, config.tileSize),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridGamePainter oldDelegate) {
    // Compute a simple state hash based on extracted entity data
    final newHash = _computeStateHash();
    if (newHash != _lastStateHash) {
      _lastStateHash = newHash;
      return true;
    }
    return false;
  }

  /// Computes a hash of the current render state for repaint optimization.
  int _computeStateHash() {
    var hash = 0;

    // Hash all extracted entities
    for (final (entity, extracted)
        in renderWorld.query1<ExtractedGridEntity>().iter()) {
      hash ^= entity.hashCode ^
          extracted.pixelX.toInt() ^
          (extracted.pixelY.toInt() << 8) ^
          (extracted.entityType.index << 16);
    }

    // Include score in hash
    final score = renderWorld.getResource<ExtractedScore>()?.value ?? 0;
    hash ^= score << 24;

    return hash;
  }
}
