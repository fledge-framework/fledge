import 'dart:ui' show Offset;

import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show TextureHandle, TextureAtlas, GridAtlasLayout;
import 'package:tiled/tiled.dart';
import 'package:xml/xml.dart';

import '../components/tilemap_animator.dart';
import '../properties/tiled_properties.dart';
import '../resources/tilemap_assets.dart';
import '../resources/tileset_registry.dart';
import 'tilemap_loader.dart';

/// Cache for loaded TSX content, keyed by file path.
final Map<String, String> _tsxCache = {};

/// Loader for tilemaps bundled as Flutter assets or loaded from strings.
///
/// This loader parses TMX content and loads associated tilesets and textures.
///
/// Example:
/// ```dart
/// final loader = AssetTilemapLoader();
///
/// // Load from string content
/// final tmxContent = await rootBundle.loadString('assets/maps/level1.tmx');
/// final tilemap = await loader.loadFromString(
///   tmxContent,
///   'assets/maps/',
///   (path, w, h) async => await loadTexture(path),
///   (path) async => await rootBundle.loadString(path),
/// );
/// ```
class AssetTilemapLoader implements TilemapLoader {
  /// Prefix added to all asset paths.
  final String assetPrefix;

  /// Function to load string content from assets.
  final Future<String> Function(String path) loadStringContent;

  AssetTilemapLoader({this.assetPrefix = '', required this.loadStringContent});

  @override
  Future<LoadedTilemap> load(String path, TextureLoader textureLoader) async {
    final fullPath = '$assetPrefix$path';
    final tmxContent = await loadStringContent(fullPath);
    final basePath = _getDirectory(fullPath);

    return loadFromString(
      tmxContent,
      basePath,
      textureLoader,
      (p) => loadStringContent(p),
      sourcePath: path,
    );
  }

  /// Loads a tilemap from TMX string content.
  ///
  /// Parameters:
  /// - [tmxContent]: The TMX file content as a string
  /// - [basePath]: Base path for resolving relative paths (tilesets, images)
  /// - [textureLoader]: Callback to load texture images
  /// - [tsxLoader]: Callback to load external TSX files
  /// - [sourcePath]: Original source path for reloading
  Future<LoadedTilemap> loadFromString(
    String tmxContent,
    String basePath,
    TextureLoader textureLoader,
    Future<String> Function(String path) tsxLoader, {
    String sourcePath = '',
  }) async {
    // Pre-load all TSX files referenced in the TMX and expose them through a
    // ParserProvider so that `TiledMap.parseTmx` can resolve external tilesets
    // synchronously.
    final provider = await _loadTsxProvider(tmxContent, basePath, tsxLoader);

    // Parse the TMX file
    final tiledMap = TiledMap.parseTmx(tmxContent, providers: [provider]);

    // Load all tilesets
    final loadedTilesets = <LoadedTileset>[];
    final animations = <int, TileAnimation>{};

    for (final tileset in tiledMap.tilesets) {
      final loaded = await _loadTileset(tileset, basePath, textureLoader);
      loadedTilesets.add(loaded);

      // Extract animations with global IDs
      for (final entry in loaded.animations.entries) {
        final gid = entry.key + loaded.firstGid;
        animations[gid] = entry.value;
      }
    }

    return LoadedTilemap(
      map: tiledMap,
      tilesets: loadedTilesets,
      animations: animations,
      sourcePath: sourcePath,
    );
  }

  Future<LoadedTileset> _loadTileset(
    Tileset tileset,
    String basePath,
    TextureLoader textureLoader,
  ) async {
    // Determine image path and dimensions
    String? imagePath;
    int imageWidth = 0;
    int imageHeight = 0;

    if (tileset.image != null) {
      imagePath = _resolvePath(basePath, tileset.image!.source!);
      imageWidth = tileset.image!.width ?? 0;
      imageHeight = tileset.image!.height ?? 0;
    }

    // Get tileset dimensions with defaults
    final tileWidth = tileset.tileWidth ?? 0;
    final tileHeight = tileset.tileHeight ?? 0;
    final columns = tileset.columns ?? 1;
    final tileCount = tileset.tileCount ?? 0;

    // Load texture if we have an image
    TextureHandle? texture;
    if (imagePath != null) {
      // Calculate dimensions if not provided
      if (imageWidth == 0 && columns > 0) {
        imageWidth = columns * tileWidth;
      }
      if (imageHeight == 0 && columns > 0 && tileCount > 0) {
        final rows = (tileCount + columns - 1) ~/ columns;
        imageHeight = rows * tileHeight;
      }

      texture = await textureLoader(imagePath, imageWidth, imageHeight);
    } else {
      // Create a placeholder texture handle for image collection tilesets
      texture = TextureHandle(id: 0, width: 0, height: 0);
    }

    // Create the texture atlas
    final atlas = TextureAtlas(
      texture: texture,
      layout: GridAtlasLayout(
        textureWidth: texture.width,
        textureHeight: texture.height,
        columns: columns > 0 ? columns : 1,
        rows: tileCount > 0 && columns > 0
            ? (tileCount + columns - 1) ~/ columns
            : 1,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        paddingX: tileset.spacing,
        paddingY: tileset.spacing,
        offsetX: tileset.margin,
        offsetY: tileset.margin,
      ),
    );

    // Extract tile properties, animations, and collision
    final tileProperties = <int, TiledProperties>{};
    final tileAnimations = <int, TileAnimation>{};
    final collisionShapes = <int, List<CollisionShape>>{};

    for (final tile in tileset.tiles) {
      final localId = tile.localId;

      // Properties
      if (tile.properties.isNotEmpty) {
        tileProperties[localId] = TiledProperties.fromCustomProperties(
          tile.properties,
        );
      }

      // Animation
      if (tile.animation.isNotEmpty) {
        tileAnimations[localId] = TileAnimation(
          frames: tile.animation
              .map(
                (frame) => TileAnimationFrame(
                  tileId: frame.tileId,
                  duration: frame.duration / 1000.0,
                ),
              )
              .toList(),
        );
      }

      // Collision (from objectGroup)
      if (tile.objectGroup != null && tile.objectGroup is ObjectGroup) {
        final shapes = <CollisionShape>[];
        final objectGroup = tile.objectGroup as ObjectGroup;
        for (final obj in objectGroup.objects) {
          shapes.addAll(_parseCollisionObject(obj));
        }
        if (shapes.isNotEmpty) {
          collisionShapes[localId] = shapes;
        }
      }
    }

    return LoadedTileset(
      source: tileset.source ?? '',
      name: tileset.name ?? '',
      firstGid: tileset.firstGid ?? 1,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      columns: columns > 0 ? columns : 1,
      tileCount: tileCount > 0 ? tileCount : 1,
      spacing: tileset.spacing,
      margin: tileset.margin,
      atlas: atlas,
      tileProperties: tileProperties,
      animations: tileAnimations,
      collisionShapes: collisionShapes,
    );
  }

  /// Pre-loads all TSX files referenced in the TMX content and wraps them in a
  /// [ParserProvider] keyed by the source path exactly as it appears in the
  /// map (paths are always relative to the map file — see [ParserProvider]).
  Future<_FledgeTsxProvider> _loadTsxProvider(
    String tmxContent,
    String basePath,
    Future<String> Function(String path) loadString,
  ) async {
    // Parse the TMX to find tileset sources.
    final doc = XmlDocument.parse(tmxContent);
    final tilesetElements = doc.rootElement.findElements('tileset');

    final contents = <String, String>{};

    for (final element in tilesetElements) {
      final source = element.getAttribute('source');
      if (source == null) continue;

      final tsxPath = _resolvePath(basePath, source);

      // Load the TSX content if not cached (cache is shared across map loads).
      final content = _tsxCache[tsxPath] ??= await loadString(tsxPath);
      contents[source] = content;
    }

    return _FledgeTsxProvider(contents);
  }

  List<CollisionShape> _parseCollisionObject(TiledObject obj) {
    if (obj.isPolygon && obj.polygon.isNotEmpty) {
      return [
        PolygonShape(
          points: obj.polygon.map((p) => Offset(p.x, p.y)).toList(),
          offsetX: obj.x,
          offsetY: obj.y,
        ),
      ];
    } else if (obj.isPolyline && obj.polyline.isNotEmpty) {
      return [
        PolylineShape(
          points: obj.polyline.map((p) => Offset(p.x, p.y)).toList(),
          offsetX: obj.x,
          offsetY: obj.y,
        ),
      ];
    } else if (obj.isEllipse) {
      return [EllipseShape.fromBounds(obj.x, obj.y, obj.width, obj.height)];
    } else if (obj.isPoint) {
      return [PointShape(x: obj.x, y: obj.y)];
    } else {
      // Default to rectangle
      return [
        RectangleShape(
          x: obj.x,
          y: obj.y,
          width: obj.width,
          height: obj.height,
          rotation: obj.rotation,
        ),
      ];
    }
  }

  String _getDirectory(String path) {
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return path.substring(0, lastSlash + 1);
  }

  String _resolvePath(String basePath, String relativePath) {
    if (relativePath.startsWith('/')) {
      return relativePath;
    }
    return '$basePath$relativePath';
  }
}

/// [ParserProvider] that serves pre-loaded external tileset (TSX) content.
///
/// The provider is populated up-front with a map of `source` path (exactly as
/// written in the TMX, i.e. relative to the map file) to the TSX content.
/// Parsed [Parser]s are cached per-path so subsequent lookups reuse them.
class _FledgeTsxProvider implements ParserProvider {
  final Map<String, String> _contents;
  final Map<String, Parser> _parserCache = {};

  _FledgeTsxProvider(this._contents);

  @override
  bool canProvide(String path) => _contents.containsKey(path);

  @override
  Parser getSource(String path) {
    return _parserCache[path] ??= Parser.fromString(_contents[path]!);
  }
}
