import 'package:fledge_assets/fledge_assets.dart';

import '../loader/asset_tilemap_loader.dart';
import '../loader/tilemap_loader.dart';
import 'tilemap_assets.dart' show LoadedTilemap;
import 'tileset_registry.dart' show LoadedTileset;

/// The value type stored in `Assets<TilemapAsset>` — a parsed `.tmx`
/// tilemap plus every tileset it references.
///
/// Kept as a typedef onto the existing [LoadedTilemap] so downstream
/// code that already speaks in `LoadedTilemap` (spawn systems,
/// extractors, ...) can move onto the new asset store without a
/// class-shape change. Distinct from the `Tilemap` **component** in
/// `src/components/tilemap.dart`, which is a lightweight per-entity
/// summary of the same map — the component is what you attach to an
/// entity; the asset is what you load, refcount, and hot-reload. A
/// future release will collapse these once the component migrates.
typedef TilemapAsset = LoadedTilemap;

/// The value type stored in `Assets<TilesetAsset>` — a parsed `.tsx`
/// tileset plus its texture atlas.
///
/// Aliased onto the existing [LoadedTileset] for the same reason
/// [TilemapAsset] aliases [LoadedTilemap]. Named with an `Asset`
/// suffix to leave room for a future `Tileset` component.
typedef TilesetAsset = LoadedTileset;

/// A [Loader] that reads a `.tmx` tilemap from a path.
///
/// Wraps [TilemapLoader] (the existing content-source-agnostic
/// interface) so games can drop a tilemap into `Assets<TilemapAsset>`
/// with the same "path → Handle" ergonomics used elsewhere. The
/// internal tilemap loader still handles the actual TMX parsing; this
/// class only bridges its shape into the generic `Loader<T>` contract.
class TmxLoader implements Loader<TilemapAsset> {
  /// The underlying tilemap loader (asset bundle, file system, ...).
  final TilemapLoader tilemapLoader;

  /// Callback that resolves tileset image paths into `TextureHandle`s.
  /// Injected because the render-side texture registration is
  /// game-specific (asset bundle vs `dart:io.File`).
  final TextureLoader textureLoader;

  const TmxLoader({required this.tilemapLoader, required this.textureLoader});

  @override
  Future<TilemapAsset> load(String path) =>
      tilemapLoader.load(path, textureLoader);
}

/// A [Loader] that reads a `.tsx` external tileset from a path, with its
/// image (or, for an image-collection tileset, each tile's image) loaded
/// through [textureLoader].
///
/// Parses with the same code [AssetTilemapLoader] uses for a map's
/// external tilesets, so properties, animations, collision shapes, tile
/// classes and `y_sort` spans come out the same. A tileset loaded on its
/// own isn't part of a map, so its [LoadedTileset.firstGid] is 1.
///
/// ```dart
/// final tilesets = world.getResource<Assets<TilesetAsset>>()!;
/// final handle = tilesets.load(
///   'assets/tilesets/terrain.tsx',
///   TsxLoader(
///     loadStringContent: rootBundle.loadString,
///     textureLoader: textureLoader,
///   ),
/// );
/// ```
///
/// External tilesets referenced by a `.tmx` are still loaded with the map
/// by [TmxLoader]; this is for tilesets used without one.
class TsxLoader implements Loader<TilesetAsset> {
  /// Reads a file's text: the `.tsx` (at [assetPrefix] + path).
  ///
  /// Required: the default constructor leaves it null only so existing
  /// `const TsxLoader()` calls compile; [load] throws a [StateError]
  /// without it.
  final Future<String> Function(String path)? loadStringContent;

  /// Turns the tileset's image paths (resolved against the `.tsx`'s
  /// folder) into textures. Required, like [loadStringContent].
  final TextureLoader? textureLoader;

  /// Prefix added to every path passed to [load].
  final String assetPrefix;

  const TsxLoader({
    this.loadStringContent,
    this.textureLoader,
    this.assetPrefix = '',
  });

  @override
  Future<TilesetAsset> load(String path) async {
    final loadString = loadStringContent;
    final textures = textureLoader;
    if (loadString == null || textures == null) {
      throw StateError(
        'TsxLoader.load($path): construct the loader with both '
        'loadStringContent and textureLoader.',
      );
    }
    final fullPath = '$assetPrefix$path';
    final slash = fullPath.lastIndexOf('/');
    final directory = slash < 0 ? '' : fullPath.substring(0, slash + 1);
    final file = fullPath.substring(slash + 1);
    // A one-tileset map around the .tsx, so it's parsed and its images
    // resolved exactly as a map's external tileset is.
    final tmx =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<map version="1.10" orientation="orthogonal" '
        'renderorder="right-down" width="1" height="1" tilewidth="1" '
        'tileheight="1" infinite="0">'
        '<tileset firstgid="1" source="${_escapeAttribute(file)}"/>'
        '</map>';
    final map = await AssetTilemapLoader(loadStringContent: loadString)
        .loadFromString(tmx, directory, textures, loadString, sourcePath: path);
    return map.tilesets.single;
  }

  static String _escapeAttribute(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;');
}
