/// Payload formats of the replication layer (protocol version 5).
///
/// All integers are little-endian; `varuint` is unsigned LEB128.
///
/// ## Entity state (shared by spawn messages and snapshots)
///
/// ```
/// varuint mask                  bit i set: registered component i present
/// per set bit, ascending: varuint length, bytes (component codec output)
/// ```
///
/// ## PacketType.stateUpdate (host to client, unreliable): snapshot chunk
///
/// ```
/// uint32  serverTick            host tick the state was captured at
/// uint32  ackInputTick          last input tick the host simulated for
///                               this client (0 = none)
/// uint32  reliableAck           host cumulative ack of the client channel
/// varuint lateInputs            running count of late inputs from client
/// uint32  chunkSeq              per-client sequence number of this chunk,
///                               acknowledged by the client (see input)
/// varuint actionAck             newest action seq received from this
///                               client
/// uint16  chunkIndex, uint16 chunkCount
/// varuint entityCount
/// entityCount x { varuint netId, entity delta }
/// ```
///
/// Every chunk is self-contained; one entity never spans two chunks. Only
/// entities that changed since the client's last acknowledged copy are
/// listed (at least one chunk, possibly empty, is sent every sync). An
/// entity whose delta is larger than `NetworkSession.maxSnapshotEntityBytes`
/// is never listed: its delta goes as a reliable `state` message instead
/// (see below), as do its later deltas until the client has acknowledged
/// that message, so a snapshot never overtakes it.
///
/// ## Entity delta (snapshots)
///
/// ```
/// varuint presentMask           bit i set: component i exists on the host
/// varuint changedMask           bit i set: component i's bytes follow
/// per changedMask bit, ascending: varuint length, bytes
/// ```
///
/// A component in neither mask is gone; one only in presentMask is
/// unchanged.
///
/// ## PacketType.input (client to host, unreliable, every client tick)
///
/// ```
/// uint32  clientTick            local tick at send time
/// uint32  reliableAck           client cumulative ack of the host control
///                               channel
/// uint32  bulkAck               client cumulative ack of the host bulk
///                               channel
/// uint32  lastSnapshotTick      newest snapshot tick received
/// uint32  chunkAck              newest snapshot chunkSeq received
/// uint32  chunkAckBits          bit i set: chunkSeq chunkAck-1-i received
/// varuint streamCount
/// streamCount x {
///   varuint netId               controlled entity
///   uint32  firstTick
///   varuint count               inputs for firstTick .. firstTick+count-1
///   count x { varuint length, bytes }   input codec output
/// }
/// varuint actionCount
/// actionCount x {               consecutive seqs, oldest unacknowledged
///   varuint actionIndex           first; resent every packet until the
///   varuint seq                   host acknowledges them (actionAck)
///   uint32  tick                tick the action was sent at
///   varuint targetNetId         0 = none
///   varuint length, bytes       action codec output
/// }
/// ```
///
/// Actions ride in every input packet until acknowledged, like inputs, so
/// a lost packet delays them one tick rather than a reliable resend. The
/// host applies each seq once (the next expected one) and ignores copies.
///
/// ## PacketType.tickSync (unreliable)
///
/// ```
/// request  (client to host): uint8 0, uint32 clientClock32
/// response (host to client): uint8 1, uint32 echoedClientClock32,
///                            uint32 serverTick, uint16 tickRate
/// ```
///
/// ## PacketType.replication messages (see `ReliableChannel`)
///
/// Every replication packet starts with a channel byte ([ChannelId]): 0 is
/// the control channel (everything below but `resource` and `resolved`),
/// 1 the bulk channel (host to client `resource` and `resolved` messages
/// only), so a large world streaming in never delays control messages. A
/// `resolved` message is queued behind every resource chunk queued before
/// it, so the action's effect on resources has arrived when it does. Each channel is its own
/// `ReliableChannel`.
///
/// ```
/// uint8 kind, then:
///   1 welcome  varuint peerId, uint16 tickRate, uint16 syncRate,
///              uint32 schemaHash, uint32 serverTick
///   2 spawn    varuint netId, varuint ownerId, varuint parentNetId (0 none),
///              uint32 tick, entity state
///   3 despawn  varuint netId
///   4 parent   varuint netId, varuint parentNetId (0 none)
///   5 owner    varuint netId, varuint ownerId
///   6 rpc      varuint rpcIndex, varuint targetNetId (0 none), varuint
///              length, bytes (RPC codec output)
///   7 resource varuint resourceIndex, varuint chunkCount, varuint chunk,
///              bytes (resource codec output for the chunk, to the end)
///   8 resolved varuint seq, uint32 resolvedTick, uint8 flags (bit 0
///              accepted, bit 1 a reason follows), [string reason]
///   9 state    varuint netId, uint32 tick, entity delta (as in snapshots)
/// ```
///
/// `spawn` and `state` messages may be larger than one packet; the
/// reliable channel sends them as fragments. A `state` message is applied
/// exactly like a snapshot entry of that tick (since version 5).
///
/// Clients may only send `rpc` messages; the host rejects anything else.
/// (Actions travel in input packets.)
library;

import 'dart:typed_data';

import '../protocol/packet.dart';

/// Reliable message kinds.
abstract final class WireKind {
  static const int welcome = 1;
  static const int spawn = 2;
  static const int despawn = 3;
  static const int parent = 4;
  static const int owner = 5;
  static const int rpc = 6;
  static const int resource = 7;
  static const int resolved = 8;

  /// An entity delta too large for a snapshot (protocol version 5).
  static const int state = 9;
}

/// Reliable channels inside `PacketType.replication` packets.
abstract final class ChannelId {
  static const int control = 0;
  static const int bulk = 1;
}

/// Tick sync sub-types.
abstract final class TickSyncKind {
  static const int request = 0;
  static const int response = 1;
}

/// Decoded entity state: component bytes by registry index.
class EntityStateData {
  final int mask;
  final Map<int, Uint8List> components;

  const EntityStateData(this.mask, this.components);
}

/// Write an entity state ([components] keyed by index, any order).
void writeEntityState(PacketBuilder out, Map<int, Uint8List> components) {
  final indices = components.keys.toList()..sort();
  var mask = 0;
  for (final i in indices) {
    mask |= 1 << i;
  }
  out.writeVarUint(mask);
  for (final i in indices) {
    out.writeVarBytes(components[i]!);
  }
}

/// Read an entity state written by [writeEntityState].
EntityStateData readEntityState(PacketReader input) {
  final mask = input.readVarUint();
  final components = <int, Uint8List>{};
  for (var i = 0; i < 63; i++) {
    if (mask & (1 << i) == 0) continue;
    components[i] = input.readVarBytes();
  }
  return EntityStateData(mask, components);
}

/// Decoded entity delta.
class EntityDeltaData {
  final int presentMask;
  final Map<int, Uint8List> changed;

  const EntityDeltaData(this.presentMask, this.changed);
}

/// Write an entity delta: [presentMask], and the [changed] components'
/// bytes (keyed by index).
void writeEntityDelta(
  PacketBuilder out,
  int presentMask,
  Map<int, Uint8List> changed,
) {
  final indices = changed.keys.toList()..sort();
  var changedMask = 0;
  for (final i in indices) {
    changedMask |= 1 << i;
  }
  out
    ..writeVarUint(presentMask)
    ..writeVarUint(changedMask);
  for (final i in indices) {
    out.writeVarBytes(changed[i]!);
  }
}

/// Read an entity delta written by [writeEntityDelta].
EntityDeltaData readEntityDelta(PacketReader input) {
  final present = input.readVarUint();
  final changedMask = input.readVarUint();
  final changed = <int, Uint8List>{};
  for (var i = 0; i < 63; i++) {
    if (changedMask & (1 << i) == 0) continue;
    changed[i] = input.readVarBytes();
  }
  return EntityDeltaData(present, changed);
}

/// Snapshot chunk header.
class SnapshotHeader {
  final int serverTick;
  final int ackInputTick;
  final int reliableAck;
  final int lateInputs;
  final int chunkSeq;
  final int actionAck;
  final int chunkIndex;
  final int chunkCount;

  const SnapshotHeader({
    required this.serverTick,
    required this.ackInputTick,
    required this.reliableAck,
    required this.lateInputs,
    this.chunkSeq = 0,
    this.actionAck = 0,
    required this.chunkIndex,
    required this.chunkCount,
  });

  /// Upper bound of the encoded size (excluding the entity count).
  static const int maxBytes = 4 + 4 + 4 + 5 + 4 + 5 + 2 + 2;

  void write(PacketBuilder out) {
    out
      ..writeUint32(serverTick)
      ..writeUint32(ackInputTick)
      ..writeUint32(reliableAck)
      ..writeVarUint(lateInputs)
      ..writeUint32(chunkSeq)
      ..writeVarUint(actionAck)
      ..writeUint16(chunkIndex)
      ..writeUint16(chunkCount);
  }

  static SnapshotHeader read(PacketReader input) => SnapshotHeader(
    serverTick: input.readUint32(),
    ackInputTick: input.readUint32(),
    reliableAck: input.readUint32(),
    lateInputs: input.readVarUint(),
    chunkSeq: input.readUint32(),
    actionAck: input.readVarUint(),
    chunkIndex: input.readUint16(),
    chunkCount: input.readUint16(),
  );
}

/// One entity input stream inside an input packet.
class InputStream {
  final int netId;
  final int firstTick;
  final List<Uint8List> inputs;

  const InputStream(this.netId, this.firstTick, this.inputs);
}

/// One action inside an input packet.
class ActionEntry {
  final int index;
  final int seq;
  final int tick;
  final int targetNetId;
  final Uint8List bytes;

  const ActionEntry(
    this.index,
    this.seq,
    this.tick,
    this.targetNetId,
    this.bytes,
  );

  /// Upper bound of the encoded size.
  int get maxEncodedBytes => 5 + 5 + 4 + 5 + 5 + bytes.length;
}

/// Decoded input packet.
class InputPacket {
  final int clientTick;
  final int reliableAck;
  final int bulkAck;
  final int lastSnapshotTick;
  final int chunkAck;
  final int chunkAckBits;
  final List<InputStream> streams;
  final List<ActionEntry> actions;

  const InputPacket({
    required this.clientTick,
    required this.reliableAck,
    this.bulkAck = 0,
    required this.lastSnapshotTick,
    this.chunkAck = 0,
    this.chunkAckBits = 0,
    required this.streams,
    this.actions = const [],
  });

  Uint8List encode() {
    final out = PacketBuilder()
      ..writeUint32(clientTick)
      ..writeUint32(reliableAck)
      ..writeUint32(bulkAck)
      ..writeUint32(lastSnapshotTick)
      ..writeUint32(chunkAck)
      ..writeUint32(chunkAckBits)
      ..writeVarUint(streams.length);
    for (final s in streams) {
      out
        ..writeVarUint(s.netId)
        ..writeUint32(s.firstTick)
        ..writeVarUint(s.inputs.length);
      for (final i in s.inputs) {
        out.writeVarBytes(i);
      }
    }
    out.writeVarUint(actions.length);
    for (final a in actions) {
      out
        ..writeVarUint(a.index)
        ..writeVarUint(a.seq)
        ..writeUint32(a.tick)
        ..writeVarUint(a.targetNetId)
        ..writeVarBytes(a.bytes);
    }
    return out.build();
  }

  static InputPacket decode(Uint8List payload) {
    final r = PacketReader(payload);
    final clientTick = r.readUint32();
    final reliableAck = r.readUint32();
    final bulkAck = r.readUint32();
    final lastSnapshotTick = r.readUint32();
    final chunkAck = r.readUint32();
    final chunkAckBits = r.readUint32();
    final count = r.readVarUint();
    final streams = <InputStream>[];
    for (var i = 0; i < count; i++) {
      final netId = r.readVarUint();
      final firstTick = r.readUint32();
      final n = r.readVarUint();
      final inputs = <Uint8List>[];
      for (var j = 0; j < n; j++) {
        inputs.add(r.readVarBytes());
      }
      streams.add(InputStream(netId, firstTick, inputs));
    }
    final actions = <ActionEntry>[];
    for (var n = r.readVarUint(); n > 0; n--) {
      actions.add(
        ActionEntry(
          r.readVarUint(),
          r.readVarUint(),
          r.readUint32(),
          r.readVarUint(),
          r.readVarBytes(),
        ),
      );
    }
    return InputPacket(
      clientTick: clientTick,
      reliableAck: reliableAck,
      bulkAck: bulkAck,
      lastSnapshotTick: lastSnapshotTick,
      chunkAck: chunkAck,
      chunkAckBits: chunkAckBits,
      streams: streams,
      actions: actions,
    );
  }
}
