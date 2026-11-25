import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureHandle;

import '../resources/tilemap_assets.dart';

/// Abstract interface for loading tilemaps from various sources.
///
/// Implement this interface to support different loading strategies:
/// - Asset bundle (Flutter assets)
/// - File system
/// - Network/HTTP
/// - In-memory
///
/// Example:
/// ```dart
/// final loader = AssetTilemapLoader(assetPrefix: 'assets/maps/');
/// final tilemap = await loader.load(
///   'level1.tmx',
///   (path, width, height) async => await loadTexture(path),
/// );
/// ```
abstract class TilemapLoader {
  /// Loads a tilemap from the given path.
  ///
  /// The [textureLoader] callback is used to load tileset images.
  /// It receives the image path (relative to the map), width, and height.
  Future<LoadedTilemap> load(String path, TextureLoader textureLoader);
}

/// Callback for loading textures.
///
/// Platform-specific implementations should handle image loading
/// and return a [TextureHandle] with the appropriate ID and dimensions.
///
/// Parameters:
/// - [path]: Path to the image file (relative or absolute depending on loader)
/// - [width]: Expected width in pixels (from tileset metadata)
/// - [height]: Expected height in pixels (from tileset metadata)
typedef TextureLoader = Future<TextureHandle> Function(
  String path,
  int width,
  int height,
);

/// Provider for loading TMX/TSX content from different sources.
///
/// Used by loaders to abstract file I/O.
abstract class TiledContentProvider {
  /// Loads the content of a file as a string.
  Future<String> loadString(String path);

  /// Loads the content of a file as bytes.
  Future<List<int>> loadBytes(String path);

  /// Resolves a relative path against a base path.
  String resolvePath(String basePath, String relativePath);
}
