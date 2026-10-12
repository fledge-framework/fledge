/// Payload formats of the replication layer (protocol version 3).
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
/// uint16  chunkIndex, uint16 chunkCount
/// varuint entityCount
/// entityCount x { varuint netId, entity state }
/// ```
///
/// Every chunk is self-contained; one entity never spans two chunks.
///
/// ## PacketType.input (client to host, unreliable, every client tick)
///
/// ```
/// uint32  clientTick            local tick at send time
/// uint32  reliableAck           client cumulative ack of the host channel
/// uint32  lastSnapshotTick      newest snapshot tick received
/// varuint streamCount
/// streamCount x {
///   varuint netId               controlled entity
///   uint32  firstTick
///   varuint count               inputs for firstTick .. firstTick+count-1
///   count x { varuint length, bytes }   input codec output
/// }
/// ```
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
/// ```
///
/// Clients may only send `rpc` messages; the host rejects anything else.
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

/// Snapshot chunk header.
class SnapshotHeader {
  final int serverTick;
  final int ackInputTick;
  final int reliableAck;
  final int lateInputs;
  final int chunkIndex;
  final int chunkCount;

  const SnapshotHeader({
    required this.serverTick,
    required this.ackInputTick,
    required this.reliableAck,
    required this.lateInputs,
    required this.chunkIndex,
    required this.chunkCount,
  });

  /// Upper bound of the encoded size (excluding the entity count).
  static const int maxBytes = 4 + 4 + 4 + 5 + 2 + 2;

  void write(PacketBuilder out) {
    out
      ..writeUint32(serverTick)
      ..writeUint32(ackInputTick)
      ..writeUint32(reliableAck)
      ..writeVarUint(lateInputs)
      ..writeUint16(chunkIndex)
      ..writeUint16(chunkCount);
  }

  static SnapshotHeader read(PacketReader input) => SnapshotHeader(
    serverTick: input.readUint32(),
    ackInputTick: input.readUint32(),
    reliableAck: input.readUint32(),
    lateInputs: input.readVarUint(),
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

/// Decoded input packet.
class InputPacket {
  final int clientTick;
  final int reliableAck;
  final int lastSnapshotTick;
  final List<InputStream> streams;

  const InputPacket({
    required this.clientTick,
    required this.reliableAck,
    required this.lastSnapshotTick,
    required this.streams,
  });

  Uint8List encode() {
    final out = PacketBuilder()
      ..writeUint32(clientTick)
      ..writeUint32(reliableAck)
      ..writeUint32(lastSnapshotTick)
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
    return out.build();
  }

  static InputPacket decode(Uint8List payload) {
    final r = PacketReader(payload);
    final clientTick = r.readUint32();
    final reliableAck = r.readUint32();
    final lastSnapshotTick = r.readUint32();
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
    return InputPacket(
      clientTick: clientTick,
      reliableAck: reliableAck,
      lastSnapshotTick: lastSnapshotTick,
      streams: streams,
    );
  }
}
