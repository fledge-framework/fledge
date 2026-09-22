import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter_test/flutter_test.dart';

// The generic placement core on a bare fledge App: the state machine,
// the validator hook, the notifications and the registry.

/// Valid everywhere except x < 0 ("off the board").
class _Validator extends PlacementValidator {
  int calls = 0;

  @override
  bool isValid(World world, String key, PlacementTile tile) {
    calls++;
    return tile.x >= 0;
  }

  @override
  String? refusalReason(World world, String key, PlacementTile tile) =>
      'off the board';
}

class _Harness {
  final App app = App();
  final _Validator validator = _Validator();
  final List<Object> events = [];

  _Harness() {
    app.addPlugin(PlacementCorePlugin(validator: validator));
  }

  World get world => app.world;
  PlacementState get state => world.getResource<PlacementState>()!;

  void send<T>(T event) => world.eventWriter<T>().send(event);

  /// One update (after swapping the event buffers), then collects the
  /// notifications sent.
  Future<void> tick() async {
    world.updateEvents();
    await app.scheduler.runSchedule(Schedules.update, world);
    world.updateEvents();
    events
      ..addAll(world.eventReader<PlacementEntered>().read())
      ..addAll(world.eventReader<PlacementPreviewMoved>().read())
      ..addAll(world.eventReader<PlacementConfirmed>().read())
      ..addAll(world.eventReader<PlacementCancelled>().read());
  }
}

void main() {
  late _Harness h;
  setUp(() => h = _Harness());

  test('idle until entered; enter + preview in one tick previews', () async {
    await h.tick();
    expect(h.state.mode, PlacementMode.idle);
    expect(h.validator.calls, 0, reason: 'idle costs nothing');

    h
      ..send(const PlacementEnterRequested('chair'))
      ..send(const PlacementPreviewRequested('room', 2, 3));
    await h.tick();
    expect(h.state.mode, PlacementMode.previewing);
    expect(h.state.placeableKey, 'chair');
    expect(h.state.previewTile, const PlacementTile('room', 2, 3));
    expect(h.events.map((e) => e.runtimeType), [
      PlacementEntered,
      PlacementPreviewMoved,
    ]);
  });

  test('an invalid tile: mode invalid + the reason; confirm is ignored; '
      'the tile is re-validated every tick', () async {
    h
      ..send(const PlacementEnterRequested('chair'))
      ..send(const PlacementPreviewRequested('room', -1, 0));
    await h.tick();
    expect(h.state.mode, PlacementMode.invalid);
    expect(h.state.refusalReason, 'off the board');
    final moved = h.events.whereType<PlacementPreviewMoved>().single;
    expect(moved.isValid, isFalse);
    expect(moved.reason, 'off the board');

    h.send(const PlacementConfirmRequested());
    await h.tick();
    expect(h.state.isPlacing, isTrue);
    expect(h.events.whereType<PlacementConfirmed>(), isEmpty);

    final calls = h.validator.calls;
    await h.tick();
    expect(h.validator.calls, calls + 1);
    expect(
      h.events.whereType<PlacementPreviewMoved>(),
      hasLength(1),
      reason: 'nothing changed: no new notification',
    );
  });

  test('confirm on a valid tile: PlacementConfirmed(key, tile), back to '
      'idle', () async {
    h
      ..send(const PlacementEnterRequested('chair'))
      ..send(const PlacementPreviewRequested('room', 1, 1));
    await h.tick();
    h.send(const PlacementConfirmRequested());
    await h.tick();
    final confirmed = h.events.whereType<PlacementConfirmed>().single;
    expect(confirmed.key, 'chair');
    expect(confirmed.tile, const PlacementTile('room', 1, 1));
    expect(h.state.mode, PlacementMode.idle);
    expect(h.state.previewTile, isNull);
  });

  test('cancel; entering another key cancels the first; re-entering the '
      'same key is a no-op', () async {
    h.send(const PlacementEnterRequested('chair'));
    await h.tick();
    h.send(const PlacementEnterRequested('chair'));
    await h.tick();
    expect(h.events.whereType<PlacementEntered>(), hasLength(1));

    h.send(const PlacementEnterRequested('lamp'));
    await h.tick();
    expect(h.state.placeableKey, 'lamp');
    expect(h.events.whereType<PlacementCancelled>().single.key, 'chair');

    h.send(const PlacementCancelRequested());
    await h.tick();
    expect(h.state.isPlacing, isFalse);
    expect(h.events.whereType<PlacementCancelled>().map((c) => c.key), [
      'chair',
      'lamp',
    ]);

    // Requests while idle (other than enter) do nothing.
    h
      ..send(const PlacementConfirmRequested())
      ..send(const PlacementPreviewRequested('room', 0, 0));
    await h.tick();
    expect(h.state.isPlacing, isFalse);
  });

  group('PlacedEntityRegistry', () {
    test('deterministic ids from a settable counter; per-map queries in '
        'registration order', () {
      final registry = PlacedEntityRegistry<_Record>();
      expect(registry.allocateId('chair'), 'chair_1');
      expect(registry.allocateId('lamp'), 'lamp_2');
      registry
        ..register(const _Record('chair_1', 'room'))
        ..register(const _Record('lamp_2', 'hall'))
        ..register(const _Record('x', 'room'));
      expect(registry.recordsOn('room').map((r) => r.id), ['chair_1', 'x']);
      expect(registry.get('lamp_2')?.mapKey, 'hall');
      expect(registry.remove('x')?.id, 'x');
      expect(registry.contains('x'), isFalse);

      registry.nextId = 40;
      expect(registry.allocateId('chair'), 'chair_40');
      registry.nextId = -3;
      expect(registry.nextId, 1);
    });
  });
}

class _Record implements PlacedRecord {
  @override
  final String id;
  @override
  final String mapKey;

  const _Record(this.id, this.mapKey);
}
