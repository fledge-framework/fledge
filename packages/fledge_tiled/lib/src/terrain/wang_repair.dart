import 'package:tiled/tiled.dart';
import 'package:xml/xml.dart';

/// Restores the Wang tiles of [map]'s tilesets from the XML they were
/// parsed from.
///
/// `package:tiled` (0.12) looks for `<wangtiles>` children where Tiled
/// writes `<wangtile>` elements, so every Wang set parsed from TMX/TSX comes
/// back with no tiles. This reads them from [tmxContent] (embedded tilesets)
/// and [tsxContents] (external ones, keyed by the `source` the map names) and
/// stores each [WangTile.wangId] in Tiled's 8-index form: top, top right,
/// right, bottom right, bottom, bottom left, left, top left, each a 1-based
/// colour index or 0 for unset.
///
/// A Wang set that already has tiles is left alone, so this is a no-op once
/// the upstream parser is fixed.
void repairWangTiles(
  TiledMap map,
  String tmxContent,
  Map<String, String> tsxContents,
) {
  final elements = XmlDocument.parse(tmxContent).rootElement
      .findElements('tileset')
      .toList();
  for (var i = 0; i < map.tilesets.length && i < elements.length; i++) {
    final tileset = map.tilesets[i];
    if (tileset.wangSets.every((set) => set.wangTiles.isNotEmpty)) continue;
    final source = elements[i].getAttribute('source');
    final XmlElement root;
    if (source == null) {
      root = elements[i];
    } else {
      final content = tsxContents[source];
      if (content == null) continue;
      root = XmlDocument.parse(content).rootElement;
    }
    final sets = root
        .findElements('wangsets')
        .expand((e) => e.findElements('wangset'))
        .toList();
    for (var j = 0; j < tileset.wangSets.length && j < sets.length; j++) {
      final set = tileset.wangSets[j];
      if (set.wangTiles.isNotEmpty) continue;
      set.wangTiles = [
        for (final tile in sets[j].findElements('wangtile'))
          if (int.tryParse(tile.getAttribute('tileid') ?? '') case final id?)
            WangTile(
              tileId: id,
              wangId: (tile.getAttribute('wangid') ?? '')
                  .split(',')
                  .map((v) => int.tryParse(v.trim()) ?? 0)
                  .toList(),
            ),
      ];
    }
  }
}
