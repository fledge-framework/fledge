import 'package:fledge_ecs/fledge_ecs.dart';

import '../connection/protocol_mismatch.dart';

/// What the host does with a disconnected peer's owned entities.
enum OwnedEntityPolicy {
  /// Despawn every entity the peer owned (recursively, with its
  /// children). Default: a leaving player's avatar disappears.
  despawn,

  /// Keep the entities and transfer ownership to the host (`ownerId` 0).
  releaseToHost,
}

/// Host: a client finished connecting. It receives the full relevant
/// world state on the next fixed tick.
class NetPeerConnected {
  /// The new peer's id.
  final int peerId;

  const NetPeerConnected(this.peerId);
}

/// Host: a client left (disconnect, timeout or kick). Its owned entities
/// have already been handled according to [policy].
class NetPeerDisconnected {
  /// The departed peer's id.
  final int peerId;

  /// Human-readable reason (never contains secrets).
  final String reason;

  /// Network ids of the entities the peer owned when it left.
  final List<int> ownedNetIds;

  /// What was done with [ownedNetIds].
  final OwnedEntityPolicy policy;

  const NetPeerDisconnected(
    this.peerId,
    this.reason, {
    this.ownedNetIds = const [],
    this.policy = OwnedEntityPolicy.despawn,
  });
}

/// Client: the connection handshake and tick sync completed.
class NetConnected {
  /// Peer id the host assigned to this client.
  final int localPeerId;

  const NetConnected(this.localPeerId);
}

/// Client or host: the session ended (or failed after connecting).
///
/// On a client, every replicated entity has been despawned.
class NetDisconnected {
  /// Human-readable reason (never contains secrets).
  final String reason;

  const NetDisconnected(this.reason);
}

/// A datagram from a peer speaking another protocol version.
class NetProtocolMismatch {
  /// Details (local and remote versions, source address).
  final ProtocolMismatchEvent details;

  const NetProtocolMismatch(this.details);
}

/// Category of a [NetRejected] event.
enum NetRejectionKind {
  /// Input for an entity the peer does not own.
  input,

  /// RPC targeting an entity the peer does not own.
  rpc,

  /// A message a client is not allowed to send (e.g. a spawn).
  message,
}

/// Host: a client sent something it is not authorised to send. The data
/// was dropped; nothing in the world changed.
class NetRejected {
  /// Offending peer.
  final int peerId;

  /// What was rejected.
  final NetRejectionKind kind;

  /// Network id the client targeted (0 if none / unknown).
  final int netId;

  /// Why it was rejected (never contains payload data or secrets).
  final String reason;

  const NetRejected(this.peerId, this.kind, this.netId, this.reason);

  @override
  String toString() =>
      'NetRejected(peer $peerId, ${kind.name}, netId $netId: $reason)';
}

/// An RPC of type [T] arrived.
///
/// On the host [sender] is the client's peer id; on a client it is `0`
/// (the host). [target] is the targeted entity resolved locally, or
/// `null` if the RPC had no target (or the target is not known here).
class NetRpcReceived<T> {
  /// Sending peer id (`0` = host).
  final int sender;

  /// Decoded payload.
  final T value;

  /// Network id of the targeted entity, `0` if untargeted.
  final int targetNetId;

  /// Local entity for [targetNetId], if any.
  final Entity? target;

  const NetRpcReceived({
    required this.sender,
    required this.value,
    this.targetNetId = 0,
    this.target,
  });
}

/// Client: a replicated entity was spawned locally.
class NetEntitySpawned {
  /// The local entity.
  final Entity entity;

  /// Its network id.
  final int netId;

  const NetEntitySpawned(this.entity, this.netId);
}

/// Client: a replicated entity was despawned locally (host despawn or it
/// left this client's interest set).
class NetEntityDespawned {
  /// The (now dead) local entity.
  final Entity entity;

  /// Its network id.
  final int netId;

  const NetEntityDespawned(this.entity, this.netId);
}

/// Client: the host's state for a predicted entity differed from the
/// prediction beyond tolerance; the state was reset to the server's and
/// unacknowledged inputs were replayed.
class NetPredictionCorrected {
  /// The corrected entity.
  final Entity entity;

  /// Its network id.
  final int netId;

  /// Server tick the correction was based on.
  final int tick;

  /// Prediction error reported by the registered `error` function.
  final double error;

  const NetPredictionCorrected(this.entity, this.netId, this.tick, this.error);
}
