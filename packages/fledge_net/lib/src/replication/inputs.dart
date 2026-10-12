import 'dart:collection';

import 'package:fledge_ecs/fledge_ecs.dart';

/// One input of type [I] for one entity at one tick.
class NetInputEntry<I> {
  /// Peer that owns [entity] and produced the input (`0` = host).
  final int peerId;

  /// The controlled entity.
  final Entity entity;

  /// Network id of [entity].
  final int netId;

  /// Tick the input belongs to.
  final int tick;

  /// The input.
  final I input;

  /// `true` when the real input for [tick] had not arrived in time and the
  /// previous input was repeated instead.
  final bool repeated;

  const NetInputEntry({
    required this.peerId,
    required this.entity,
    required this.netId,
    required this.tick,
    required this.input,
    this.repeated = false,
  });
}

/// Resource: the inputs to simulate **this fixed tick**, one per
/// controlled entity, rebuilt every fixed step by `NetInputSystem`.
///
/// - **Host**: every validated client input for the current tick plus the
///   host's own [NetLocalInputs] submissions (peer `0`). Remote inputs
///   that are missing or late repeat the previous one (up to
///   `NetworkConfig.maxInputRepeatTicks`).
/// - **Client**: this client's own inputs for its (leading) local tick,
///   i.e. what the prediction step consumes.
///
/// Read it from systems that run after `NetInputSystem.systemName`
/// (in `Schedules.fixedPreUpdate` or later in the fixed chain).
class NetInputs<I> {
  int _tick = 0;
  final List<NetInputEntry<I>> _entries = [];
  final Map<Entity, NetInputEntry<I>> _byEntity = {};

  /// Tick the current [entries] belong to.
  int get tick => _tick;

  /// All inputs for [tick].
  List<NetInputEntry<I>> get entries => List.unmodifiable(_entries);

  /// The input for [entity] this tick, if any.
  NetInputEntry<I>? forEntity(Entity entity) => _byEntity[entity];

  /// Inputs produced by [peerId] this tick.
  Iterable<NetInputEntry<I>> forPeer(int peerId) =>
      _entries.where((e) => e.peerId == peerId);

  /// Replace the contents (used by the replication systems).
  void replace(int tick, Iterable<NetInputEntry<I>> entries) {
    _tick = tick;
    _entries
      ..clear()
      ..addAll(entries);
    _byEntity
      ..clear()
      ..addEntries(_entries.map((e) => MapEntry(e.entity, e)));
  }
}

/// Resource: inputs produced **locally** for entities this instance owns.
///
/// Call [submit] once per fixed tick per controlled entity from a system
/// in `Schedules.fixedPreUpdate` with `sets: [NetSets.localInput]` (the
/// plugin orders that set before `NetInputSystem`). A client sends the
/// input to the host (redundantly, until acknowledged) and feeds it to
/// prediction; the host uses it directly. Ticks without a submission
/// repeat the previous input (up to `NetworkConfig.maxInputRepeatTicks`).
///
/// Submissions for entities this instance does not own are ignored.
class NetLocalInputs<I> {
  final Map<Entity, I> _pending = {};

  /// Submit [input] for [entity] for the current tick.
  void submit(Entity entity, I input) => _pending[entity] = input;

  /// The submission for [entity] this tick, if any.
  I? pendingFor(Entity entity) => _pending[entity];

  /// Entities with a submission this tick.
  Iterable<Entity> get entities => _pending.keys;

  /// Remove and return this tick's submissions (used by the systems).
  Map<Entity, I> take() {
    final out = Map<Entity, I>.of(_pending);
    _pending.clear();
    return out;
  }
}

/// Per-tick input buffer for one controlled entity on the host (the
/// replication layer keeps one per peer and entity).
///
/// Inputs arrive redundantly and out of order; [add] keeps the first copy
/// of each tick. [take] hands out exactly one input per tick: the real one
/// if it arrived, otherwise the previous input repeated (at most
/// `maxRepeat` times in a row). Inputs for ticks that were already
/// simulated are dropped; if such a tick had been filled by a repeat it
/// counts as [lateCount].
class TickInputQueue<I> {
  final SplayTreeMap<int, I> _pending = SplayTreeMap();
  final Set<int> _repeatedTicks = {};
  final Queue<int> _repeatedOrder = Queue();

  /// Last tick handed out by [take] (`0` before the first).
  int lastConsumedTick = 0;

  /// Real inputs that arrived after their tick was simulated with a
  /// repeated input.
  int lateCount = 0;

  I? _last;
  int _repeats = 0;

  /// Buffered inputs not yet consumed.
  int get length => _pending.length;

  /// Buffer [input] for [tick]. Returns `false` if it was dropped (stale,
  /// duplicate, or more than [maxAhead] ticks after [currentTick]).
  bool add(int tick, I input, {required int currentTick, int maxAhead = 128}) {
    if (tick <= lastConsumedTick) {
      if (_repeatedTicks.remove(tick)) lateCount++;
      return false;
    }
    if (tick > currentTick + maxAhead) return false;
    if (_pending.containsKey(tick)) return false;
    _pending[tick] = input;
    return true;
  }

  /// The input to simulate at [tick], or `null` if there is none (no
  /// input ever received, or the repeat budget is exhausted).
  ({I input, bool repeated})? take(int tick, {int maxRepeat = 8}) {
    while (_pending.isNotEmpty && _pending.firstKey()! < tick) {
      _pending.remove(_pending.firstKey());
    }
    final real = _pending.remove(tick);
    if (real != null) {
      _last = real;
      _repeats = 0;
      lastConsumedTick = tick;
      return (input: real, repeated: false);
    }
    final last = _last;
    if (last == null || _repeats >= maxRepeat) return null;
    _repeats++;
    lastConsumedTick = tick;
    _repeatedTicks.add(tick);
    _repeatedOrder.addLast(tick);
    while (_repeatedOrder.length > 256) {
      _repeatedTicks.remove(_repeatedOrder.removeFirst());
    }
    return (input: last, repeated: true);
  }
}
