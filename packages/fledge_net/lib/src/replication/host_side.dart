part of 'session.dart';

enum _InboundKind { connect, disconnect, data }

class _HostInbound {
  final _InboundKind kind;
  final int peerId;
  final PacketType? type;
  final Uint8List? data;
  final String? reason;

  _HostInbound(this.kind, this.peerId, {this.type, this.data, this.reason});
}

class _HostPeer {
  final int id;

  /// The identity the client presented (empty or anonymous if none).
  String identity = '';

  /// Clients only send RPCs, so a small out-of-order window suffices and
  /// bounds what a misbehaving client can make the host buffer.
  final ReliableChannel channel = ReliableChannel(maxReceiveWindow: 256);

  /// Resource chunks to this client (it never sends on this channel).
  final ReliableChannel bulk = ReliableChannel(maxReceiveWindow: 1);

  /// Per resource index: the chunk versions last queued for this client,
  /// and how many chunks the resource had then.
  final Map<int, List<int?>> resourceVersions = {};

  /// Next snapshot chunk sequence number.
  int nextChunkSeq = 1;

  /// Bytes this client may still be sent (refilled every tick from
  /// `sendBudgetBytesPerSecond`; may dip below zero, as a started packet
  /// always goes).
  double allowance = 0;

  /// Where the next snapshot starts in the relevant entities, so a budget
  /// too small for all of them still gets to each in turn.
  int snapshotCursor = 0;

  /// What this client is known to have, per entity (acknowledged).
  final Map<int, _Baseline> baselines = {};

  /// Snapshot chunks in flight: what each carried, by chunkSeq.
  final SplayTreeMap<int, List<_SentEntity>> inFlight = SplayTreeMap();

  /// Actions received from this client and not yet released, in order.
  final ListQueue<_InAction> actions = ListQueue();

  /// The client's last action sequence number.
  int lastActionSeq = 0;

  /// Resolution messages waiting to go on the bulk channel (after the
  /// resource chunks they may depend on).
  final List<Uint8List> resolutions = [];

  /// Net ids currently spawned on this client.
  final Set<int> relevant = {};
  final SplayTreeMap<int, TickInputQueue<Uint8List>> inputs = SplayTreeMap();
  int lastProcessedInputTick = 0;
  int lateInputs = 0;

  /// The send channel hit `ReliableChannel.maxUnacked` and dropped a
  /// message: the ordered stream is broken, so the peer is disconnected.
  bool overflowed = false;
  bool kicked = false;

  _HostPeer(this.id);
}

/// An entity as a client is known to have it: each component's version and
/// which components exist, as of the newest acknowledged snapshot.
class _Baseline {
  _Baseline(this.presentMask, this.versions, this.maskSeq);

  int presentMask;
  final Map<int, int> versions;

  /// The chunkSeq [presentMask] came from (spawns count as acknowledged).
  int maskSeq;
}

/// One entity's entry in a snapshot chunk: what it told the client.
class _SentEntity {
  _SentEntity(this.netId, this.presentMask, this.versions);

  final int netId;
  final int presentMask;
  final Map<int, int> versions;
}

class _HostEntity {
  final int netId;
  final Entity entity;
  bool isNew = true;

  /// Each component's last encoded bytes, and a version bumped whenever
  /// they change.
  final Map<int, Uint8List> componentBytes = {};
  final Map<int, int> componentVersions = {};
  int sentParent = 0;
  int sentOwner = 0;

  /// Encoded state exceeds `NetworkSession.maxEntityStateBytes`: not
  /// replicated (despawned on clients) until it fits again.
  bool oversized = false;

  // Refreshed every send pass.
  int parent = 0;
  int owner = 0;
  bool alwaysRelevant = false;
  bool ownerOnly = false;
  bool hidden = false;
  (double, double)? position;
  int depth = 0;

  _HostEntity(this.netId, this.entity);
}

/// An action received (or sent by the host itself), not yet released.
class _InAction {
  final int index;
  final int seq;
  final int tick;
  final int targetNetId;
  final Entity? target;
  final Object? value;

  _InAction(
    this.index,
    this.seq,
    this.tick,
    this.value, {
    this.targetNetId = 0,
    this.target,
  });
}

class _OutRpc {
  final int index;
  final Uint8List bytes;
  final Entity? target;
  final int? to;
  final int? except;

  _OutRpc(this.index, this.bytes, this.target, this.to, this.except);
}

class _HostSide {
  final NetworkSession session;
  final NetworkHost host;
  final List<StreamSubscription<Object?>> _subs = [];
  final List<_HostInbound> _inbox = [];
  final List<ProtocolMismatchEvent> _mismatches = [];
  final SplayTreeMap<int, _HostPeer> _peers = SplayTreeMap();
  final SplayTreeMap<int, _HostEntity> _entities = SplayTreeMap();
  final List<_OutRpc> _rpcs = [];

  /// The host's own actions (peer 0): not yet released, and not yet
  /// resolved (by sequence number).
  final ListQueue<_InAction> _localActions = ListQueue();
  final SplayTreeMap<int, OutstandingAction> _localOutstanding = SplayTreeMap();
  int _localActionSeq = 0;

  /// Actions released this tick and not resolved yet, by (peer, seq).
  final Map<(int, int), _InAction> _unresolved = {};

  /// The host's own resolutions, reported by the next send pass.
  final List<(OutstandingAction, bool, String?, int)> _localResolved = [];

  /// The tick actions were last released at.
  int _actionTick = 0;

  final Map<Entity, Object?> _lastLocalInput = {};
  final Map<Entity, int> _localRepeats = {};
  List<RawInputEntry> _tickInputs = const [];

  /// Net ids already reported as oversized (logged once per entity).
  final Set<int> _reportedOversized = {};

  // Scratch builders reused by the send pass (build() copies).
  final PacketBuilder _stateOut = PacketBuilder();
  final PacketBuilder _entryOut = PacketBuilder();
  final PacketBuilder _messageOut = PacketBuilder();
  final PacketBuilder _chunkOut = PacketBuilder();

  _HostSide(this.session, this.host) {
    _subs
      ..add(
        host.onPeerConnected.listen(
          (e) => _inbox.add(_HostInbound(_InboundKind.connect, e.peer.id)),
        ),
      )
      ..add(
        host.onPeerDisconnected.listen(
          (e) => _inbox.add(
            _HostInbound(_InboundKind.disconnect, e.peer.id, reason: e.reason),
          ),
        ),
      )
      ..add(
        host.onData.listen(
          (e) => _inbox.add(
            _HostInbound(
              _InboundKind.data,
              e.peer.id,
              type: e.type,
              data: e.data,
            ),
          ),
        ),
      )
      ..add(host.onProtocolMismatch.listen(_mismatches.add));
  }

  NetworkConfig get _config => session.config;
  ReplicationRegistry get _registry => session.registry;

  List<int> sortedPeerIds() => _peers.keys.toList();

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void _send(int peerId, PacketType type, Uint8List payload) {
    NetworkSession._sendSafely(
      payload,
      () => host.sendTo(peerId, type, payload),
    );
  }

  // Pump ----------------------------------------------------------------------

  void pump(World world) {
    host.update();
    final tick = world.getResource<NetworkTick>()?.serverTick ?? 0;
    final keep = <_HostInbound>[];
    for (final item in _inbox) {
      if (item.kind == _InboundKind.connect) {
        _onConnect(world, item.peerId, tick);
      } else if (item.kind == _InboundKind.data &&
          item.type == PacketType.tickSync) {
        _answerTickSync(item, tick);
      } else {
        keep.add(item);
      }
    }
    _inbox
      ..clear()
      ..addAll(keep);
    for (final m in _mismatches) {
      NetworkSession._emit(world, NetProtocolMismatch(m));
    }
    _mismatches.clear();
    _flushChannels(bulk: false);
  }

  /// Entities kept for players who left, by identity, until they return
  /// (`OwnedEntityPolicy.holdForReturn`).
  final Map<String, List<int>> _held = {};

  /// The identity peer [peerId] presented, or empty.
  String identityOf(int peerId) => host.getPeer(peerId)?.identity ?? '';

  static bool _named(String identity) =>
      identity.isNotEmpty && identity != anonymousClientId;

  void _onConnect(World world, int peerId, int tick) {
    if (_peers.containsKey(peerId)) return;
    final peer = _HostPeer(peerId);
    _peers[peerId] = peer;
    final identity = identityOf(peerId);
    peer.identity = identity;
    // Back again: what they left behind is theirs once more.
    final returned = <int>[];
    for (final netId in _held.remove(identity) ?? const <int>[]) {
      final info = _entities[netId];
      if (info == null || !world.isAlive(info.entity)) continue;
      final net = world.get<NetworkIdentity>(info.entity);
      if (net == null || net.ownerId != 0) continue; // taken over meanwhile
      net.ownerId = peerId;
      returned.add(netId);
    }
    final welcome = PacketBuilder()
      ..writeByte(WireKind.welcome)
      ..writeVarUint(peerId)
      ..writeUint16(_config.tickRate)
      ..writeUint16(_config.syncRate)
      ..writeUint32(_registry.schemaHash)
      ..writeUint32(tick);
    _enqueue(peer, welcome.build());
    NetworkSession._emit(
      world,
      NetPeerConnected(
        peerId,
        identity: _named(identity) ? identity : '',
        returned: returned,
      ),
    );
  }

  void _answerTickSync(_HostInbound item, int tick) {
    if (!_peers.containsKey(item.peerId)) return;
    try {
      final r = PacketReader(item.data!);
      if (r.readByte() != TickSyncKind.request) return;
      final echoed = r.readUint32();
      final reply = PacketBuilder()
        ..writeByte(TickSyncKind.response)
        ..writeUint32(echoed)
        ..writeUint32(tick)
        ..writeUint16(_config.tickRate);
      _send(item.peerId, PacketType.tickSync, reply.build());
    } on RangeError {
      // Malformed: drop.
    }
  }

  /// Sends what's due on each client's control channel (or, with [bulk],
  /// its bulk channel), within its allowance; a channel left over goes on
  /// a later tick.
  void _flushChannels({required bool bulk}) {
    final now = session.clock.nowMs;
    for (final peer in _peers.values.toList()) {
      if (peer.overflowed) {
        // A peer that stops acknowledging fills its channel up to
        // ReliableChannel.maxUnacked. The disconnect event then applies
        // the owned-entity policy.
        if (!peer.kicked) {
          peer.kicked = true;
          unawaited(
            host
                .disconnectPeer(peer.id, 'Reliable channel overflow')
                .catchError((Object _) {}),
          );
        }
        continue;
      }
      if (peer.allowance <= 0) continue;
      final rtt = host.getPeer(peer.id)?.rtt ?? 0;
      final channel = bulk ? peer.bulk : peer.channel;
      final id = bulk ? ChannelId.bulk : ChannelId.control;
      for (final p in channel.takePackets(
        nowMs: now,
        resendAfterMs: session._resendAfterMs(rtt),
        ack: bulk ? 0 : peer.channel.receivedAck,
        maxBytes: peer.allowance.ceil(),
      )) {
        peer.allowance -= p.length + 1;
        _send(peer.id, PacketType.replication, _onChannelId(id, p));
      }
    }
  }

  // Receive -------------------------------------------------------------------

  void receive(World world) {
    final items = List<_HostInbound>.of(_inbox);
    _inbox.clear();
    final tick = world.getResource<NetworkTick>()?.serverTick ?? 0;
    for (final item in items) {
      switch (item.kind) {
        case _InboundKind.connect:
          _onConnect(world, item.peerId, tick);
        case _InboundKind.disconnect:
          _onDisconnect(world, item.peerId, item.reason ?? 'Disconnected');
        case _InboundKind.data:
          final peer = _peers[item.peerId];
          if (peer == null) continue;
          try {
            switch (item.type) {
              case PacketType.input:
                _onInput(world, peer, item.data!, tick);
              case PacketType.replication:
                _onChannel(world, peer, item.data!);
              case PacketType.tickSync:
                _answerTickSync(item, tick);
              default:
                break;
            }
          } on RangeError {
            // Truncated packet: drop.
          } on FormatException {
            // Malformed packet: drop.
          }
      }
    }
  }

  void _reject(
    World world,
    int peerId,
    NetRejectionKind kind,
    int netId,
    String reason,
  ) {
    final stats = session.stats;
    switch (kind) {
      case NetRejectionKind.input:
        stats.rejectedInputs++;
      case NetRejectionKind.rpc:
        stats.rejectedRpcs++;
      case NetRejectionKind.message:
        stats.rejectedMessages++;
      case NetRejectionKind.action:
        stats.rejectedActions++;
    }
    NetworkSession._emit(world, NetRejected(peerId, kind, netId, reason));
  }

  /// Authority check: does [peerId] own the entity with [netId]?
  ({Entity? entity, bool owned}) _ownedBy(World world, int netId, int peerId) {
    final entity = world.getResource<NetworkEntityRegistry>()?.getEntity(netId);
    if (entity == null || !world.isAlive(entity)) {
      return (entity: null, owned: false);
    }
    final identity = world.get<NetworkIdentity>(entity);
    return (entity: entity, owned: identity?.ownerId == peerId);
  }

  void _onInput(World world, _HostPeer peer, Uint8List data, int tick) {
    final packet = InputPacket.decode(data);
    peer.channel.onAck(packet.reliableAck);
    peer.bulk.onAck(packet.bulkAck);
    _onChunkAcks(peer, packet.chunkAck, packet.chunkAckBits);
    for (final action in packet.actions) {
      _onAction(world, peer, action);
    }
    if (packet.streams.isEmpty) return;
    if (_registry.inputReplicator == null) {
      _reject(world, peer.id, NetRejectionKind.message, 0, 'no input type');
      return;
    }
    for (final stream in packet.streams) {
      final check = _ownedBy(world, stream.netId, peer.id);
      if (check.entity == null) continue; // despawned meanwhile: stale
      if (!check.owned) {
        _reject(
          world,
          peer.id,
          NetRejectionKind.input,
          stream.netId,
          'input for an entity the peer does not own',
        );
        continue;
      }
      final queue = peer.inputs.putIfAbsent(
        stream.netId,
        TickInputQueue<Uint8List>.new,
      );
      for (var i = 0; i < stream.inputs.length; i++) {
        queue.add(stream.firstTick + i, stream.inputs[i], currentTick: tick);
      }
    }
    var late = 0;
    for (final q in peer.inputs.values) {
      late += q.lateCount;
    }
    if (late > peer.lateInputs) {
      session.stats.lateInputs += late - peer.lateInputs;
      peer.lateInputs = late;
    }
  }

  void _onChannel(World world, _HostPeer peer, Uint8List data) {
    if (data.isEmpty || data[0] != ChannelId.control) {
      _reject(
        world,
        peer.id,
        NetRejectionKind.message,
        0,
        'clients may only use the control channel',
      );
      return;
    }
    data = Uint8List.sublistView(data, 1);
    peer.channel.onAck(peer.channel.receivePacket(data));
    for (final message in peer.channel.drain()) {
      try {
        final r = PacketReader(message);
        final kind = r.readByte();
        if (kind != WireKind.rpc) {
          _reject(
            world,
            peer.id,
            NetRejectionKind.message,
            0,
            'clients may only send RPC messages (got kind $kind)',
          );
          continue;
        }
        final index = r.readVarUint();
        final targetNetId = r.readVarUint();
        final bytes = r.readVarBytes();
        final rpcs = _registry.rpcs;
        if (index >= rpcs.length) {
          _reject(world, peer.id, NetRejectionKind.message, 0, 'unknown RPC');
          continue;
        }
        Entity? target;
        if (targetNetId != 0) {
          final check = _ownedBy(world, targetNetId, peer.id);
          if (!check.owned) {
            _reject(
              world,
              peer.id,
              NetRejectionKind.rpc,
              targetNetId,
              'RPC targets an entity the peer does not own',
            );
            continue;
          }
          target = check.entity;
        }
        rpcs[index].emit(world, peer.id, bytes, targetNetId, target);
      } on Object {
        _reject(world, peer.id, NetRejectionKind.message, 0, 'malformed RPC');
      }
    }
  }

  /// Most actions a client may have waiting to be released.
  static const int maxQueuedActions = 256;

  void _onAction(World world, _HostPeer peer, ActionEntry entry) {
    final ActionEntry(:index, :seq, :tick, :targetNetId, :bytes) = entry;
    if (seq <= peer.lastActionSeq) return; // a copy (actions are resent)
    if (seq != peer.lastActionSeq + 1) {
      // A gap an honest client can't make (it resends from the oldest
      // unacknowledged action): dropped, as there is nothing sound to
      // answer.
      _reject(
        world,
        peer.id,
        NetRejectionKind.action,
        targetNetId,
        'action out of sequence (got $seq, expected ${peer.lastActionSeq + 1})',
      );
      return;
    }
    peer.lastActionSeq = seq;
    final reps = _registry.actions;
    Object? value;
    String? problem;
    if (index >= reps.length) {
      problem = 'unknown action';
    } else if (peer.actions.length >= maxQueuedActions) {
      problem = 'too many actions';
    } else {
      try {
        value = reps[index].decode(bytes);
      } on Object {
        problem = 'malformed action';
      }
    }
    if (problem != null) {
      _reject(world, peer.id, NetRejectionKind.action, targetNetId, problem);
      _queueResolution(peer.id, seq, false, problem, _actionTick);
      return;
    }
    peer.actions.add(
      _InAction(index, seq, tick, value, targetNetId: targetNetId),
    );
  }

  /// The host's own action: released with the next tick's actions.
  NetActionTicket queueLocalAction(int index, Object? value, Entity? target) {
    final seq = ++_localActionSeq;
    final tick = _actionTick;
    _localActions.add(_InAction(index, seq, tick, value, target: target));
    _localOutstanding[seq] = OutstandingAction(index, seq, tick, value, target);
    return NetActionTicket(seq, tick);
  }

  /// `NetInputSystem`: publish the actions due this tick.
  void releaseActions(World world) {
    final tick = world.getResource<NetworkTick>()?.serverTick ?? 0;
    _actionTick = tick;
    final reps = _registry.actions;
    if (reps.isEmpty) return;
    final registry = world.getResource<NetworkEntityRegistry>();
    final due = [for (final _ in reps) <NetAction<Object?>>[]];
    // A client's actions wait for the tick they were sent at, unless that
    // is implausibly far ahead.
    final horizon = tick + _config.tickRate;
    void release(int peerId, ListQueue<_InAction> queue) {
      while (queue.isNotEmpty) {
        final a = queue.first;
        if (a.tick > tick && a.tick <= horizon) break;
        queue.removeFirst();
        var target = a.target;
        var targetNetId = a.targetNetId;
        if (peerId == 0) {
          targetNetId = target == null ? 0 : registry?.getNetId(target) ?? 0;
        } else if (targetNetId != 0) {
          final check = _ownedBy(world, targetNetId, peerId);
          if (!check.owned) {
            const reason = 'action targets an entity the peer does not own';
            _reject(
              world,
              peerId,
              NetRejectionKind.action,
              targetNetId,
              reason,
            );
            _queueResolution(peerId, a.seq, false, reason, tick);
            continue;
          }
          target = check.entity;
        }
        due[a.index].add(
          reps[a.index].action(
            peerId,
            a.seq,
            a.tick,
            a.value,
            targetNetId,
            target,
          ),
        );
        _unresolved[(peerId, a.seq)] = a;
      }
    }

    release(0, _localActions);
    for (final peer in _peers.values) {
      release(peer.id, peer.actions);
    }
    for (var i = 0; i < reps.length; i++) {
      reps[i].publish(world, tick, due[i]);
    }
  }

  /// Decide a released action. Returns `false` if it was already decided
  /// (or never released).
  bool resolveAction(
    int peerId,
    int seq, {
    required bool accepted,
    String? reason,
  }) {
    if (_unresolved.remove((peerId, seq)) == null) return false;
    _queueResolution(peerId, seq, accepted, reason, _actionTick);
    return true;
  }

  void _queueResolution(
    int peerId,
    int seq,
    bool accepted,
    String? reason,
    int tick,
  ) {
    if (peerId == 0) {
      final outstanding = _localOutstanding.remove(seq);
      if (outstanding != null) {
        _localResolved.add((outstanding, accepted, reason, tick));
      }
      return;
    }
    final peer = _peers[peerId];
    if (peer == null) return;
    final out = PacketBuilder()
      ..writeByte(WireKind.resolved)
      ..writeVarUint(seq)
      ..writeUint32(tick)
      ..writeByte((accepted ? 1 : 0) | (reason != null ? 2 : 0));
    if (reason != null) out.writeString(reason);
    peer.resolutions.add(out.build());
  }

  /// Settle this tick's actions: anything not resolved counts as accepted.
  /// Report the host's own resolutions, and queue each client's behind the
  /// resource chunks already queued for it ([lagging] lists the clients
  /// whose chunks had to wait for budget: their resolutions wait too; null
  /// when resources were not sent this tick).
  void _sendResolutions(World world, {required Set<int>? lagging}) {
    for (final (peerId, seq) in _unresolved.keys.toList()) {
      resolveAction(peerId, seq, accepted: true);
    }
    final reps = _registry.actions;
    for (final (a, accepted, reason, tick) in _localResolved) {
      reps[a.index].emitResolved(
        world,
        a.seq,
        a.tick,
        a.value,
        accepted: accepted,
        resolvedTick: tick,
        reason: reason,
      );
    }
    _localResolved.clear();
    if (lagging == null) return;
    for (final peer in _peers.values) {
      if (peer.resolutions.isEmpty || peer.overflowed) continue;
      if (lagging.contains(peer.id)) continue;
      while (peer.resolutions.isNotEmpty &&
          peer.bulk.canEnqueue(peer.resolutions.first.length)) {
        peer.bulk.enqueue(peer.resolutions.removeAt(0));
      }
    }
  }

  /// The host's own actions still outstanding, of action type [index].
  Iterable<OutstandingAction> localOutstanding(int index) =>
      _localOutstanding.values.where((a) => a.index == index);

  void _onDisconnect(World world, int peerId, String reason) {
    final peer = _peers.remove(peerId);
    if (peer == null) return;
    final policy = _config.disconnectPolicy;
    final owned = <int>[];
    for (final info in _entities.values) {
      if (!world.isAlive(info.entity)) continue;
      if (world.get<NetworkIdentity>(info.entity)?.ownerId == peerId) {
        owned.add(info.netId);
      }
    }
    for (final netId in owned) {
      final entity = _entities[netId]!.entity;
      if (!world.isAlive(entity)) continue; // despawned with an ancestor
      switch (policy) {
        case OwnedEntityPolicy.despawn:
          world.despawnRecursive(entity);
        case OwnedEntityPolicy.releaseToHost:
        case OwnedEntityPolicy.holdForReturn:
          world.get<NetworkIdentity>(entity)?.ownerId = 0;
      }
    }
    final identity = peer.identity;
    if (policy == OwnedEntityPolicy.holdForReturn &&
        _named(identity) &&
        owned.isNotEmpty) {
      (_held[identity] ??= []).addAll(owned);
    }
    NetworkSession._emit(
      world,
      NetPeerDisconnected(
        peerId,
        reason,
        identity: _named(identity) ? identity : '',
        ownedNetIds: owned,
        policy: policy,
      ),
    );
  }

  // Inputs and prediction ----------------------------------------------------

  void gatherInputs(World world) {
    final rep = _registry.inputReplicator;
    if (rep == null) return;
    final tick = world.getResource<NetworkTick>()?.serverTick ?? 0;
    final maxRepeat = _config.maxInputRepeatTicks;
    final entries = <RawInputEntry>[];

    for (final peer in _peers.values) {
      for (final netId in peer.inputs.keys.toList()) {
        final check = _ownedBy(world, netId, peer.id);
        if (!check.owned) {
          peer.inputs.remove(netId); // despawned or ownership moved
          continue;
        }
        final taken = peer.inputs[netId]!.take(tick, maxRepeat: maxRepeat);
        if (taken == null) continue;
        final Object? input;
        try {
          input = rep.decode(taken.input);
        } on Object {
          continue; // undecodable input: treat as missing
        }
        entries.add(
          RawInputEntry(peer.id, check.entity!, netId, input, taken.repeated),
        );
        peer.lastProcessedInputTick = tick;
      }
    }

    // The host is a player too: its own submissions (peer 0).
    final registry = world.getResource<NetworkEntityRegistry>();
    final local = rep.takeLocal(world);
    for (final MapEntry(key: entity, value: input) in local.entries) {
      _lastLocalInput[entity] = input;
      _localRepeats[entity] = 0;
    }
    for (final entity in _lastLocalInput.keys.toList()) {
      final identity = world.isAlive(entity)
          ? world.get<NetworkIdentity>(entity)
          : null;
      if (!world.isAlive(entity) ||
          (identity != null && identity.ownerId != 0)) {
        _lastLocalInput.remove(entity);
        _localRepeats.remove(entity);
        continue;
      }
      final fresh = local.containsKey(entity);
      if (!fresh) {
        final repeats = (_localRepeats[entity] ?? 0) + 1;
        _localRepeats[entity] = repeats;
        if (repeats > maxRepeat) continue;
      }
      entries.add(
        RawInputEntry(
          0,
          entity,
          registry?.getNetId(entity) ?? 0,
          _lastLocalInput[entity],
          !fresh,
        ),
      );
    }

    _tickInputs = entries;
    rep.publish(world, tick, entries);
  }

  void predict(World world) {
    final predictions = _registry.predictions;
    if (predictions.isEmpty || _tickInputs.isEmpty) return;
    final dt = world.getResource<FixedTimestep>()?.stepSeconds ?? 0;
    final tick = world.getResource<NetworkTick>()?.serverTick ?? 0;
    for (final entry in _tickInputs) {
      if (!world.isAlive(entry.entity)) continue;
      final context = PredictContext(
        world: world,
        entity: entry.entity,
        tick: tick,
        dt: dt,
      );
      for (final p in predictions) {
        final c = p.component;
        if (!c.has(world, entry.entity)) continue;
        c.insert(
          world,
          entry.entity,
          p.step(c.get(world, entry.entity), entry.input, context),
        );
      }
    }
  }

  // Replication (fixedLast) --------------------------------------------------

  void queueRpc(int index, Uint8List bytes, Entity? target, int? to, int? ex) {
    _checkRpcSize(bytes);
    _rpcs.add(_OutRpc(index, bytes, target, to, ex));
  }

  void send(World world) {
    final registry = world.getResource<NetworkEntityRegistry>();
    if (registry == null) return;
    final tick = world.getResource<NetworkTick>()?.serverTick ?? 0;

    _registerNew(world, registry);
    _detectRemovals(world, registry);
    _refreshFacts(world, registry);

    final componentCache = <int, Map<int, Uint8List>>{};
    Map<int, Uint8List> componentsOf(_HostEntity info) => componentCache
        .putIfAbsent(info.netId, () => _encodeComponents(world, info));
    final stateCache = <int, Uint8List>{};
    Uint8List stateOf(_HostEntity info) =>
        stateCache.putIfAbsent(info.netId, () {
          _stateOut.clear();
          writeEntityState(_stateOut, componentsOf(info));
          return _stateOut.build();
        });
    // What a client that doesn't own an entity gets: no owner-only
    // components.
    final private = {
      for (final c in _registry.components)
        if (c.ownerOnly) c.index,
    };
    final publicCache = <int, Map<int, Uint8List>>{};
    Map<int, Uint8List> componentsFor(_HostEntity info, int peerId) {
      if (private.isEmpty || info.owner == peerId) return componentsOf(info);
      return publicCache.putIfAbsent(
        info.netId,
        () => {
          for (final e in componentsOf(info).entries)
            if (!private.contains(e.key)) e.key: e.value,
        },
      );
    }

    final publicStateCache = <int, Uint8List>{};
    Uint8List stateFor(_HostEntity info, int peerId) {
      if (private.isEmpty || info.owner == peerId) return stateOf(info);
      return publicStateCache.putIfAbsent(info.netId, () {
        _stateOut.clear();
        writeEntityState(_stateOut, componentsFor(info, peerId));
        return _stateOut.build();
      });
    }

    // Entities skipped as oversized rejoin once their state fits again.
    for (final info in _entities.values) {
      if (info.oversized) {
        info.oversized =
            stateOf(info).length > NetworkSession.maxEntityStateBytes;
      }
    }

    final changed = [
      for (final info in _entities.values)
        if (!info.isNew &&
            (info.parent != info.sentParent || info.owner != info.sentOwner))
          info,
    ];

    // Refill each client's allowance; at most a tenth of a second banks.
    final perTick = _config.sendBudgetBytesPerSecond / _config.tickRate;
    final cap = _config.sendBudgetBytesPerSecond / 10;
    for (final peer in _peers.values) {
      peer.allowance = math.min(peer.allowance + perTick, cap);
    }

    final grid = _InterestGrid.build(_entities.values, _config.interestRadius);
    for (final peer in _peers.values) {
      final next = _relevantFor(world, peer.id, grid);
      final enters =
          [
            for (final id in next)
              if (!peer.relevant.contains(id)) _entities[id]!,
          ]..sort(
            (a, b) => a.depth != b.depth
                ? a.depth.compareTo(b.depth)
                : a.netId.compareTo(b.netId),
          );
      // Spawns are queued only while about two seconds of the budget is
      // unacknowledged; the rest wait for later passes (children wait for
      // their parents), so a big join streams in instead of piling up.
      final window = _config.sendBudgetBytesPerSecond * 2;
      final spawned = <int>{};
      for (final info in enters) {
        final parentReady =
            info.parent == 0 ||
            (next.contains(info.parent) &&
                (peer.relevant.contains(info.parent) ||
                    spawned.contains(info.parent)));
        if (!parentReady || peer.channel.unackedBytes > window) {
          next.remove(info.netId);
          continue;
        }
        if (!_fits(info, stateOf(info))) {
          next.remove(info.netId); // never spawned on this peer
          continue;
        }
        _enqueue(peer, _spawnMessage(info, tick, stateFor(info, peer.id)));
        spawned.add(info.netId);
        // The spawn arrives reliably: the client has this state.
        final comps = componentsFor(info, peer.id);
        peer.baselines[info.netId] = _Baseline(_maskOf(comps.keys), {
          for (final i in comps.keys) i: info.componentVersions[i]!,
        }, peer.nextChunkSeq);
      }
      for (final info in changed) {
        if (!peer.relevant.contains(info.netId) || !next.contains(info.netId)) {
          continue;
        }
        if (info.parent != info.sentParent) {
          _enqueue(
            peer,
            (_messageOut
                  ..clear()
                  ..writeByte(WireKind.parent)
                  ..writeVarUint(info.netId)
                  ..writeVarUint(info.parent))
                .build(),
          );
        }
        if (info.owner != info.sentOwner) {
          _enqueue(
            peer,
            (_messageOut
                  ..clear()
                  ..writeByte(WireKind.owner)
                  ..writeVarUint(info.netId)
                  ..writeVarUint(info.owner))
                .build(),
          );
        }
      }
      final exits =
          [
            for (final id in peer.relevant)
              if (!next.contains(id)) _entities[id]!,
          ]..sort(
            (a, b) => a.depth != b.depth
                ? b.depth.compareTo(a.depth)
                : a.netId.compareTo(b.netId),
          );
      for (final info in exits) {
        _enqueue(peer, _despawnMessage(info.netId));
        peer.baselines.remove(info.netId);
      }
      peer.relevant
        ..clear()
        ..addAll(next);
    }

    for (final info in _entities.values) {
      info
        ..isNew = false
        ..sentParent = info.parent
        ..sentOwner = info.owner;
    }

    // Spend each client's allowance: control first (spawns, RPCs), then
    // snapshots, then resource chunks.
    _flushRpcs(registry);
    _flushChannels(bulk: false);
    Set<int>? lagging;
    if (tick % _config.syncInterval == 0) {
      _sendSnapshots(world, tick, stateOf, componentsFor);
      lagging = _sendResources(world);
    } else if (_registry.resources.isEmpty) {
      lagging = const {}; // no resource to wait for: resolve every tick
    }
    _sendResolutions(world, lagging: lagging);
    _flushChannels(bulk: true);
  }

  /// Queue [message] on [peer]'s channel. A full channel means the peer
  /// is not acknowledging: the message is dropped and the peer is
  /// disconnected by the next [_flushChannels] (the ordered stream is
  /// broken, so nothing more is queued for it).
  void _enqueue(_HostPeer peer, Uint8List message) {
    if (peer.overflowed) return;
    if (peer.channel.isFull) {
      peer.overflowed = true;
      return;
    }
    peer.channel.enqueue(message);
  }

  /// Whether [info]'s encoded [state] fits `maxEntityStateBytes`. If not,
  /// marks it oversized (it is then not relevant to any peer) and reports
  /// it once.
  bool _fits(_HostEntity info, Uint8List state) {
    if (state.length <= NetworkSession.maxEntityStateBytes) return true;
    info.oversized = true;
    if (_reportedOversized.add(info.netId)) {
      session.stats.oversizedEntities++;
      developer.log(
        'Not replicating entity netId ${info.netId}: its replicated state '
        'is ${state.length} bytes, more than '
        '${NetworkSession.maxEntityStateBytes} bytes. It replicates again '
        'once it fits.',
        name: 'fledge_net',
        level: 900, // WARNING
      );
    }
    return false;
  }

  Uint8List _despawnMessage(int netId) =>
      (_messageOut
            ..clear()
            ..writeByte(WireKind.despawn)
            ..writeVarUint(netId))
          .build();

  /// Spawn message for [info]; [state] must pass [_fits].
  Uint8List _spawnMessage(_HostEntity info, int tick, Uint8List state) =>
      (_messageOut
            ..clear()
            ..writeByte(WireKind.spawn)
            ..writeVarUint(info.netId)
            ..writeVarUint(info.owner)
            ..writeVarUint(info.parent)
            ..writeUint32(tick)
            ..writeRawBytes(state))
          .build();

  /// [info]'s replicated components, encoded; bumps the version of each
  /// whose bytes changed since last time.
  Map<int, Uint8List> _encodeComponents(World world, _HostEntity info) {
    final components = <int, Uint8List>{};
    for (final c in _registry.components) {
      if (!c.has(world, info.entity)) continue;
      final bytes = c.encodeFrom(world, info.entity);
      components[c.index] = bytes;
      final last = info.componentBytes[c.index];
      if (last == null || !_sameBytes(last, bytes)) {
        info.componentBytes[c.index] = bytes;
        info.componentVersions[c.index] =
            (info.componentVersions[c.index] ?? 0) + 1;
      }
    }
    info.componentBytes.removeWhere((i, _) => !components.containsKey(i));
    return components;
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static int _maskOf(Iterable<int> indices) {
    var mask = 0;
    for (final i in indices) {
      mask |= 1 << i;
    }
    return mask;
  }

  /// A client acknowledged snapshot chunks [newest] and those flagged in
  /// [bits] (bit i: newest-1-i): what they carried is now its baseline.
  /// Chunks too old to be acknowledged any more are forgotten: what they
  /// carried is sent again.
  void _onChunkAcks(_HostPeer peer, int newest, int bits) {
    if (newest == 0) return;
    void applyAck(int seq) {
      final sent = peer.inFlight.remove(seq);
      if (sent == null) return;
      for (final entry in sent) {
        final base = peer.baselines[entry.netId];
        if (base == null) continue; // despawned or left relevance
        for (final MapEntry(key: i, value: v) in entry.versions.entries) {
          if ((base.versions[i] ?? 0) < v) base.versions[i] = v;
        }
        if (seq > base.maskSeq) {
          base
            ..presentMask = entry.presentMask
            ..maskSeq = seq;
          base.versions.removeWhere(
            (i, _) => entry.presentMask & (1 << i) == 0,
          );
        }
      }
    }

    applyAck(newest);
    for (var i = 0; i < 32; i++) {
      if (bits & (1 << i) != 0) applyAck(newest - 1 - i);
    }
    while (peer.inFlight.isNotEmpty &&
        peer.inFlight.firstKey()! < newest - 32) {
      peer.inFlight.remove(peer.inFlight.firstKey());
    }
  }

  void _registerNew(World world, NetworkEntityRegistry registry) {
    final fresh = <(Entity, Replicated)>[
      for (final (entity, rep) in world.query1<Replicated>().iter())
        if (registry.getNetId(entity) == null) (entity, rep),
    ]..sort((a, b) => a.$1.id.compareTo(b.$1.id));
    for (final (entity, rep) in fresh) {
      final netId = registry.generateNetId();
      registry.register(entity, netId);
      world.insert(entity, NetworkIdentity(netId: netId, ownerId: rep.owner));
      _entities[netId] = _HostEntity(netId, entity);
    }
  }

  void _detectRemovals(World world, NetworkEntityRegistry registry) {
    for (final info in _entities.values.toList()) {
      final alive = world.isAlive(info.entity);
      if (alive && world.has<Replicated>(info.entity)) continue;
      _entities.remove(info.netId);
      _reportedOversized.remove(info.netId);
      if (registry.getEntity(info.netId) == info.entity) {
        registry.unregister(info.entity);
      }
      for (final peer in _peers.values) {
        peer.inputs.remove(info.netId);
        peer.baselines.remove(info.netId);
        if (peer.relevant.remove(info.netId)) {
          _enqueue(peer, _despawnMessage(info.netId));
        }
      }
    }
  }

  void _refreshFacts(World world, NetworkEntityRegistry registry) {
    final positionOf = _config.interestRadius == null
        ? null
        : _registry.positionOf;
    for (final info in _entities.values) {
      final e = info.entity;
      final parentEntity = world.getParent(e);
      final parentNetId = parentEntity == null
          ? null
          : registry.getNetId(parentEntity);
      info
        ..parent = (parentNetId != null && _entities.containsKey(parentNetId))
            ? parentNetId
            : 0
        ..owner = world.get<NetworkIdentity>(e)?.ownerId ?? 0
        ..alwaysRelevant = world.get<Replicated>(e)?.alwaysRelevant ?? false
        ..ownerOnly = world.get<Replicated>(e)?.ownerOnly ?? false
        ..position = positionOf?.call(world, e);
      if (info.isNew) {
        info
          ..sentParent = info.parent
          ..sentOwner = info.owner;
      }
    }
    // Depth (0 = root among replicated entities); hierarchies are acyclic.
    for (final info in _entities.values) {
      var depth = 0;
      var p = info.parent;
      while (p != 0 && depth < 64) {
        depth++;
        p = _entities[p]?.parent ?? 0;
      }
      info.depth = depth;
    }
  }

  /// Interest set for [peerId]: always-relevant entities, entities the
  /// peer owns, entities without a position, and entities within
  /// `interestRadius` of its first positioned owned entity (found through
  /// [grid]); minus owner-only entities of others and whatever
  /// `NetworkConfig.relevance` hides; closed over ancestors (a child is
  /// useless without its parent).
  Set<int> _relevantFor(World world, int peerId, _InterestGrid? grid) {
    final radius = _config.interestRadius;
    final custom = _config.relevance;
    bool visible(_HostEntity info) {
      if (info.oversized) return false;
      if (info.ownerOnly && info.owner != peerId) return false;
      if (custom != null &&
          info.owner != peerId &&
          !custom(world, info.entity, peerId)) {
        return false;
      }
      return true;
    }

    (double, double)? focus;
    if (radius != null && grid != null) {
      for (final info in _entities.values) {
        if (info.owner == peerId && info.position != null) {
          focus = info.position;
          break;
        }
      }
    }
    final result = <int>{};
    if (focus == null || grid == null) {
      for (final info in _entities.values) {
        if (visible(info)) result.add(info.netId);
      }
    } else {
      for (final info in _entities.values) {
        if (!visible(info)) continue;
        if (info.alwaysRelevant ||
            info.owner == peerId ||
            info.position == null) {
          result.add(info.netId);
        }
      }
      final r2 = radius! * radius;
      for (final info in grid.near(focus)) {
        if (result.contains(info.netId) || !visible(info)) continue;
        final pos = info.position!;
        final dx = pos.$1 - focus.$1;
        final dy = pos.$2 - focus.$2;
        if (dx * dx + dy * dy <= r2) result.add(info.netId);
      }
    }
    // Ancestors come along (a client can't spawn a child without its
    // parent), even outside the interest radius. But the host's explicit
    // rules win: a child whose ancestor is hidden from this peer (owner-
    // only, refused by the custom relevance, or oversized) is hidden too,
    // so a private parent never reaches other players through a child.
    for (final id in result.toList()) {
      final chain = <int>[];
      var p = _entities[id]!.parent;
      var hidden = false;
      while (p != 0) {
        final ancestor = _entities[p];
        if (ancestor == null || !visible(ancestor)) {
          hidden = true;
          break;
        }
        chain.add(p);
        p = ancestor.parent;
      }
      if (hidden) {
        result.remove(id);
      } else {
        result.addAll(chain);
      }
    }
    return result;
  }

  /// Sends each client the entities that changed since its last
  /// acknowledged copy: for each, which components exist, and the bytes of
  /// those that changed (and, to their owner, every predicted component,
  /// which reconciliation needs every snapshot). At least one chunk, maybe
  /// empty, goes every sync: it carries the tick and the acks.
  void _sendSnapshots(
    World world,
    int tick,
    Uint8List Function(_HostEntity) stateOf,
    Map<int, Uint8List> Function(_HostEntity, int peerId) componentsFor,
  ) {
    const budget = _snapshotEntryBudget;
    for (final peer in _peers.values) {
      // Owned entities first (prediction and the player's own view), then
      // the rest from a rotating start, so a tight budget reaches every
      // entity in turn.
      final sorted = peer.relevant.toList()..sort();
      final owned = [
        for (final id in sorted)
          if (_entities[id]?.owner == peer.id) id,
      ];
      final others = [
        for (final id in sorted)
          if (_entities[id]?.owner != peer.id) id,
      ];
      final start = others.isEmpty ? 0 : peer.snapshotCursor % others.length;
      final ids = [
        ...owned,
        ...others.sublist(start),
        ...others.sublist(0, start),
      ];
      final chunks = <List<(Uint8List, _SentEntity)>>[[]];
      var size = 0;
      for (final id in ids) {
        final info = _entities[id];
        if (info == null) continue;
        // Outgrown maxEntityStateBytes: left out (and despawned on clients
        // by the next send pass).
        if (!_fits(info, stateOf(info))) continue;
        final comps = componentsFor(info, peer.id);
        final present = _maskOf(comps.keys);
        final base = peer.baselines[id];
        final owned = info.owner == peer.id;
        final changed = <int, Uint8List>{};
        final versions = <int, int>{};
        for (final MapEntry(key: index, value: bytes) in comps.entries) {
          final version = info.componentVersions[index]!;
          final predicted = owned && _registry.predictionFor(index) != null;
          if (predicted || base == null || base.versions[index] != version) {
            changed[index] = bytes;
            versions[index] = version;
          }
        }
        if (changed.isEmpty && base != null && base.presentMask == present) {
          continue;
        }
        final entry =
            (_entryOut
                  ..clear()
                  ..writeVarUint(id))
                .build();
        _stateOut.clear();
        writeEntityDelta(_stateOut, present, changed);
        final delta = _stateOut.build();
        final bytes = Uint8List(entry.length + delta.length)
          ..setAll(0, entry)
          ..setAll(entry.length, delta);
        if (size + bytes.length > budget && chunks.last.isNotEmpty) {
          chunks.add([]);
          size = 0;
        }
        chunks.last.add((bytes, _SentEntity(id, present, versions)));
        size += bytes.length;
      }
      // The first chunk always goes (it carries the tick and the acks); the
      // rest while the allowance lasts. Entities left out stay changed, so
      // they go next time, and the cursor moves on to start with them.
      var sendable = 1;
      var cost = chunks.first.fold(0, (n, e) => n + e.$1.length);
      for (var i = 1; i < chunks.length; i++) {
        if (peer.allowance - cost <= 0) break;
        cost += chunks[i].fold(0, (n, e) => n + e.$1.length);
        sendable++;
      }
      if (sendable < chunks.length && others.isNotEmpty) {
        final firstLeft = chunks[sendable].first.$2.netId;
        final at = others.indexOf(firstLeft);
        if (at >= 0) peer.snapshotCursor = at;
      }
      chunks.removeRange(sendable, chunks.length);
      for (var i = 0; i < chunks.length; i++) {
        final seq = peer.nextChunkSeq++;
        final out = _chunkOut..clear();
        SnapshotHeader(
          serverTick: tick,
          ackInputTick: peer.lastProcessedInputTick,
          reliableAck: peer.channel.receivedAck,
          lateInputs: peer.lateInputs,
          chunkSeq: seq,
          actionAck: peer.lastActionSeq,
          chunkIndex: i,
          chunkCount: chunks.length,
        ).write(out);
        out.writeVarUint(chunks[i].length);
        for (final (bytes, _) in chunks[i]) {
          out.writeRawBytes(bytes);
        }
        peer.inFlight[seq] = [for (final (_, sent) in chunks[i]) sent];
        final packet = out.build();
        peer.allowance -= packet.length;
        _send(peer.id, PacketType.stateUpdate, packet);
        session.stats.snapshotChunksSent++;
      }
    }
  }

  final PacketBuilder _resourceOut = PacketBuilder();
  final PacketBuilder _resourceChunkOut = PacketBuilder();

  /// Queues, on each client's bulk channel, every resource chunk whose
  /// version changed since it was last queued for that client (everything,
  /// for a client that just joined or a resource whose chunk count
  /// changed). A full channel leaves the rest for the next pass. Returns
  /// the clients left with chunks still to send.
  Set<int> _sendResources(World world) {
    final lagging = <int>{};
    for (final rep in _registry.resources) {
      final resource = rep.of(world);
      if (resource == null) continue;
      final count = rep.chunkCount(resource);
      final versions = [
        for (var c = 0; c < count; c++) rep.chunkVersion(resource, c),
      ];
      final encoded = <int, Uint8List>{};
      Uint8List message(int chunk) => encoded.putIfAbsent(chunk, () {
        final data = rep.encodeChunk(resource, chunk, _resourceChunkOut);
        return (_resourceOut
              ..clear()
              ..writeByte(WireKind.resource)
              ..writeVarUint(rep.index)
              ..writeVarUint(count)
              ..writeVarUint(chunk)
              ..writeRawBytes(data))
            .build();
      });
      for (final peer in _peers.values) {
        if (peer.overflowed) {
          lagging.add(peer.id);
          continue;
        }
        var sent = peer.resourceVersions[rep.index];
        if (sent == null || sent.length != count) {
          sent = List<int?>.filled(count, null);
          peer.resourceVersions[rep.index] = sent;
        }
        for (var c = 0; c < count; c++) {
          if (sent[c] == versions[c]) continue;
          final bytes = message(c);
          // Queue no more than about two seconds of the budget at once.
          if ((peer.bulk.unackedBytes + bytes.length >
                      _config.sendBudgetBytesPerSecond * 2 &&
                  peer.bulk.unackedCount > 0) ||
              !peer.bulk.canEnqueue(bytes.length)) {
            lagging.add(peer.id);
            break;
          }
          peer.bulk.enqueue(bytes);
          sent[c] = versions[c];
          session.stats.resourceChunksSent++;
        }
      }
    }
    return lagging;
  }

  void _flushRpcs(NetworkEntityRegistry registry) {
    if (_rpcs.isEmpty) return;
    for (final rpc in _rpcs) {
      final target = rpc.target;
      final targetNetId = target == null ? 0 : registry.getNetId(target) ?? 0;
      final message = _rpcMessage(rpc.index, targetNetId, rpc.bytes);
      for (final peer in _peers.values) {
        if (rpc.to != null && peer.id != rpc.to) continue;
        if (rpc.except != null && peer.id == rpc.except) continue;
        _enqueue(peer, message);
      }
    }
    _rpcs.clear();
  }
}

/// [packet] prefixed with its channel byte.
Uint8List _onChannelId(int channel, Uint8List packet) =>
    (BytesBuilder(copy: false)
          ..addByte(channel)
          ..add(packet))
        .takeBytes();

Uint8List _rpcMessage(int index, int targetNetId, Uint8List bytes) =>
    (PacketBuilder()
          ..writeByte(WireKind.rpc)
          ..writeVarUint(index)
          ..writeVarUint(targetNetId)
          ..writeVarBytes(bytes))
        .build();

void _checkRpcSize(Uint8List bytes) {
  final max = ReliableChannel.maxMessageBytes - 16;
  if (bytes.length > max) {
    throw ArgumentError.value(
      bytes.length,
      'rpc payload',
      'RPC payload is ${bytes.length} bytes; the maximum is $max bytes',
    );
  }
}

/// Upper bound of a spawn message's bytes before the entity state:
/// kind, netId, ownerId and parent varints, uint32 tick.
const int _spawnHeaderMaxBytes = 1 + 5 + 5 + 5 + 4;

/// Bytes of a snapshot chunk available for entity entries (header and
/// entity count varint excluded). One entry (netId varint + at most
/// `NetworkSession.maxEntityStateBytes` of state) always fits; see the
/// `maxEntityStateBytes` test.
const int _snapshotEntryBudget =
    Packet.maxPayloadBytes - SnapshotHeader.maxBytes - 5;

/// Positioned entities bucketed by cell (the interest radius), so finding
/// those near a point looks at nine cells instead of every entity.
class _InterestGrid {
  _InterestGrid(this.cell);

  final double cell;
  final Map<(int, int), List<_HostEntity>> _cells = {};

  static _InterestGrid? build(Iterable<_HostEntity> entities, double? radius) {
    if (radius == null || radius <= 0) return null;
    final grid = _InterestGrid(radius);
    for (final info in entities) {
      final pos = info.position;
      if (pos == null) continue;
      grid._cells.putIfAbsent(grid._key(pos), () => []).add(info);
    }
    return grid;
  }

  (int, int) _key((double, double) pos) =>
      ((pos.$1 / cell).floor(), (pos.$2 / cell).floor());

  /// Entities in the 3x3 cells around [pos] (every one within a radius).
  Iterable<_HostEntity> near((double, double) pos) sync* {
    final (cx, cy) = _key(pos);
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final bucket = _cells[(cx + dx, cy + dy)];
        if (bucket != null) yield* bucket;
      }
    }
  }
}
