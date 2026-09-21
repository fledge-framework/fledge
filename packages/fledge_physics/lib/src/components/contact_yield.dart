import 'package:fledge_ecs/fledge_ecs.dart';

/// Emitted the step a pair of dynamic bodies starts yielding to each
/// other after sustained contact (see [CollisionConfig.yieldAfter]).
///
/// While the pair is yielding, blocking between them turns off; they
/// pass through each other. A matching [ContactYieldEnded] fires the
/// step they separate.
///
/// Games can subscribe to fire NPC voice lines, telemetry, or debug
/// visualisation:
///
/// ```dart
/// for (final e in world.eventReader<ContactYieldStarted>().read()) {
///   print('${e.entityA} and ${e.entityB} decided to pass through');
/// }
/// ```
class ContactYieldStarted {
  /// One of the two entities that just started yielding. The pair is
  /// unordered — the same event is not also emitted with the entities
  /// swapped.
  final Entity entityA;

  /// The other entity in the pair.
  final Entity entityB;

  const ContactYieldStarted(this.entityA, this.entityB);

  @override
  String toString() => 'ContactYieldStarted($entityA, $entityB)';
}

/// Emitted the step a yielding pair separates and blocking resumes.
///
/// If the same pair re-establishes contact later, contact age starts
/// fresh at zero.
class ContactYieldEnded {
  /// One of the two entities that just stopped yielding.
  final Entity entityA;

  /// The other entity in the pair.
  final Entity entityB;

  const ContactYieldEnded(this.entityA, this.entityB);

  @override
  String toString() => 'ContactYieldEnded($entityA, $entityB)';
}
