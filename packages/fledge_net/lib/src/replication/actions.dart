import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:meta/meta.dart';

import '../protocol/packet.dart';
import 'codec.dart';

/// What a player sent with `NetworkSession.sendAction`: its sequence number
/// and the tick it was sent at.
class NetActionTicket {
  /// Per-sender sequence number (from 1; never reused in a session).
  final int seq;

  /// The sender's tick when it sent the action (server-tick space).
  final int tick;

  const NetActionTicket(this.seq, this.tick);

  @override
  String toString() => 'NetActionTicket(seq: $seq, tick: $tick)';
}

/// One player action delivered to the host this tick.
class NetAction<T> {
  /// The sender (`0` = the host itself).
  final int peerId;

  /// The sender's sequence number for this action.
  final int seq;

  /// The tick the sender sent it at.
  final int tick;

  /// The action.
  final T value;

  /// Network id of the entity it targets (`0` = none).
  final int targetNetId;

  /// Local entity for [targetNetId], if any. The host has already checked
  /// that the sender owns it.
  final Entity? target;

  const NetAction({
    required this.peerId,
    required this.seq,
    required this.tick,
    required this.value,
    this.targetNetId = 0,
    this.target,
  });
}

/// Resource (host): the actions of type [T] to apply **this fixed tick**,
/// rebuilt every fixed step by `NetInputSystem`.
///
/// Every action appears in exactly one tick, in each sender's order: a
/// client's action is held until the host reaches the tick it was sent
/// at, so it lands on the same tick as the inputs sent with it. Apply
/// them in `Schedules.fixedUpdate` (or any system after
/// `NetInputSystem.systemName`) and decide each with
/// `NetworkSession.resolveAction`; an action not resolved by the end of
/// the tick counts as accepted. Always empty on clients.
class NetActions<T> {
  int _tick = 0;
  final List<NetAction<T>> _entries = [];

  /// Tick the current [entries] belong to.
  int get tick => _tick;

  /// This tick's actions, ordered by sender, then sequence number.
  List<NetAction<T>> get entries => List.unmodifiable(_entries);

  /// Whether there are no actions this tick.
  bool get isEmpty => _entries.isEmpty;

  /// Replace the contents (used by the replication systems).
  void replace(int tick, Iterable<NetAction<T>> entries) {
    _tick = tick;
    _entries
      ..clear()
      ..addAll(entries);
  }
}

/// An action this instance sent that the host's state does not reflect
/// yet (see `NetworkSession.pendingActions`).
class NetPendingAction<T> {
  /// Its sequence number.
  final int seq;

  /// The tick it was sent at.
  final int tick;

  /// The action.
  final T value;

  /// The entity it targets, if any.
  final Entity? target;

  /// `true` once the host accepted it (its state is on the way).
  final bool accepted;

  const NetPendingAction({
    required this.seq,
    required this.tick,
    required this.value,
    this.target,
    this.accepted = false,
  });
}

/// The host decided an action this instance sent. Fired once per action.
class NetActionResolved<T> {
  /// The action's sequence number.
  final int seq;

  /// The tick it was sent at.
  final int tick;

  /// The action.
  final T value;

  /// Whether the host accepted it.
  final bool accepted;

  /// The host's reason, if it gave one (typically for a rejection).
  final String? reason;

  /// Host tick the action was resolved at.
  final int resolvedTick;

  const NetActionResolved({
    required this.seq,
    required this.tick,
    required this.value,
    required this.accepted,
    required this.resolvedTick,
    this.reason,
  });
}

/// Type-erased action registration.
@internal
class ActionReplicator<T> {
  final int index;
  final String key;
  final NetCodec<T> codec;

  ActionReplicator({
    required this.index,
    required this.key,
    required this.codec,
  });

  Type get type => T;
  Type get actionsType => NetActions<T>;
  Type get resolvedType => NetActionResolved<T>;

  void register(App app) {
    app
      ..insertResource(NetActions<T>())
      ..addEvent<NetActionResolved<T>>();
  }

  Uint8List encode(Object? value) {
    final out = PacketBuilder();
    codec.encode(value as T, out);
    return out.build();
  }

  Object? decode(Uint8List bytes) => codec.decode(PacketReader(bytes));

  NetAction<T> action(
    int peerId,
    int seq,
    int tick,
    Object? value,
    int targetNetId,
    Entity? target,
  ) => NetAction<T>(
    peerId: peerId,
    seq: seq,
    tick: tick,
    value: value as T,
    targetNetId: targetNetId,
    target: target,
  );

  NetPendingAction<T> pending(
    int seq,
    int tick,
    Object? value,
    Entity? target, {
    required bool accepted,
  }) => NetPendingAction<T>(
    seq: seq,
    tick: tick,
    value: value as T,
    target: target,
    accepted: accepted,
  );

  /// Publish this tick's [actions] (all of this type).
  void publish(World world, int tick, Iterable<NetAction<Object?>> actions) {
    world.getResource<NetActions<T>>()?.replace(tick, actions.cast());
  }

  void emitResolved(
    World world,
    int seq,
    int tick,
    Object? value, {
    required bool accepted,
    required int resolvedTick,
    String? reason,
  }) {
    if (!world.events.isRegistered<NetActionResolved<T>>()) return;
    world.eventWriter<NetActionResolved<T>>().send(
      NetActionResolved<T>(
        seq: seq,
        tick: tick,
        value: value as T,
        accepted: accepted,
        resolvedTick: resolvedTick,
        reason: reason,
      ),
    );
  }
}

/// An action one instance sent and the host has not finished with.
@internal
class OutstandingAction {
  final int index;
  final int seq;
  final int tick;
  final Object? value;
  final Entity? target;

  /// Set when the host accepted it: the tick it did.
  int? acceptedAt;

  OutstandingAction(this.index, this.seq, this.tick, this.value, this.target);
}
