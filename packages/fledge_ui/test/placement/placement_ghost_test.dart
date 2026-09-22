import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter_test/flutter_test.dart';

// The ghost preview (core PlacementGhostSystem, postUpdate): one
// world-space Sprite entity at the preview tile, tinted for validity,
// gone when placement ends. Fledge-only test — no Porios context.

const TextureHandle _texture = TextureHandle(id: 42, width: 16, height: 16);

/// x/y as tile x/y * 16 (arbitrary — pixel-space tile size).
(double, double) _tileToWorld(PlacementTile tile) =>
    (tile.x * 16.0, tile.y * 16.0);

Sprite? _spriteFor(World world, String key) => Sprite(texture: _texture);

class _EvenTilesOnly extends PlacementValidator {
  @override
  bool isValid(World world, String key, PlacementTile tile) => tile.x.isEven;
}

class _Harness {
  final App app = App();

  _Harness() {
    app.addPlugin(
      PlacementCorePlugin(
        validator: _EvenTilesOnly(),
        ghost: const PlacementGhostConfig(
          tileToWorld: _tileToWorld,
          ghostSpriteFor: _spriteFor,
        ),
      ),
    );
  }

  World get world => app.world;
  PlacementState get state => world.getResource<PlacementState>()!;

  void send<T>(T event) => world.eventWriter<T>().send(event);

  Future<void> tick() async {
    world.updateEvents();
    await app.scheduler.runSchedule(Schedules.update, world);
    await app.scheduler.runSchedule(Schedules.postUpdate, world);
    world.updateEvents();
  }

  Future<void> ticks(int n) async {
    for (var i = 0; i < n; i++) {
      await tick();
    }
  }

  List<(Entity, PlacementGhost)> get ghosts => [
    for (final (entity, ghost) in world.query1<PlacementGhost>().iter())
      (entity, ghost),
  ];
}

void main() {
  late _Harness h;
  late Color validColor;
  late Color invalidColor;
  setUp(() {
    h = _Harness();
    final config = h.world.getResource<PlacementGhostConfig>()!;
    validColor = config.validColor;
    invalidColor = config.invalidColor;
  });

  test('no ghost until placing', () async {
    await h.ticks(2);
    expect(h.ghosts, isEmpty);
  });

  test('the ghost sits on the preview tile, tinted valid', () async {
    h
      ..send(const PlacementEnterRequested('chair'))
      ..send(const PlacementPreviewRequested('room', 2, 3));
    await h.tick();
    final (entity, ghost) = h.ghosts.single;
    expect(ghost.key, 'chair');
    expect(ghost.tile, const PlacementTile('room', 2, 3));
    expect(ghost.isValid, isTrue);
    final t = h.world.get<Transform2D>(entity)!;
    expect(t.translation.x, 32.0);
    expect(t.translation.y, 48.0);
    final sprite = h.world.get<Sprite>(entity)!;
    expect(sprite.texture, _texture);
    expect(sprite.color, validColor);
  });

  test('the ghost follows the tile and turns invalid-tinted on a '
      'refused tile', () async {
    h
      ..send(const PlacementEnterRequested('chair'))
      ..send(const PlacementPreviewRequested('room', 2, 3));
    await h.tick();
    expect(h.ghosts.single.$2.isValid, isTrue);

    h.send(const PlacementPreviewRequested('room', 3, 3)); // odd = invalid
    await h.tick();
    final (entity, ghost) = h.ghosts.single;
    expect(ghost.tile, const PlacementTile('room', 3, 3));
    expect(ghost.isValid, isFalse);
    expect(h.world.get<Sprite>(entity)!.color, invalidColor);

    h.send(const PlacementPreviewRequested('room', 4, 3)); // even again
    await h.tick();
    expect(h.ghosts.single.$2.isValid, isTrue);
    expect(h.world.get<Sprite>(entity)!.color, validColor);
  });

  test('the ghost is removed on confirm and on cancel', () async {
    h
      ..send(const PlacementEnterRequested('chair'))
      ..send(const PlacementPreviewRequested('room', 2, 3));
    await h.tick();
    expect(h.ghosts, hasLength(1));

    h.send(const PlacementCancelRequested());
    await h.tick();
    expect(h.ghosts, isEmpty);
    expect(h.state.isPlacing, isFalse);

    h
      ..send(const PlacementEnterRequested('lamp'))
      ..send(const PlacementPreviewRequested('room', 0, 0));
    await h.tick();
    expect(h.ghosts, hasLength(1));
    h.send(const PlacementConfirmRequested());
    await h.tick();
    expect(h.ghosts, isEmpty);
    expect(h.state.isPlacing, isFalse);
  });

  test('changing placeable rebuilds the ghost', () async {
    h
      ..send(const PlacementEnterRequested('chair'))
      ..send(const PlacementPreviewRequested('room', 2, 3));
    await h.tick();
    final firstEntity = h.ghosts.single.$1;

    // Enter with a new key and re-provide a preview tile in the same tick.
    h
      ..send(const PlacementEnterRequested('lamp'))
      ..send(const PlacementPreviewRequested('room', 2, 3));
    await h.tick();
    expect(h.ghosts, hasLength(1));
    final rebuilt = h.ghosts.single;
    expect(rebuilt.$2.key, 'lamp');
    expect(rebuilt.$1, isNot(firstEntity));
  });
}
