import 'dart:async';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:watcher/watcher.dart';

import 'assets.dart';
import 'handle.dart';

/// Whether this platform has `dart:io` (and so native file watching).
/// False on the web.
const bool _fileWatchingSupported = bool.fromEnvironment('dart.library.io');

/// Watches the filesystem for changes to files backing [Assets] entries
/// and marks those entries dirty for [HotReloadPollSystem] to reload on
/// the next tick.
///
/// The flow is: a file changes on disk, the watcher calls
/// [Assets.markDirty] for every entry registered against that path with
/// [watch], and on the next frame [HotReloadPollSystem] drains each
/// store's dirty set ([Assets.drainDirtyReloads]) and starts an
/// [Assets.reload] for each entry. The reload finishes in the background;
/// its value (or error, see [Assets.onLoadError]) lands on the entry when
/// the loader completes.
///
/// The watcher is a native-only convenience. Where `dart:io` file
/// watching isn't available (the web) [watch] and [watchWithCallback]
/// start no native watcher: the registration is kept (so [debugFireChange]
/// still works) but no file event ever arrives, and the rest of the engine
/// keeps working as if hot reload were disabled. A platform whose watcher
/// fails to start behaves the same way.
///
/// Normally created by [AssetPlugin] with `enableHotReload: true`.
class HotReloadWatcher {
  /// Directory watchers, keyed by the parent directory. Watchers only
  /// fire for the directory they watch, so multiple assets under the
  /// same directory share a single native watcher.
  final Map<String, StreamSubscription<WatchEvent>> _dirSubs = {};

  /// Per-path handlers, run synchronously when the filesystem reports a
  /// change on `path`. [watch] registers one that marks an entry dirty;
  /// [watchWithCallback] one that queues its callback onto [_pending].
  final Map<String, List<void Function()>> _pathHandlers = {};

  /// Every store passed to [watch], drained by [HotReloadPollSystem].
  final Set<Assets<dynamic>> _stores = {};

  /// Custom callbacks queued by file-system events. Drained by
  /// [HotReloadPollSystem.run].
  final List<Future<void> Function()> _pending = [];

  /// Called with the error and stack trace when a [watchWithCallback]
  /// callback fails. When `null` (the default) the error is reported to
  /// the current zone as an uncaught error. Asset reloads started for
  /// [watch] registrations never reach this: their errors are recorded on
  /// the entry and reported through [Assets.onLoadError].
  void Function(Object error, StackTrace stackTrace)? onCallbackError;

  /// Register a file [path] so that changes to it mark [id] dirty on
  /// [assets]; [HotReloadPollSystem] then reloads it on the next tick.
  ///
  /// A no-op as far as file events go where `dart:io` file watching isn't
  /// available (e.g. web) or the native watcher fails to start.
  void watch<T>(String path, Assets<T> assets, HandleId id) {
    _stores.add(assets);
    _pathHandlers.putIfAbsent(path, () => []).add(() => assets.markDirty(id));
    _startWatcherFor(path);
  }

  /// Register an arbitrary [callback] to run when [path] changes on
  /// disk. Handy for tests and for custom reload behaviour on top of
  /// [Assets.reload]. [HotReloadPollSystem] starts the callback during
  /// its next run without awaiting it; failures go to [onCallbackError].
  void watchWithCallback(String path, Future<void> Function() callback) {
    _pathHandlers.putIfAbsent(path, () => []).add(() => _pending.add(callback));
    _startWatcherFor(path);
  }

  void _startWatcherFor(String path) {
    if (!_fileWatchingSupported) return;
    try {
      final dir = _dirnameOf(path);
      if (_dirSubs.containsKey(dir)) return;
      final watcher = DirectoryWatcher(dir);
      final sub = watcher.events.listen(_onEvent, onError: (Object _) {});
      _dirSubs[dir] = sub;
    } catch (_) {
      // Silent — filesystem watching unavailable on this platform.
    }
  }

  /// Stop watching a previously registered path. Idempotent.
  void unwatch(String path) {
    _pathHandlers.remove(path);
  }

  /// Stop every watcher this instance owns. Used on cleanup.
  Future<void> dispose() async {
    final subs = _dirSubs.values.toList();
    _dirSubs.clear();
    _pathHandlers.clear();
    _stores.clear();
    _pending.clear();
    for (final sub in subs) {
      await sub.cancel();
    }
  }

  /// The stores registered through [watch].
  Iterable<Assets<dynamic>> get watchedStores => _stores;

  /// Drain and return the queued [watchWithCallback] callbacks. Called by
  /// [HotReloadPollSystem].
  List<Future<void> Function()> drainPending() {
    if (_pending.isEmpty) return const [];
    final out = List<Future<void> Function()>.of(_pending, growable: false);
    _pending.clear();
    return out;
  }

  /// Test helper: pretend a file changed on disk, so tests don't need
  /// a real filesystem watcher (which is racy on macOS in CI).
  void debugFireChange(String path) => _onEvent(
    WatchEvent(
      ChangeType.MODIFY,
      // Absolute path for realism; the matcher below falls back to
      // basename comparison so relative registrations still work.
      path,
    ),
  );

  void _onEvent(WatchEvent event) {
    final direct = _pathHandlers[event.path];
    if (direct != null) {
      for (final handler in List.of(direct)) {
        handler();
      }
      return;
    }
    // Fallback for a relative registration and an absolute event (or the
    // other separator): the event's normalised path must equal the key's
    // or end with it at a separator, so `a/tree.png` changing never reloads
    // `b/tree.png`, as matching basenames alone did.
    final changed = _normalise(event.path);
    final matches = [
      for (final MapEntry(:key, :value) in _pathHandlers.entries)
        if (_sameFile(changed, _normalise(key))) ...value,
    ];
    for (final handler in matches) {
      handler();
    }
  }

  static bool _sameFile(String changed, String registered) {
    if (registered.isEmpty) return false;
    if (changed == registered) return true;
    if (registered.startsWith('/')) return false; // absolute: exact only
    return changed.endsWith('/$registered');
  }

  /// [path] with forward slashes, no `./` segments and no doubled slashes.
  static String _normalise(String path) {
    final parts = path.replaceAll(r'\', '/').split('/');
    final kept = <String>[
      for (var i = 0; i < parts.length; i++)
        if (!(parts[i] == '.' || (parts[i].isEmpty && i > 0))) parts[i],
    ];
    return kept.join('/');
  }

  /// Index of the last path separator in [path], accepting both a slash
  /// and a backslash, so it needs no `dart:io` (which throws on the web).
  static int _lastSeparator(String path) {
    final slash = path.lastIndexOf('/');
    final backslash = path.lastIndexOf(r'\');
    return slash > backslash ? slash : backslash;
  }

  static String _dirnameOf(String path) {
    final idx = _lastSeparator(path);
    if (idx <= 0) return '.';
    return path.substring(0, idx);
  }
}

/// Runs each frame in [Schedules.first] (phase [FirstSets.content]) to
/// start the reloads hot reload asks for. Registered automatically by
/// [AssetPlugin] when `enableHotReload: true`.
///
/// Each run drains the dirty set ([Assets.drainDirtyReloads]) of every
/// store the [watcher] watches and of every `Assets` resource in the
/// world, and starts an [Assets.reload] for each dirty entry. It also
/// starts any queued [HotReloadWatcher.watchWithCallback] callbacks.
///
/// The system is synchronous: it starts that work without awaiting it,
/// so a reload never holds up the frame. The reloaded value replaces the
/// old one when the loader completes; a failed reload keeps the old value
/// and records the error on the entry ([Assets.error], reported through
/// [Assets.onLoadError]). A frame with nothing dirty starts no async
/// work.
class HotReloadPollSystem implements System {
  final HotReloadWatcher watcher;

  HotReloadPollSystem(this.watcher);

  /// The `SystemMeta.name` of [HotReloadPollSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'hotReloadPoll';

  @override
  SystemMeta get meta =>
      const SystemMeta(name: systemName, sets: [FirstSets.content]);

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    for (final callback in watcher.drainPending()) {
      unawaited(_runCallback(callback));
    }
    final seen = <Assets<dynamic>>{};
    for (final store in watcher.watchedStores) {
      if (seen.add(store)) _reloadDirty(store);
    }
    for (final store in world.resourcesOfType<Assets<dynamic>>()) {
      if (seen.add(store)) _reloadDirty(store);
    }
  }

  static void _reloadDirty(Assets<dynamic> store) {
    for (final id in store.drainDirtyReloads()) {
      // reload records failures on the entry and never throws.
      unawaited(store.reload(id));
    }
  }

  Future<void> _runCallback(Future<void> Function() callback) async {
    try {
      await callback();
    } catch (e, st) {
      final onError = watcher.onCallbackError;
      if (onError != null) {
        onError(e, st);
      } else {
        Zone.current.handleUncaughtError(e, st);
      }
    }
  }
}
