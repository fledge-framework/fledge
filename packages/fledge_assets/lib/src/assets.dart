import 'handle.dart';
import 'loader.dart';

/// Internal storage for a single asset entry inside [Assets].
class AssetEntry<T> {
  /// The loaded asset value, or `null` while an async load is still
  /// running.
  T? value;

  /// Number of live [Handle] shares currently referencing this entry.
  int refCount;

  /// Source path this entry was loaded from, if any. Populated by
  /// [Assets.load]; `null` for entries created via [Assets.add].
  String? path;

  /// Loader used to (re)load this entry from [path]. Retained so
  /// [Assets.reload] can rebuild the value after a hot-reload event.
  Loader<T>? loader;

  /// Diagnostic label, mirrored onto the [HandleId] for readable logs.
  String debugLabel;

  /// The error thrown by the last [loader] run for this entry, or `null`
  /// if it succeeded (or hasn't finished). Cleared by a later successful
  /// load or reload.
  Object? error;

  /// The stack trace of [error], when one was captured.
  StackTrace? stackTrace;

  AssetEntry({
    this.value,
    this.refCount = 1,
    this.path,
    this.loader,
    this.debugLabel = '',
  });
}

/// A per-type asset store, held as an ECS resource.
///
/// [Assets] maps [HandleId] -> [AssetEntry] and tracks the reference
/// count for each entry. Entries are minted via [add] (for assets you
/// already have in memory) or [load] (for asynchronous file-backed
/// loads through a [Loader]).
///
/// The store is intentionally asset-type-agnostic — `Assets<Texture>`,
/// `Assets<AudioClip>`, `Assets<Tilemap>` all share the same shape.
class Assets<T> {
  /// Live entries by id. Entries whose ref count drops to zero are
  /// removed here.
  final Map<HandleId, AssetEntry<T>> _entries = <HandleId, AssetEntry<T>>{};

  /// Path -> HandleId map used by [load] to dedupe: a second load of
  /// the same path returns a fresh [Handle] onto the existing entry.
  final Map<String, HandleId> _pathIndex = <String, HandleId>{};

  /// Ids waiting for a hot-reload watcher tick. `null` unless
  /// something registered a callback that touched this store; kept as
  /// an internal set so the AssetPlugin's poll system can drain it.
  final Set<HandleId> _dirtyReloads = <HandleId>{};

  /// Next available numeric id. Id 0 is reserved for callers that want
  /// a stable well-known entry (e.g. a 1x1 solid-color texture); use
  /// [addWithId] to write it.
  int _nextId = 1;

  /// Register an already-loaded [asset]. Returns a fresh [Handle] with
  /// refcount 1.
  Handle<T> add(T asset, {String debugLabel = ''}) {
    final id = HandleId(_nextId++, debugLabel: debugLabel);
    _entries[id] = AssetEntry<T>(
      value: asset,
      refCount: 1,
      debugLabel: debugLabel,
    );
    return Handle<T>.internal(id, this);
  }

  /// Register [asset] under a caller-supplied [id]. Used for reserved
  /// slots such as a 1x1 solid-color texture. Throws if [id.id] is
  /// already in use.
  ///
  /// The returned [Handle] carries refcount 1.
  Handle<T> addWithId(HandleId id, T asset, {String debugLabel = ''}) {
    if (_entries.containsKey(id)) {
      throw StateError('Assets<$T> already has an entry for $id.');
    }
    _entries[id] = AssetEntry<T>(
      value: asset,
      refCount: 1,
      debugLabel: debugLabel.isEmpty ? id.debugLabel : debugLabel,
    );
    // Bump the id counter past any manually reserved slot so future
    // `add` calls don't collide.
    if (id.id >= _nextId) _nextId = id.id + 1;
    return Handle<T>.internal(id, this);
  }

  /// Called with the path, error and stack trace whenever a [load] or
  /// [reload] fails. `null` (the default) reports nothing beyond
  /// [error]; set it to log or surface failures.
  void Function(String path, Object error, StackTrace stackTrace)? onLoadError;

  /// Begin an asynchronous load of [path] through [loader]. Returns a
  /// [Handle] immediately, whose `get()` returns `null` until the
  /// loader completes.
  ///
  /// If the loader throws, the value stays `null`, the error is kept
  /// for [error] / [hasError] (and `Handle.error`), and [onLoadError] is
  /// called. The returned future of the loader never surfaces as an
  /// unhandled error.
  ///
  /// Loading the same [path] twice returns a fresh [Handle] onto the
  /// existing entry (dedup) — refcount is bumped rather than a second
  /// loader invocation being kicked off.
  Handle<T> load(String path, Loader<T> loader, {String debugLabel = ''}) {
    final existing = _pathIndex[path];
    if (existing != null && _entries.containsKey(existing)) {
      _entries[existing]!.refCount++;
      return Handle<T>.internal(existing, this);
    }
    final id = HandleId(_nextId++, debugLabel: debugLabel);
    _entries[id] = AssetEntry<T>(
      value: null,
      refCount: 1,
      path: path,
      loader: loader,
      debugLabel: debugLabel,
    );
    _pathIndex[path] = id;
    // Fire the async load. A failure leaves the value null and is
    // recorded on the entry (see [error]) and reported to [onLoadError].
    _run(id, path, loader);
    return Handle<T>.internal(id, this);
  }

  Future<void> _run(HandleId id, String path, Loader<T> loader) async {
    try {
      final v = await loader.load(path);
      // Entry may have been dropped while we were awaiting.
      final current = _entries[id];
      if (current != null) {
        current
          ..value = v
          ..error = null
          ..stackTrace = null;
      }
    } catch (e, st) {
      final current = _entries[id];
      if (current != null) {
        current
          ..error = e
          ..stackTrace = st;
      }
      onLoadError?.call(path, e, st);
    }
  }

  /// The error from the last failed load or reload of [id], or `null`
  /// if it loaded (or is still loading, or doesn't exist).
  Object? error(HandleId id) => _entries[id]?.error;

  /// Whether the last load or reload of [id] failed. A failed reload
  /// keeps the previous value, so an entry can be both [ready] and
  /// failed.
  bool hasError(HandleId id) => _entries[id]?.error != null;

  /// The current value for [id], or `null` if the entry is missing or
  /// still loading.
  T? get(HandleId id) => _entries[id]?.value;

  /// Whether [id] refers to a resolved (non-null) asset.
  bool ready(HandleId id) => _entries[id]?.value != null;

  /// The current reference count for [id], or 0 if no entry exists.
  int refCount(HandleId id) => _entries[id]?.refCount ?? 0;

  /// Increment the reference count for [id]. Used by [Handle.clone].
  ///
  /// No-op if the entry has already been dropped (protects against
  /// use-after-free in racy shutdown paths).
  void incrementRef(HandleId id) {
    final entry = _entries[id];
    if (entry == null) return;
    entry.refCount++;
  }

  /// Decrement the reference count for [id]. When the count reaches
  /// zero the entry is removed from the store.
  ///
  /// Used by [Handle.drop].
  void decrementRef(HandleId id) {
    final entry = _entries[id];
    if (entry == null) return;
    entry.refCount--;
    if (entry.refCount <= 0) {
      _entries.remove(id);
      if (entry.path != null) _pathIndex.remove(entry.path);
      _dirtyReloads.remove(id);
    }
  }

  /// Reload the entry for [id] from its origin [Loader]. Invoked by
  /// the hot-reload watcher; safe to call directly in tests.
  ///
  /// No-op if the entry does not exist, was created via [add] (no
  /// path), or has no associated loader.
  Future<void> reload(HandleId id) async {
    final entry = _entries[id];
    if (entry == null) return;
    final loader = entry.loader;
    final path = entry.path;
    if (loader == null || path == null) return;
    // A failure keeps the previous value and is recorded like [load]'s.
    await _run(id, path, loader);
  }

  /// All live handle ids in the store.
  Iterable<HandleId> get all => _entries.keys;

  /// Look up the [HandleId] currently associated with [path], if any.
  /// Used by the hot-reload watcher to translate a file-system event
  /// back into a handle.
  HandleId? findByPath(String path) => _pathIndex[path];

  /// Mark [id] as needing a reload. Called by the hot-reload watcher
  /// when the file it points at changes. The poll system drains this
  /// set via [drainDirtyReloads].
  void markDirty(HandleId id) {
    if (_entries.containsKey(id)) _dirtyReloads.add(id);
  }

  /// Drain and return the set of dirty ids currently waiting for a
  /// reload. Called by [HotReloadPollSystem]; not intended for user
  /// code.
  List<HandleId> drainDirtyReloads() {
    if (_dirtyReloads.isEmpty) return const <HandleId>[];
    final ids = _dirtyReloads.toList(growable: false);
    _dirtyReloads.clear();
    return ids;
  }
}
