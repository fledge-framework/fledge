import 'package:fledge_ecs/fledge_ecs.dart';

/// Canonicalised unordered pair key for the yield tracker.
///
/// Combines the two entity ids into one int so both the resolver and
/// the tracker (in separate files) can produce identical keys without
/// sharing a private class. Entity ids in fledge_ecs are `int`, safely
/// fitting into 32 bits for any realistic game, so packing into 64
/// bits is loss-free.
int contactYieldPairKey(Entity a, Entity b) {
  final ax = a.id;
  final bx = b.id;
  final lo = ax <= bx ? ax : bx;
  final hi = ax <= bx ? bx : ax;
  return (hi << 32) | (lo & 0xffffffff);
}

/// Per-pair contact-age bookkeeping for `CollisionConfig.yieldAfter`.
///
/// Owned by `PhysicsPlugin`; games rarely touch it directly. Tests
/// and debug overlays can inspect [isYielding] / [contactAge] to see
/// what the resolver is doing.
///
/// The resolver updates this each step:
///
/// - For every dynamic-vs-dynamic pair currently in contact, [contactAge]
///   accumulates one dt worth of contact time.
/// - When contact age crosses the pair's
///   `min(a.yieldAfter, b.yieldAfter)` threshold, the pair enters the
///   yielding set and a `ContactYieldStarted` event fires.
/// - When a yielding pair separates, it leaves the set and a
///   `ContactYieldEnded` event fires.
class ContactYieldTracker {
  /// Contact age per canonicalised pair key, in seconds.
  final Map<int, double> _contactAge = {};

  /// Pairs currently yielding (post-threshold, still in contact).
  final Set<int> _yielding = {};

  /// The entities the tracker last saw a yielding pair for, keyed by
  /// pair key. Kept so [ContactYieldEnded] events fire with the right
  /// pair of entities on separation.
  final Map<int, (Entity, Entity)> _yieldingEntities = {};

  /// True if [a] and [b] currently pass through each other because
  /// they exceeded their yield threshold. The pair is unordered.
  bool isYielding(Entity a, Entity b) =>
      _yielding.contains(contactYieldPairKey(a, b));

  /// Accumulated contact time (in seconds) between [a] and [b], or
  /// `null` if the pair has no active contact record.
  double? contactAge(Entity a, Entity b) =>
      _contactAge[contactYieldPairKey(a, b)];

  /// Wipe all tracked state. Useful after a scene teardown or a
  /// deterministic replay reset. Does not emit
  /// `ContactYieldEnded` events — call this only when the whole
  /// world is being reset.
  void clear() {
    _contactAge.clear();
    _yielding.clear();
    _yieldingEntities.clear();
  }
}

/// Package-internal handles the resolver uses to mutate the tracker.
/// Kept in the same library as [ContactYieldTracker] so private
/// fields stay reachable without exposing them on the public API.
extension ContactYieldTrackerInternal on ContactYieldTracker {
  Map<int, double> get ageMap => _contactAge;
  Set<int> get yieldingSet => _yielding;
  Map<int, (Entity, Entity)> get yieldingEntities => _yieldingEntities;
}
