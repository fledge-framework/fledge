/// Marker component: replicate this host entity to clients.
///
/// Add it on the **host** (it is ignored on clients). On the next fixed
/// tick the replication layer assigns a network id, inserts a
/// `NetworkIdentity` (`ownerId` = [owner], `hasAuthority` = `true`), and
/// spawns the entity, with every registered component it has, on each
/// client it is relevant to. Removing the marker or despawning the entity
/// despawns it on clients.
///
/// After the first tick, `NetworkIdentity.ownerId` is the source of truth
/// for ownership; change it there to transfer ownership (clients are
/// told reliably). [owner] is only read when the network id is assigned.
///
/// ```dart
/// final vehicle = world.spawn()
///   ..insert(Replicated(alwaysRelevant: true))
///   ..insert(Position(0, 0));
/// final avatar = world.spawn()
///   ..insert(Replicated(owner: peerId))
///   ..insert(Position(1, 0)); // local to the vehicle
/// world.setParent(avatar.entity, vehicle.entity);
/// ```
class Replicated {
  /// Peer id that owns (controls) this entity: `0` for the host, or a
  /// client's peer id. Owners may send inputs and targeted RPCs for the
  /// entity; everyone else is rejected.
  final int owner;

  /// Send this entity to every client regardless of `interestRadius`.
  bool alwaysRelevant;

  Replicated({this.owner = 0, this.alwaysRelevant = false});
}
