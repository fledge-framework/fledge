/// Ties a placed entity back to its registry record (`PlacedRecord.id`).
///
/// Every entity the game spawns for a placed record carries one, so the
/// game can find (and despawn) placed entities generically, and tell which
/// records already have an entity on the current map.
class PlacedEntityRef {
  final String recordId;

  const PlacedEntityRef(this.recordId);

  @override
  String toString() => 'PlacedEntityRef($recordId)';
}
