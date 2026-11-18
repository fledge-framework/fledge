import 'tilemap_extractor.dart';

/// The tilemap extractor with a wider cull margin.
///
/// [TilemapExtractor] culls to the camera's view itself now (through the
/// map's transform and the camera's zoom, visiting only the tiles in
/// view), so this is the same extractor with a 96 px margin, kept for
/// existing code. Use [TilemapExtractor] (`cullMargin:` for the margin).
@Deprecated('Use TilemapExtractor, which culls to the view itself')
class CulledTilemapExtractor extends TilemapExtractor {
  CulledTilemapExtractor({
    super.respectVisibility,
    super.emitLegacyTiles,
    super.cullMargin = 96.0,
  });
}
