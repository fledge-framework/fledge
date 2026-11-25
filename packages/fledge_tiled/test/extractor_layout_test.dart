import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled/tiled.dart' as tiled;

/// One 16 px-grid map with one layer holding [tiles], drawn from [tileset].
World _world(
  LoadedTileset tileset,
  List<TileData> tiles, {
  Offset parallax = const Offset(1, 1),
  int size = 8,
}) {
  final world = World();
  final loaded = LoadedTilemap(
    map: tiled.TiledMap(
      width: size,
      height: size,
      tileWidth: 16,
      tileHeight: 16,
    ),
    tilesets: [tileset],
    animations: const {},
    sourcePath: 'map.tmx',
  );
  // ignore: deprecated_member_use_from_same_package
  world.insertResource(TilemapAssets()..put('map', loaded));
  final map = world.spawn()
    ..insert(Tilemap.fromTiledMap(loaded.map))
    ..insert(GlobalTransform2D.identity());
  world
      .spawnChild(map.entity)
      .insert(
        TileLayer(
          name: 'layer',
          layerIndex: 0,
          tiledLayer: tiled.TileLayer(name: 'layer', width: size, height: size),
          tiles: tiles,
          parallax: parallax,
        ),
      );
  return world;
}

LoadedTileset _atlasTileset({
  int tileWidth = 16,
  int tileHeight = 16,
  Offset tileOffset = Offset.zero,
  Map<int, Rect> ySortSpans = const {},
}) => LoadedTileset(
  source: 'atlas.tsx',
  name: 'atlas',
  firstGid: 1,
  tileWidth: tileWidth,
  tileHeight: tileHeight,
  columns: 1,
  tileCount: 1,
  atlas: TextureAtlas.grid(
    texture: TextureHandle(id: 2, width: tileWidth, height: tileHeight),
    columns: 1,
    rows: 1,
  ),
  tileOffset: tileOffset,
  ySortSpans: ySortSpans,
);

const _tile = TileData(gid: 1, x: 2, y: 3, localId: 0, tilesetIndex: 0);

List<ExtractedSprite> _extract(World world) {
  final renderWorld = RenderWorld();
  TilemapExtractor().extract(world, renderWorld);
  return renderWorld.extractedSprites.toList();
}

/// Centre of [sprite]'s box in the world.
(double, double) _centre(ExtractedSprite sprite) =>
    (sprite.transform.storage[6], sprite.transform.storage[7]);

void main() {
  test('a parallax layer is shifted by camera * (1 - p), not scaled', () {
    final world = _world(
      _atlasTileset(),
      [_tile],
      parallax: const Offset(0.5, 0.5),
    )..insertResource(ActiveCameraView(x: 100, y: 40));
    // Cell (2, 3) centre is (40, 56); shift is (100, 40) * 0.5 = (50, 20).
    expect(_centre(_extract(world).single), (90.0, 76.0));
  });

  test('without a camera a parallax layer is drawn where it is', () {
    final world = _world(_atlasTileset(), [
      _tile,
    ], parallax: const Offset(0.5, 0.5));
    expect(_centre(_extract(world).single), (40.0, 56.0));
  });

  test('parallax sprites follow the camera across frames', () {
    final camera = ActiveCameraView(x: 0, y: 0);
    final world = _world(_atlasTileset(), [_tile], parallax: const Offset(0, 1))
      ..insertResource(camera);
    final extractor = TilemapExtractor();
    ExtractedSprite once() {
      final rw = RenderWorld();
      extractor.extract(world, rw);
      return rw.extractedSprites.single;
    }

    expect(_centre(once()).$1, 40);
    camera.x = 200; // a factor-0 layer stays put on screen: moves with it
    expect(_centre(once()).$1, 240);
  });

  test('a parallax layer is culled where it is drawn, not where it lies', () {
    // The tile lies at x 32..48 but a factor-0 layer is drawn shifted by
    // the camera's x: it's on screen around x 1032.
    final world = _world(_atlasTileset(), [_tile], parallax: const Offset(0, 1))
      ..insertResource(
        ActiveCameraView(x: 1000, y: 56)..viewportSize = const Size(200, 200),
      );
    expect(_extract(world), hasLength(1));
  });

  test('image-collection tiles draw from their own texture and size', () {
    const own = TextureHandle(id: 7, width: 24, height: 40);
    final tileset = LoadedTileset(
      source: 'props.tsx',
      name: 'props',
      firstGid: 1,
      tileWidth: 24,
      tileHeight: 40,
      columns: 1,
      tileCount: 1,
      atlas: TextureAtlas.grid(
        texture: kNoTilesetImageTexture,
        columns: 1,
        rows: 1,
      ),
      tileImages: const {0: own},
    );
    final sprite = _extract(_world(tileset, [_tile])).single;
    expect(sprite.texture, own);
    expect(sprite.sourceRect, const Rect.fromLTWH(0, 0, 24, 40));
    expect((sprite.size.x, sprite.size.y), (24.0, 40.0));
    expect(kNoTilesetImageTexture.id, isNot(kSolidColorTextureId));
  });

  test("the tileset's tile offset moves every tile", () {
    final sprite = _extract(
      _world(_atlasTileset(tileOffset: const Offset(3, -5)), [_tile]),
    ).single;
    expect(_centre(sprite), (43.0, 51.0));
  });

  test("a tall y-sorted tile sorts at its line, measured from the image's "
      'top', () {
    // A 16x48 pillar on a 16 px grid, sorting at its base (line 48 in its
    // own pixels). Cell (2, 3)'s bottom edge is y 64, so the line is 64.
    final sprite = _extract(
      _world(
        _atlasTileset(
          tileHeight: 48,
          ySortSpans: {0: const Rect.fromLTWH(0, 32, 16, 16)},
        ),
        [_tile],
      ),
    ).single;
    expect(sprite.preciseSubOrder, 64 * DrawLayerExtension.ySortScale);
  });

  test('a tall tile just below the view is still extracted', () {
    // A 16x96 tile in row 10 (cell y 160..176) reaches up to y 80; a view
    // ending at y 100 shows its top.
    final world = _world(_atlasTileset(tileHeight: 96), const [
      TileData(gid: 1, x: 2, y: 10, localId: 0, tilesetIndex: 0),
    ], size: 16);
    final extractor = TilemapExtractor(cullMargin: 0);
    world.insertResource(
      ActiveCameraView(x: 40, y: 50)..viewportSize = const Size(100, 100),
    );
    final rw = RenderWorld();
    extractor.extract(world, rw);
    expect(rw.extractedSprites, hasLength(1));
  });
}
