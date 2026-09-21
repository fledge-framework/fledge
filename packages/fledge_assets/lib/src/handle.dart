import 'package:meta/meta.dart';

import 'assets.dart';

/// A lightweight identifier for an asset entry stored in an [Assets] map.
///
/// Two [HandleId]s are equal when their [id] fields are equal. The
/// [debugLabel] is diagnostic-only — it is not part of the identity —
/// and is preserved through reloads to make hot-reload logs readable.
@immutable
class HandleId {
  /// The unique numeric identifier for this asset entry.
  final int id;

  /// Optional debug label — surfaces in `toString()` and hot-reload
  /// logs. Not part of equality.
  final String debugLabel;

  /// Creates a handle id. In normal use, `Assets<T>` mints these
  /// internally; construct one manually only when interoperating with
  /// legacy id-based APIs.
  const HandleId(this.id, {this.debugLabel = ''});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is HandleId && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      debugLabel.isEmpty ? 'HandleId($id)' : 'HandleId($id, "$debugLabel")';
}

/// Ref-counted handle to an asset stored in an [Assets] resource.
///
/// A [Handle] is a *smart pointer*: it identifies an entry by [id] and
/// carries a share of that entry's reference count. Copying a handle
/// through [clone] increments the count; releasing it through [drop]
/// decrements it. When the count reaches zero the entry (and the
/// underlying asset) is removed from the store.
///
/// **Important**: this matches Bevy's convention — going out of scope
/// does **not** decrement the count, because Dart does not have
/// destructors. User code that stops using a handle must call [drop]
/// to release it, or the entry will leak.
class Handle<T> {
  /// The identifier of the asset this handle refers to.
  final HandleId id;

  /// The [Assets] store that owns the underlying entry.
  final Assets<T> _assets;

  /// Whether this specific handle has already been dropped. Used to
  /// keep `drop` idempotent and prevent double-decrements from
  /// accidentally freeing a still-shared entry.
  bool _dropped = false;

  Handle.internal(this.id, this._assets);

  /// Returns the loaded asset, or `null` if the entry is still
  /// loading, has been dropped, or was never registered.
  T? get() => _assets.get(id);

  /// Whether the underlying entry currently holds a resolved asset.
  bool get isReady => _assets.ready(id);

  /// Decrement the reference count on this handle's entry. Idempotent
  /// per-instance — calling `drop` twice on the same [Handle] is a
  /// no-op after the first call.
  void drop() {
    if (_dropped) return;
    _dropped = true;
    _assets.decrementRef(id);
  }

  /// Return a new [Handle] pointing at the same entry, bumping the
  /// ref-count by one. Use this to hand out shared references.
  Handle<T> clone() {
    _assets.incrementRef(id);
    return Handle<T>.internal(id, _assets);
  }

  @override
  String toString() => 'Handle<$T>(${id.toString()})';
}
