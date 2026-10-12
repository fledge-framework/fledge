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

  /// Clients only send RPCs, so a small out-of-order window suffices and
  /// bounds what a misbehaving client can make the host buffer.
  final ReliableChannel channel = ReliableChannel(maxReceiveWindow: 256);

  /// Net ids currently spawned on this client.
  final Set<int> relevant = {};
  final SplayTreeMap<int, TickInputQueue<Uint8List>> inputs = SplayTreeMap();
  int lastProcessedInputTick = 0;
  int lateInputs = 0;

  _HostPeer(this.id);
}

class _HostEntity {
  final int netId;
  final Entity entity;
  bool isNew = true;
  int sentParent = 0;
  int sentOwner = 0;

  // Refreshed every send pass.
  int parent = 0;
  int owner = 0;
  bool alwaysRelevant = false;
  (double, double)? position;
  int depth = 0;

  _HostEntity(this.netId, this.entity);
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
  final Map<Entity, Object?> _lastLocalInput = {};
  final Map<Entity, int> _localRepeats = {};
  List<RawInputEntry> _tickInputs = const [];

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
    NetworkSession._sendSafely(() => host.sendTo(peerId, type, payload));
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
    _flushChannels();
  }

  void _onConnect(World world, int peerId, int tick) {
    if (_peers.containsKey(peerId)) return;
    final peer = _HostPeer(peerId);
    _peers[peerId] = peer;
    final welcome = PacketBuilder()
      ..writeByte(WireKind.welcome)
      ..writeVarUint(peerId)
      ..writeUint16(_config.tickRate)
      ..writeUint16(_config.syncRate)
      ..writeUint32(_registry.schemaHash)
      ..writeUint32(tick);
    peer.channel.enqueue(welcome.build());
    NetworkSession._emit(world, NetPeerConnected(peerId));
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

  /// Unacked reliable messages after which a peer is disconnected (it is
  /// not acknowledging; buffering more would grow without bound).
  static const int maxUnackedMessages = 16384;

  void _flushChannels() {
    final now = session.clock.nowMs;
    for (final peer in _peers.values.toList()) {
      if (peer.channel.unackedCount > maxUnackedMessages) {
        // The disconnect event then applies the owned-entity policy.
        unawaited(
          host
              .disconnectPeer(peer.id, 'Reliable channel overflow')
              .catchError((Object _) {}),
        );
        continue;
      }
      final rtt = host.getPeer(peer.id)?.rtt ?? 0;
      final packets = peer.channel.takePackets(
        nowMs: now,
        resendAfterMs: session._resendAfterMs(rtt),
        ack: peer.channel.receivedAck,
      );
      for (final p in packets) {
        _send(peer.id, PacketType.replication, p);
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
          world.get<NetworkIdentity>(entity)?.ownerId = 0;
      }
    }
    NetworkSession._emit(
      world,
      NetPeerDisconnected(peerId, reason, ownedNetIds: owned, policy: policy),
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
    for (final entry in _tickInputs) {
      if (!world.isAlive(entry.entity)) continue;
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

    final stateCache = <int, Uint8List>{};
    Uint8List stateOf(_HostEntity info) =>
        stateCache.putIfAbsent(info.netId, () => _encodeState(world, info));

    final changed = [
      for (final info in _entities.values)
        if (!info.isNew &&
            (info.parent != info.sentParent || info.owner != info.sentOwner))
          info,
    ];

    for (final peer in _peers.values) {
      final next = _relevantFor(peer.id);
      final enters =
          [
            for (final id in next)
              if (!peer.relevant.contains(id)) _entities[id]!,
          ]..sort(
            (a, b) => a.depth != b.depth
                ? a.depth.compareTo(b.depth)
                : a.netId.compareTo(b.netId),
          );
      for (final info in enters) {
        _enqueue(peer, _spawnMessage(info, tick, stateOf(info)));
      }
      for (final info in changed) {
        if (!peer.relevant.contains(info.netId) || !next.contains(info.netId)) {
          continue;
        }
        if (info.parent != info.sentParent) {
          _enqueue(
            peer,
            (PacketBuilder()
                  ..writeByte(WireKind.parent)
                  ..writeVarUint(info.netId)
                  ..writeVarUint(info.parent))
                .build(),
          );
        }
        if (info.owner != info.sentOwner) {
          _enqueue(
            peer,
            (PacketBuilder()
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

    if (tick % _config.syncInterval == 0) {
      _sendSnapshots(world, tick, stateOf);
    }
    _flushRpcs(registry);
    _flushChannels();
  }

  void _enqueue(_HostPeer peer, Uint8List message) =>
      peer.channel.enqueue(message);

  Uint8List _despawnMessage(int netId) =>
      (PacketBuilder()
            ..writeByte(WireKind.despawn)
            ..writeVarUint(netId))
          .build();

  Uint8List _spawnMessage(_HostEntity info, int tick, Uint8List state) {
    final out = PacketBuilder()
      ..writeByte(WireKind.spawn)
      ..writeVarUint(info.netId)
      ..writeVarUint(info.owner)
      ..writeVarUint(info.parent)
      ..writeUint32(tick)
      ..writeRawBytes(state);
    final message = out.build();
    final max = ReliableChannel().maxMessageBytes;
    if (message.length > max) {
      throw StateError(
        'Replicated state of entity netId ${info.netId} is '
        '${message.length} bytes; one entity must fit in $max bytes',
      );
    }
    return message;
  }

  Uint8List _encodeState(World world, _HostEntity info) {
    final components = <int, Uint8List>{};
    for (final c in _registry.components) {
      if (c.has(world, info.entity)) {
        components[c.index] = c.encodeFrom(world, info.entity);
      }
    }
    final out = PacketBuilder();
    writeEntityState(out, components);
    return out.build();
  }

  void _registerNew(World world, NetworkEntityRegistry registry) {
    final fresh = <(Entity, Replicated)>[
      for (final (entity, rep) in world.query1<Replicated>().iter())
        if (registry.getNetId(entity) == null) (entity, rep),
    ]..sort((a, b) => a.$1.id.compareTo(b.$1.id));
    for (final (entity, rep) in fresh) {
      final netId = registry.generateNetId();
      registry.register(entity, netId);
      world.insert(
        entity,
        NetworkIdentity(netId: netId, ownerId: rep.owner, hasAuthority: true),
      );
      _entities[netId] = _HostEntity(netId, entity);
    }
  }

  void _detectRemovals(World world, NetworkEntityRegistry registry) {
    for (final info in _entities.values.toList()) {
      final alive = world.isAlive(info.entity);
      if (alive && world.has<Replicated>(info.entity)) continue;
      _entities.remove(info.netId);
      if (registry.getEntity(info.netId) == info.entity) {
        registry.unregister(info.entity);
      }
      for (final peer in _peers.values) {
        peer.inputs.remove(info.netId);
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
  /// `interestRadius` of its first positioned owned entity, closed over
  /// ancestors (a child is useless without its parent).
  Set<int> _relevantFor(int peerId) {
    final radius = _config.interestRadius;
    if (radius == null || _registry.positionOf == null) {
      return _entities.keys.toSet();
    }
    (double, double)? focus;
    for (final info in _entities.values) {
      if (info.owner == peerId && info.position != null) {
        focus = info.position;
        break;
      }
    }
    if (focus == null) return _entities.keys.toSet();
    final r2 = radius * radius;
    final result = <int>{};
    for (final info in _entities.values) {
      final pos = info.position;
      if (info.alwaysRelevant || info.owner == peerId || pos == null) {
        result.add(info.netId);
        continue;
      }
      final dx = pos.$1 - focus.$1;
      final dy = pos.$2 - focus.$2;
      if (dx * dx + dy * dy <= r2) result.add(info.netId);
    }
    for (final id in result.toList()) {
      var p = _entities[id]!.parent;
      while (p != 0 && _entities.containsKey(p) && result.add(p)) {
        p = _entities[p]!.parent;
      }
    }
    return result;
  }

  void _sendSnapshots(
    World world,
    int tick,
    Uint8List Function(_HostEntity) stateOf,
  ) {
    const budget =
        Packet.maxPayloadBytes - SnapshotHeader.maxBytes - 5; // count varint
    final entryCache = <int, Uint8List>{};
    Uint8List entryOf(_HostEntity info) =>
        entryCache.putIfAbsent(info.netId, () {
          final out = PacketBuilder()
            ..writeVarUint(info.netId)
            ..writeRawBytes(stateOf(info));
          final entry = out.build();
          if (entry.length > budget) {
            throw StateError(
              'Replicated state of entity netId ${info.netId} is '
              '${entry.length} bytes; one entity must fit in $budget bytes',
            );
          }
          return entry;
        });

    for (final peer in _peers.values) {
      final ids = peer.relevant.toList()..sort();
      final chunks = <List<Uint8List>>[[]];
      var size = 0;
      for (final id in ids) {
        final info = _entities[id];
        if (info == null) continue;
        final entry = entryOf(info);
        if (size + entry.length > budget && chunks.last.isNotEmpty) {
          chunks.add([]);
          size = 0;
        }
        chunks.last.add(entry);
        size += entry.length;
      }
      for (var i = 0; i < chunks.length; i++) {
        final out = PacketBuilder();
        SnapshotHeader(
          serverTick: tick,
          ackInputTick: peer.lastProcessedInputTick,
          reliableAck: peer.channel.receivedAck,
          lateInputs: peer.lateInputs,
          chunkIndex: i,
          chunkCount: chunks.length,
        ).write(out);
        out.writeVarUint(chunks[i].length);
        for (final entry in chunks[i]) {
          out.writeRawBytes(entry);
        }
        _send(peer.id, PacketType.stateUpdate, out.build());
        session.stats.snapshotChunksSent++;
      }
    }
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

Uint8List _rpcMessage(int index, int targetNetId, Uint8List bytes) =>
    (PacketBuilder()
          ..writeByte(WireKind.rpc)
          ..writeVarUint(index)
          ..writeVarUint(targetNetId)
          ..writeVarBytes(bytes))
        .build();

void _checkRpcSize(Uint8List bytes) {
  final max = ReliableChannel().maxMessageBytes - 16;
  if (bytes.length > max) {
    throw ArgumentError.value(
      bytes.length,
      'rpc payload',
      'RPC payload is ${bytes.length} bytes; the maximum is $max bytes',
    );
  }
}
