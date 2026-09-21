import 'package:fledge_assets/fledge_assets.dart';

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

/// A [Loader] that reads a `.tsx` external tileset from a path.
///
/// **Phase 5 status**: not implemented. Tilesets are still loaded as
/// part of the parent `.tmx` file inside [TilemapLoader.load] — there
/// is no standalone `loadTileset(...)` entry point yet. This loader
/// exists so games can express `Assets<TilesetAsset>` in their plugin
/// tables today without waiting for the underlying parser change; use
/// `Assets<TilesetAsset>.add(myTileset)` if you already have a
/// [LoadedTileset] in memory.
///
/// A follow-up phase will add an `AssetTilemapLoader.loadTilesetOnly`
/// entry point and wire it into this class. Until then, calls to
/// [load] throw [UnimplementedError].
class TsxLoader implements Loader<TilesetAsset> {
  const TsxLoader();

  @override
  Future<TilesetAsset> load(String path) {
    throw UnimplementedError(
      'TsxLoader.load: standalone tileset loading is not wired yet. '
      'Load the parent .tmx via TmxLoader, or register an already-loaded '
      'TilesetAsset via Assets<TilesetAsset>.add.',
    );
  }
}
