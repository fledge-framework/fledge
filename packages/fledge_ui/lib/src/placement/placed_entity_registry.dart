/// What [PlacedEntityRegistry] needs to know about a record: its id and the
/// map it is on. The rest of the record is the game's.
abstract interface class PlacedRecord {
  /// Unique id (see [PlacedEntityRegistry.allocateId]).
  String get id;

  /// The map it is placed on (the game's opaque map key, as in
  /// `PlacementTile.mapKey`).
  String get mapKey;
}

/// The placed things in the world, per map, plus a deterministic id
/// allocator (generic core).
///
/// Not `Saveable` itself (so `fledge_ui` needs no `fledge_save` dep): the
/// game wraps it in its own saved resource and restores the records and
/// [nextId] from its save. Records are kept in registration order, so
/// iteration (and a save written from it) is deterministic.
///
/// Mutating it is the game's business; the recommended pattern is one
/// writer (a placement-spawn system) plus the save load.
class PlacedEntityRegistry<TRecord extends PlacedRecord> {
  final Map<String, TRecord> _records = {};
  int _nextId = 1;

  /// The number the next [allocateId] uses (>= 1). Settable, for a save
  /// load; values below 1 are clamped to 1.
  int get nextId => _nextId;
  set nextId(int value) => _nextId = value < 1 ? 1 : value;

  /// A fresh id `<prefix>_<n>` and advances the counter. Deterministic: the
  /// same sequence of allocations after the same load gives the same ids.
  /// An allocated id is never handed out again, even if its record is never
  /// registered.
  String allocateId(String prefix) => '${prefix}_${_nextId++}';

  /// Adds [record] (replacing a record with the same id).
  void register(TRecord record) => _records[record.id] = record;

  /// Removes and returns the record [id], or null.
  TRecord? remove(String id) => _records.remove(id);

  /// Removes every record (the counter is kept).
  void clear() => _records.clear();

  /// The record [id], or null.
  TRecord? get(String id) => _records[id];

  /// Whether a record [id] exists.
  bool contains(String id) => _records.containsKey(id);

  /// Every record, in registration order.
  Iterable<TRecord> get records => _records.values;

  /// The records on map [mapKey], in registration order.
  List<TRecord> recordsOn(String mapKey) => [
    for (final record in _records.values)
      if (record.mapKey == mapKey) record,
  ];

  /// Number of records.
  int get length => _records.length;
}
