part of 'session.dart';

class _ClientEntity {
  final int netId;
  final Entity entity;
  int owner;
  int parent = 0;
  int lastStateTick;

  _ClientEntity(this.netId, this.entity, this.owner, this.lastStateTick);
}

/// Server-tick-keyed samples of one interpolated component.
class _InterpBuffer {
  final SplayTreeMap<int, Object?> samples = SplayTreeMap();

  void add(int tick, Object? value) {
    samples[tick] = value;
    while (samples.length > 64) {
      samples.remove(samples.firstKey());
    }
  }

  /// Value at fractional server tick [at] (clamped to the buffered range).
  Object? sample(double at, ComponentReplicator<Object?> c) {
    final first = samples.firstKey()!;
    final last = samples.lastKey()!;
    if (at <= first) return samples[first];
    if (at >= last) return samples[last];
    final floor = at.floor();
    final lo = samples.containsKey(floor)
        ? floor
        : samples.lastKeyBefore(floor)!;
    final hi = samples.firstKeyAfter(lo)!;
    // Drop samples that can no longer be needed.
    while (samples.firstKey()! < lo) {
      samples.remove(samples.firstKey());
    }
    final t = (at - lo) / (hi - lo);
    return c.lerp(samples[lo], samples[hi], t);
  }
}

/// Prediction bookkeeping for one locally owned entity.
class _Predicted {
  /// tick -> component index -> encoded state after that tick.
  final SplayTreeMap<int, Map<int, Uint8List>> history = SplayTreeMap();

  /// component index -> (server tick, encoded server state).
  final Map<int, (int, Uint8List)> pendingServer = {};
}

class _ClientSide {
  final NetworkSession session;
  final NetworkClient client;
  final ClientTickSync sync;
  final ReliableChannel channel = ReliableChannel();
  final List<StreamSubscription<Object?>> _subs = [];
  final List<HostDataEvent> _inbox = [];
  final List<ProtocolMismatchEvent> _mismatches = [];

  /// Why the connection failed (set from state changes).
  String? failureReason;
  bool _lost = false;
  bool connected = false;
  bool welcomed = false;
  bool _connectedEmitted = false;
  int? peerId;

  // Tick sync handshake.
  int _syncReplies = 0;
  double _bestRtt = double.infinity;
  int _bestServerTick = 0;
  int _bestArrivalMs = 0;
  int? _lastSyncRequestMs;
  int _syncStartMs = 0;
  int _lastResets = 0;

  final SplayTreeMap<int, _ClientEntity> entities = SplayTreeMap();
  final Map<int, Set<int>> _orphans = {};
  final Map<int, Map<int, _InterpBuffer>> _interp = {};
  final Map<int, _Predicted> _predicted = {};
  final Map<int, SplayTreeMap<int, Uint8List>> _inputHistory = {};
  final Map<int, (Object?, int)> _lastInput = {};
  int ackedInputTick = 0;
  int lastSnapshotTick = 0;
  List<RawInputEntry> _tickInputs = const [];
  final List<(int, Uint8List, Entity?)> _rpcs = [];

  _ClientSide(this.session, this.client)
    : sync = ClientTickSync(
        stepMs: session._stepMs,
        bufferTicks: session.config.inputLeadBufferTicks,
      ) {
    _subs
      ..add(client.onData.listen(_inbox.add))
      ..add(
        client.onStateChange.listen((e) {
          if (e.state == ClientState.failed ||
              e.state == ClientState.disconnected) {
            failureReason ??= e.reason;
            if (connected) _lost = true;
          }
        }),
      )
      ..add(client.onProtocolMismatch.listen(_mismatches.add));
  }

  NetworkConfig get _config => session.config;
  ReplicationRegistry get _registry => session.registry;

  bool get ready => connected && welcomed && sync.synced;

  bool get _ended => !identical(session._client, this);

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void onConnected() {
    connected = true;
    peerId = client.localPeerId;
    _syncStartMs = session.clock.nowMs;
    _sendSyncRequest();
  }

  void _send(PacketType type, Uint8List payload) {
    NetworkSession._sendSafely(() => client.send(type, payload));
  }

  void queueRpc(int index, Uint8List bytes, Entity? target) {
    _checkRpcSize(bytes);
    _rpcs.add((index, bytes, target));
  }

  // Pump ----------------------------------------------------------------------

  void pump(World world) {
    client.update();
    for (final m in _mismatches) {
      NetworkSession._emit(world, NetProtocolMismatch(m));
    }
    _mismatches.clear();
    if (_lost || (connected && client.state != ClientState.connected)) {
      session._failClient(
        failureReason ?? client.lastStateReason ?? 'Connection lost',
      );
      return;
    }
    if (!connected) return;
    if (client.rtt > 0) sync.rttMs = client.rtt;

    // Tick sync replies are latency sensitive: handle them right away.
    final keep = <HostDataEvent>[];
    for (final e in _inbox) {
      if (e.type == PacketType.tickSync) {
        try {
          _onTickSync(e.data);
        } on RangeError {
          // Malformed: drop.
        }
        if (_ended) return;
      } else {
        keep.add(e);
      }
    }
    _inbox
      ..clear()
      ..addAll(keep);

    if (!sync.synced) {
      final now = session.clock.nowMs;
      if (_syncReplies >= 3 ||
          (_syncReplies >= 1 && now - _syncStartMs >= 1000)) {
        sync.initialSync(
          serverTick: _bestServerTick,
          rttSampleMs: _bestRtt,
          elapsedMs: (now - _bestArrivalMs).toDouble(),
        );
        _syncNetworkTick(world);
      } else if (_lastSyncRequestMs == null ||
          now - _lastSyncRequestMs! >= 100) {
        _sendSyncRequest();
      }
    }
    if (ready && !_connectedEmitted) {
      _connectedEmitted = true;
      NetworkSession._emit(world, NetConnected(peerId!));
    }
    _flushChannel();
  }

  void _sendSyncRequest() {
    _lastSyncRequestMs = session.clock.nowMs;
    final out = PacketBuilder()
      ..writeByte(TickSyncKind.request)
      ..writeUint32(session.clock.nowMs32);
    _send(PacketType.tickSync, out.build());
  }

  void _onTickSync(Uint8List data) {
    final r = PacketReader(data);
    if (r.readByte() != TickSyncKind.response) return;
    final echoed = r.readUint32();
    final serverTick = r.readUint32();
    final tickRate = r.readUint16();
    if (tickRate != _config.tickRate) {
      session._failClient(
        'Tick rate mismatch: local ${_config.tickRate} Hz, '
        'host $tickRate Hz',
      );
      return;
    }
    final rtt = NetClock.elapsed32(session.clock.nowMs32, echoed);
    if (rtt < 0 || rtt > 60000) return;
    _syncReplies++;
    if (rtt < _bestRtt) {
      _bestRtt = rtt.toDouble();
      _bestServerTick = serverTick;
      _bestArrivalMs = session.clock.nowMs;
    }
  }

  void _syncNetworkTick(World world) {
    final tick = world.getResource<NetworkTick>();
    if (tick == null) return;
    tick
      ..localTick = sync.localTick
      ..serverTick = sync.serverTickEstimate
      ..synced = true;
  }

  void _flushChannel() {
    final packets = channel.takePackets(
      nowMs: session.clock.nowMs,
      resendAfterMs: session._resendAfterMs(client.rtt),
      ack: channel.receivedAck,
    );
    for (final p in packets) {
      _send(PacketType.replication, p);
    }
  }

  // Receive -------------------------------------------------------------------

  void receive(World world) {
    final items = List<HostDataEvent>.of(_inbox);
    _inbox.clear();
    for (final e in items) {
      try {
        switch (e.type) {
          case PacketType.replication:
            _onChannel(world, e.data);
          case PacketType.stateUpdate:
            _onSnapshot(world, e.data);
          case PacketType.tickSync:
            _onTickSync(e.data);
          default:
            break;
        }
      } on RangeError {
        // Truncated packet: drop.
      } on FormatException {
        // Malformed packet: drop.
      }
      if (_ended) return;
    }
  }

  void _onChannel(World world, Uint8List data) {
    channel.onAck(channel.receivePacket(data));
    for (final message in channel.drain()) {
      _applyMessage(world, message);
      if (_ended) return;
    }
  }

  void _applyMessage(World world, Uint8List message) {
    final r = PacketReader(message);
    switch (r.readByte()) {
      case WireKind.welcome:
        final id = r.readVarUint();
        final tickRate = r.readUint16();
        r.readUint16(); // syncRate (informational)
        final schema = r.readUint32();
        r.readUint32(); // host tick at welcome (tick sync is separate)
        if (tickRate != _config.tickRate) {
          session._failClient(
            'Tick rate mismatch: local ${_config.tickRate} Hz, '
            'host $tickRate Hz',
          );
          return;
        }
        if (schema != _registry.schemaHash) {
          session._failClient(
            'Replication schema mismatch: host and client registered '
            'different components, inputs or RPCs',
          );
          return;
        }
        peerId = id;
        welcomed = true;
      case WireKind.spawn:
        _spawn(world, r);
      case WireKind.despawn:
        _despawn(world, r.readVarUint());
      case WireKind.parent:
        final info = entities[r.readVarUint()];
        final parent = r.readVarUint();
        if (info != null) _applyParent(world, info, parent);
      case WireKind.owner:
        final info = entities[r.readVarUint()];
        final owner = r.readVarUint();
        if (info != null) _applyOwner(world, info, owner);
      case WireKind.rpc:
        final index = r.readVarUint();
        final targetNetId = r.readVarUint();
        final bytes = r.readVarBytes();
        final rpcs = _registry.rpcs;
        if (index >= rpcs.length) return;
        try {
          rpcs[index].emit(
            world,
            0,
            bytes,
            targetNetId,
            entities[targetNetId]?.entity,
          );
        } on Object {
          // Undecodable payload: drop.
        }
      default:
        break; // Unknown kind from a newer host: ignore.
    }
  }

  void _spawn(World world, PacketReader r) {
    final netId = r.readVarUint();
    final owner = r.readVarUint();
    final parent = r.readVarUint();
    final tick = r.readUint32();
    final state = readEntityState(r);
    final components = _registry.components;

    if (entities.containsKey(netId)) _despawn(world, netId);

    final entity = world.spawn().entity;
    world.insert(
      entity,
      NetworkIdentity(
        netId: netId,
        ownerId: owner,
        hasAuthority: owner == peerId,
      ),
    );
    for (final MapEntry(key: index, value: bytes) in state.components.entries) {
      if (index >= components.length) continue;
      final c = components[index];
      final value = c.decode(bytes);
      c.insert(world, entity, value);
      if (_interpolates(index, owner)) {
        _interp
            .putIfAbsent(netId, () => {})
            .putIfAbsent(index, _InterpBuffer.new)
            .add(tick, value);
      }
    }
    world.getResource<NetworkEntityRegistry>()?.register(entity, netId);
    final info = _ClientEntity(netId, entity, owner, tick);
    entities[netId] = info;
    _applyParent(world, info, parent);

    // Children that arrived before this parent.
    final waiting = _orphans.remove(netId);
    if (waiting != null) {
      for (final childId in waiting) {
        final child = entities[childId];
        if (child != null && child.parent == netId) {
          world.setParent(child.entity, entity);
        }
      }
    }
    NetworkSession._emit(world, NetEntitySpawned(entity, netId));
  }

  void _applyParent(World world, _ClientEntity info, int parentNetId) {
    info.parent = parentNetId;
    for (final set in _orphans.values) {
      set.remove(info.netId);
    }
    if (parentNetId == 0) {
      world.removeParent(info.entity);
      return;
    }
    final parent = entities[parentNetId];
    if (parent == null) {
      // Parent not here yet: buffer the orphan until it spawns.
      world.removeParent(info.entity);
      _orphans.putIfAbsent(parentNetId, () => {}).add(info.netId);
      return;
    }
    if (world.getParent(info.entity) != parent.entity) {
      world.setParent(info.entity, parent.entity);
    }
  }

  void _applyOwner(World world, _ClientEntity info, int owner) {
    final wasOwned = info.owner == peerId;
    info.owner = owner;
    final identity = world.get<NetworkIdentity>(info.entity);
    identity?.transferAuthority(owner, localAuthority: owner == peerId);
    if (wasOwned && owner != peerId) {
      _predicted.remove(info.netId);
      _inputHistory.remove(info.netId);
      _lastInput.remove(info.netId);
    }
    if (!wasOwned && owner == peerId) {
      // Predicted components now come from prediction, not snapshots.
      final buffers = _interp[info.netId];
      for (final p in _registry.predictions) {
        buffers?.remove(p.component.index);
      }
    }
  }

  void _despawn(World world, int netId) {
    final info = entities.remove(netId);
    if (info == null) return;
    final registry = world.getResource<NetworkEntityRegistry>();
    if (registry?.getEntity(netId) == info.entity) {
      registry!.unregister(info.entity);
    }
    if (world.isAlive(info.entity)) {
      for (final child in world.getChildren(info.entity).toList()) {
        if (registry?.isRegistered(child) ?? false) {
          // Replicated child: the host re-parents or despawns it itself.
          world.removeParent(child);
        } else {
          world.despawnRecursive(child); // client-local attachment
        }
      }
      world.removeParent(info.entity);
      world.despawn(info.entity);
    }
    _interp.remove(netId);
    _predicted.remove(netId);
    _inputHistory.remove(netId);
    _lastInput.remove(netId);
    for (final set in _orphans.values) {
      set.remove(netId);
    }
    NetworkSession._emit(world, NetEntityDespawned(info.entity, netId));
  }

  /// Interpolated components are buffered, except predicted components of
  /// entities this client owns (those come from prediction).
  bool _interpolates(int index, int owner) {
    if (!_registry.components[index].interpolated) return false;
    return owner != peerId || _registry.predictionFor(index) == null;
  }

  void _onSnapshot(World world, Uint8List data) {
    final r = PacketReader(data);
    final header = SnapshotHeader.read(r);
    final count = r.readVarUint();
    final states = <(int, EntityStateData)>[];
    for (var i = 0; i < count; i++) {
      states.add((r.readVarUint(), readEntityState(r)));
    }

    session.stats.snapshotChunksReceived++;
    channel.onAck(header.reliableAck);
    if (header.ackInputTick > ackedInputTick) {
      ackedInputTick = header.ackInputTick;
      for (final history in _inputHistory.values) {
        while (history.isNotEmpty && history.firstKey()! <= ackedInputTick) {
          history.remove(history.firstKey());
        }
      }
    }
    sync.reportLateInputs(header.lateInputs);
    if (header.serverTick > lastSnapshotTick) {
      lastSnapshotTick = header.serverTick;
      sync.observe(
        serverTick: header.serverTick,
        alpha: world.getResource<FixedTimestep>()?.alpha ?? 0,
      );
      if (sync.resets != _lastResets) {
        session.stats.tickResets += sync.resets - _lastResets;
        _lastResets = sync.resets;
        _syncNetworkTick(world);
      }
    }
    for (final (netId, state) in states) {
      _applyState(world, netId, header.serverTick, state);
    }
  }

  void _applyState(World world, int netId, int tick, EntityStateData state) {
    final info = entities[netId];
    if (info == null || !world.isAlive(info.entity)) return;
    if (tick < info.lastStateTick) return; // older than what we have
    info.lastStateTick = tick;
    final e = info.entity;
    final owned = info.owner == peerId;
    for (final c in _registry.components) {
      final bytes = state.components[c.index];
      final prediction = owned ? _registry.predictionFor(c.index) : null;
      if (bytes == null) {
        if (c.has(world, e)) c.remove(world, e);
        _interp[netId]?.remove(c.index);
        continue;
      }
      if (prediction != null) {
        final predicted = _predicted[netId];
        if (predicted == null || predicted.history.isEmpty) {
          c.insert(world, e, c.decode(bytes)); // not predicting yet
        } else {
          final pending = predicted.pendingServer[c.index];
          if (pending == null || pending.$1 < tick) {
            predicted.pendingServer[c.index] = (tick, bytes);
          }
        }
        continue;
      }
      final value = c.decode(bytes);
      if (_interpolates(c.index, info.owner)) {
        _interp
            .putIfAbsent(netId, () => {})
            .putIfAbsent(c.index, _InterpBuffer.new)
            .add(tick, value);
        if (!c.has(world, e)) c.insert(world, e, value);
      } else {
        c.insert(world, e, value);
      }
    }
  }

  // Interpolation (Schedules.first) -------------------------------------------

  void interpolate(World world) {
    if (_interp.isEmpty) return;
    final alpha = world.getResource<FixedTimestep>()?.alpha ?? 0;
    final delayTicks = _config.interpolationDelay / session._stepMs;
    final at = sync.synced
        ? sync.renderTick(alpha: alpha, delayTicks: delayTicks)
        : double.infinity;
    final components = _registry.components;
    for (final MapEntry(key: netId, value: buffers) in _interp.entries) {
      final info = entities[netId];
      if (info == null || !world.isAlive(info.entity)) continue;
      for (final MapEntry(key: index, value: buffer) in buffers.entries) {
        if (buffer.samples.isEmpty) continue;
        final c = components[index];
        c.insert(world, info.entity, buffer.sample(at, c));
      }
    }
  }

  // Inputs and prediction (fixed chain) ---------------------------------------

  void gatherInputs(World world) {
    final rep = _registry.inputReplicator;
    if (rep == null) return;
    final local = rep.takeLocal(world);
    if (!ready) {
      _tickInputs = const [];
      return;
    }
    final tick = sync.localTick;
    final maxRepeat = _config.maxInputRepeatTicks;
    final entries = <RawInputEntry>[];
    for (final info in entities.values) {
      if (info.owner != peerId || !world.isAlive(info.entity)) continue;
      final Object? input;
      var repeated = false;
      if (local.containsKey(info.entity)) {
        input = local[info.entity];
        _lastInput[info.netId] = (input, 0);
      } else {
        final last = _lastInput[info.netId];
        if (last == null || last.$2 >= maxRepeat) continue;
        input = last.$1;
        repeated = true;
        _lastInput[info.netId] = (input, last.$2 + 1);
      }
      final history = _inputHistory.putIfAbsent(info.netId, SplayTreeMap.new);
      history[tick] = rep.encode(input);
      while (history.length > 256) {
        history.remove(history.firstKey());
      }
      entries.add(
        RawInputEntry(peerId!, info.entity, info.netId, input, repeated),
      );
    }
    _tickInputs = entries;
    rep.publish(world, tick, entries);
  }

  void predict(World world) {
    final predictions = _registry.predictions;
    if (sync.consumeJump()) {
      // The local tick moved discontinuously: history is meaningless.
      _predicted.clear();
      _inputHistory.clear();
    }
    if (predictions.isEmpty || !ready) return;
    final dt = world.getResource<FixedTimestep>()?.stepSeconds ?? 0;
    final rep = _registry.inputReplicator!;
    final tick = sync.localTick;

    // 1. Reconcile against the newest server state of each entity.
    for (final MapEntry(key: netId, value: predicted)
        in _predicted.entries.toList()) {
      if (predicted.pendingServer.isEmpty) continue;
      final info = entities[netId];
      if (info == null || !world.isAlive(info.entity)) continue;
      final pending = Map.of(predicted.pendingServer);
      predicted.pendingServer.clear();
      var oldest = tick;
      for (final MapEntry(key: index, value: (serverTick, bytes))
          in pending.entries) {
        final p = _registry.predictionFor(index);
        if (p == null) continue;
        oldest = math.min(oldest, serverTick);
        _reconcile(world, info, predicted, p, serverTick, bytes, rep, dt, tick);
      }
      while (predicted.history.isNotEmpty &&
          predicted.history.firstKey()! < oldest) {
        predicted.history.remove(predicted.history.firstKey());
      }
    }

    // 2. Predict this tick.
    for (final entry in _tickInputs) {
      for (final p in predictions) {
        final c = p.component;
        if (!c.has(world, entry.entity)) continue;
        c.insert(
          world,
          entry.entity,
          p.step(c.get(world, entry.entity), entry.input, dt),
        );
      }
    }
  }

  void _reconcile(
    World world,
    _ClientEntity info,
    _Predicted predicted,
    PredictionReplicator p,
    int serverTick,
    Uint8List serverBytes,
    InputReplicator<Object?> rep,
    double dt,
    int tick,
  ) {
    final c = p.component;
    final server = c.decode(serverBytes);
    final recorded = predicted.history[serverTick]?[c.index];
    if (recorded == null) {
      if (predicted.history.isEmpty ||
          serverTick > predicted.history.lastKey()!) {
        // Server is ahead of our prediction (e.g. after a tick reset).
        c.insert(world, info.entity, server);
      }
      return; // older than our history: nothing to compare against
    }
    final error = p.error(c.decode(recorded), server);
    if (error <= p.tolerance) return;

    // Mismatch: rewind to the server state and replay unacked inputs.
    final mispredicted = c.get(world, info.entity);
    var state = server;
    final inputs = _inputHistory[info.netId];
    for (var t = serverTick + 1; t < tick; t++) {
      final bytes = inputs?[t];
      if (bytes != null) state = p.step(state, rep.decode(bytes), dt);
      predicted.history[t]?[c.index] = c.encodeValue(state);
    }
    if (p.correctionBlend < 1 && mispredicted != null) {
      state = c.lerp(mispredicted, state, p.correctionBlend);
    }
    c.insert(world, info.entity, state);
    session.stats.corrections++;
    NetworkSession._emit(
      world,
      NetPredictionCorrected(info.entity, info.netId, serverTick, error),
    );
  }

  // Send (fixedLast) ----------------------------------------------------------

  void send(World world) {
    if (!connected) return;
    final tick = sync.localTick;
    if (ready) _recordPredictions(world, tick);

    var redundancy = math.max(1, _config.inputRedundancy);
    while (true) {
      final payload = InputPacket(
        clientTick: tick,
        reliableAck: channel.receivedAck,
        lastSnapshotTick: lastSnapshotTick,
        streams: ready ? _buildStreams(tick, redundancy) : const [],
      ).encode();
      if (payload.length <= Packet.maxPayloadBytes || redundancy == 1) {
        if (payload.length <= Packet.maxPayloadBytes) {
          _send(PacketType.input, payload);
        }
        break;
      }
      redundancy = (redundancy / 2).floor();
    }

    if (_rpcs.isNotEmpty) {
      final registry = world.getResource<NetworkEntityRegistry>();
      for (final (index, bytes, target) in _rpcs) {
        final targetNetId = target == null
            ? 0
            : registry?.getNetId(target) ?? 0;
        channel.enqueue(_rpcMessage(index, targetNetId, bytes));
      }
      _rpcs.clear();
    }
    _flushChannel();
  }

  void _recordPredictions(World world, int tick) {
    final predictions = _registry.predictions;
    if (predictions.isEmpty) return;
    for (final info in entities.values) {
      if (info.owner != peerId || !world.isAlive(info.entity)) continue;
      if (!(_inputHistory[info.netId]?.containsKey(tick) ?? false)) continue;
      final predicted = _predicted.putIfAbsent(info.netId, _Predicted.new);
      final snapshot = <int, Uint8List>{};
      for (final p in predictions) {
        final c = p.component;
        if (c.has(world, info.entity)) {
          snapshot[c.index] = c.encodeFrom(world, info.entity);
        }
      }
      predicted.history[tick] = snapshot;
      while (predicted.history.length > 256) {
        predicted.history.remove(predicted.history.firstKey());
      }
    }
  }

  List<InputStream> _buildStreams(int tick, int redundancy) {
    final streams = <InputStream>[];
    final from = math.max(ackedInputTick + 1, tick - redundancy + 1);
    for (final MapEntry(key: netId, value: history) in _inputHistory.entries) {
      final info = entities[netId];
      if (info == null || info.owner != peerId) continue;
      int? runStart;
      var run = <Uint8List>[];
      for (var t = from; t <= tick; t++) {
        final bytes = history[t];
        if (bytes == null) {
          if (run.isNotEmpty) streams.add(InputStream(netId, runStart!, run));
          run = <Uint8List>[];
          runStart = null;
          continue;
        }
        runStart ??= t;
        run.add(bytes);
      }
      if (run.isNotEmpty) streams.add(InputStream(netId, runStart!, run));
    }
    return streams;
  }
}
