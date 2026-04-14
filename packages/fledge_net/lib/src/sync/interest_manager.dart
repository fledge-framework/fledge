import 'package:fledge_ecs/fledge_ecs.dart';

import 'network_identity.dart';

/// Manages which entities are relevant to each peer for network synchronization.
///
/// By default, uses radius-based relevance — only entities within
/// [relevanceRadius] of a peer's owned entity are synchronized to that peer.
class InterestManager {
  /// Maximum distance for entity relevance.
  ///
  /// Entities beyond this radius from a peer's owned entity are not
  /// synchronized to that peer.
  final double relevanceRadius;

  /// Position getter — extracts (x, y) from an entity.
  ///
  /// Users must provide this since fledge_net doesn't depend on Transform2D.
  final (double, double) Function(World world, Entity entity)? positionGetter;

  InterestManager({
    this.relevanceRadius = 1000,
    this.positionGetter,
  });

  /// Get the set of relevant entity network IDs for a specific peer.
  ///
  /// Returns all netIds if [positionGetter] is null (no spatial filtering).
  Set<int> getRelevantEntities(
    int peerId,
    World world,
    NetworkEntityRegistry registry,
  ) {
    if (positionGetter == null) {
      return registry.entities
          .map((e) => registry.getNetId(e))
          .whereType<int>()
          .toSet();
    }

    // Find the peer's owned entity position
    (double, double)? peerPos;
    for (final entity in registry.entities) {
      final identity = world.get<NetworkIdentity>(entity);
      if (identity != null && identity.ownerId == peerId) {
        peerPos = positionGetter!(world, entity);
        break;
      }
    }

    if (peerPos == null) {
      // Peer has no owned entity — send everything
      return registry.entities
          .map((e) => registry.getNetId(e))
          .whereType<int>()
          .toSet();
    }

    final result = <int>{};
    final radiusSq = relevanceRadius * relevanceRadius;

    for (final entity in registry.entities) {
      final netId = registry.getNetId(entity);
      if (netId == null) continue;

      final pos = positionGetter!(world, entity);
      final dx = pos.$1 - peerPos.$1;
      final dy = pos.$2 - peerPos.$2;
      if (dx * dx + dy * dy <= radiusSq) {
        result.add(netId);
      }
    }

    return result;
  }

  /// Check if a specific entity is relevant to a peer.
  bool isRelevant(
    int peerId,
    int entityNetId,
    World world,
    NetworkEntityRegistry registry,
  ) {
    if (positionGetter == null) return true;

    final entity = registry.getEntity(entityNetId);
    if (entity == null) return false;

    // Find peer's position
    for (final peerEntity in registry.entities) {
      final identity = world.get<NetworkIdentity>(peerEntity);
      if (identity != null && identity.ownerId == peerId) {
        final peerPos = positionGetter!(world, peerEntity);
        final entityPos = positionGetter!(world, entity);
        final dx = entityPos.$1 - peerPos.$1;
        final dy = entityPos.$2 - peerPos.$2;
        return dx * dx + dy * dy <= relevanceRadius * relevanceRadius;
      }
    }

    return true; // Peer has no owned entity — consider all relevant
  }
}
