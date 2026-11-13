import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// `SpriteBatchSystem` used to group sprites by texture across the
/// whole frame, so a texture-A sprite that should cover a texture-B
/// sprite was drawn underneath it. It now batches contiguous
/// same-texture runs in draw order, like `renderSpritesToDrawer`.

const _texA = TextureHandle(id: 1, width: 16, height: 16);
const _texB = TextureHandle(id: 2, width: 16, height: 16);

void _spawnYSorted(
  World world,
  RenderWorld renderWorld,
  TextureHandle texture,
  double y,
) {
  world.spawn()
    ..insert(Sprite(texture: texture, color: Color(0xFF000000 | y.toInt())))
    ..insert(
      GlobalTransform2D(Transform2D(translation: Vector2(0, y)).toMatrix()),
    );
}

Future<SpriteBatches> _batch(World world, RenderWorld renderWorld) async {
  SpriteExtractor().extract(world, renderWorld);
  await SpriteBatchSystem().run(world, renderWorld);
  return renderWorld.getResource<SpriteBatches>()!;
}

List<int> _drawOrderYs(SpriteBatches batches) => [
  for (final b in batches.all)
    for (final i in b.instances) i.color.toARGB32() & 0xFFFFFF,
];

void main() {
  test('interleaved textures A, B, A by y keep their draw order', () async {
    final world = World();
    final renderWorld = RenderWorld();
    // Spawned out of order so extraction order can't mask the sort.
    _spawnYSorted(world, renderWorld, _texA, 300);
    _spawnYSorted(world, renderWorld, _texA, 100);
    _spawnYSorted(world, renderWorld, _texB, 200);

    final batches = await _batch(world, renderWorld);
    expect(batches.all.map((b) => b.texture.id), [1, 2, 1]);
    expect(batches.batchCount, 3);
    expect(batches.totalSprites, 3);
    expect(_drawOrderYs(batches), [100, 200, 300]);
  });

  test('all sprites on one texture stay one batch, in y order', () async {
    final world = World();
    final renderWorld = RenderWorld();
    for (final y in [50.0, 10.0, 40.0, 20.0, 30.0]) {
      _spawnYSorted(world, renderWorld, _texA, y);
    }

    final batches = await _batch(world, renderWorld);
    expect(batches.batchCount, 1);
    expect(batches.all.single.texture.id, 1);
    expect(_drawOrderYs(batches), [10, 20, 30, 40, 50]);
  });

  test('textures already separated by sort order merge per run', () async {
    final world = World();
    final renderWorld = RenderWorld();
    for (final y in [10.0, 20.0, 30.0]) {
      _spawnYSorted(world, renderWorld, _texA, y);
    }
    for (final y in [40.0, 50.0]) {
      _spawnYSorted(world, renderWorld, _texB, y);
    }

    final batches = await _batch(world, renderWorld);
    expect(batches.all.map((b) => b.texture.id), [1, 2]);
    expect(batches.all.map((b) => b.length), [3, 2]);
    expect(_drawOrderYs(batches), [10, 20, 30, 40, 50]);
  });

  test('SpriteRenderNode submits batches in draw order', () async {
    final world = World();
    final renderWorld = RenderWorld();
    _spawnYSorted(world, renderWorld, _texA, 100);
    _spawnYSorted(world, renderWorld, _texB, 200);
    _spawnYSorted(world, renderWorld, _texA, 300);
    await _batch(world, renderWorld);

    final drawer = _RecordingDrawer();
    final graph = RenderGraph()..addNode(SpriteRenderNode());
    graph.execute(
      SpriteRenderContext(renderWorld: renderWorld, drawer: drawer),
    );
    expect(drawer.calls, [(1, 1), (2, 1), (1, 1)]);
  });
}

class _RecordingDrawer implements SpriteDrawer {
  final calls = <(int, int)>[];

  @override
  void drawSpriteBatch(TextureHandle texture, List<BackendSpriteData> batch) {
    calls.add((texture.id, batch.length));
  }
}
