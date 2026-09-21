import 'dart:async';
import 'dart:io';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:watcher/watcher.dart';

import 'assets.dart';
import 'handle.dart';

/// Watches the filesystem for changes to files backing [Assets] entries
/// and queues reload callbacks for [HotReloadPollSystem] to drain on
/// the next tick.
///
/// The watcher is a native-only convenience: on platforms where
/// `package:watcher` cannot construct a real watcher (e.g. web) the
/// watch registration throws internally and the caller silently drops
/// the request. The rest of the engine keeps working as if hot reload
/// were disabled.
///
/// Normally created by [AssetPlugin] with `enableHotReload: true`.
class HotReloadWatcher {
  /// Directory watchers, keyed by the parent directory. Watchers only
  /// fire for the directory they watch, so multiple assets under the
  /// same directory share a single native watcher.
  final Map<String, StreamSubscription<WatchEvent>> _dirSubs = {};

  /// Per-path callbacks. When the filesystem reports a change on
  /// `path`, every callback registered against it is scheduled onto
  /// [_pending] for the poll system to run.
  final Map<String, List<Future<void> Function()>> _pathCallbacks = {};

  /// Pending reload callbacks queued by the file-system events.
  /// Drained by [HotReloadPollSystem.run].
  final List<Future<void> Function()> _pending = [];

  /// Register a file [path] so that changes to it enqueue an
  /// [Assets.reload] call for [id] on [assets].
  ///
  /// Silently ignores errors from starting a native watcher — on
  /// platforms without filesystem watch support (e.g. web) hot reload
  /// is a no-op.
  void watch<T>(String path, Assets<T> assets, HandleId id) {
    _pathCallbacks.putIfAbsent(path, () => []).add(() async {
      assets.markDirty(id);
      await assets.reload(id);
    });
    _startWatcherFor(path);
  }

  /// Register an arbitrary [callback] to run when [path] changes on
  /// disk. Handy for tests and for custom reload behaviour on top of
  /// [Assets.reload]. The callback is awaited by [HotReloadPollSystem]
  /// during the poll pass.
  void watchWithCallback(String path, Future<void> Function() callback) {
    _pathCallbacks.putIfAbsent(path, () => []).add(callback);
    _startWatcherFor(path);
  }

  void _startWatcherFor(String path) {
    final dir = _dirnameOf(path);
    if (_dirSubs.containsKey(dir)) return;
    try {
      final watcher = DirectoryWatcher(dir);
      final sub = watcher.events.listen(_onEvent);
      _dirSubs[dir] = sub;
    } catch (_) {
      // Silent — filesystem watching unavailable on this platform.
    }
  }

  /// Stop watching a previously registered path. Idempotent.
  void unwatch(String path) {
    _pathCallbacks.remove(path);
  }

  /// Stop every watcher this instance owns. Used on cleanup.
  Future<void> dispose() async {
    for (final sub in _dirSubs.values) {
      await sub.cancel();
    }
    _dirSubs.clear();
    _pathCallbacks.clear();
    _pending.clear();
  }

  /// Drain and return the queued reload callbacks. Called by
  /// [HotReloadPollSystem].
  List<Future<void> Function()> drainPending() {
    if (_pending.isEmpty) return const [];
    final out = List<Future<void> Function()>.of(_pending, growable: false);
    _pending.clear();
    return out;
  }

  /// Test helper: pretend a file changed on disk, so tests don't need
  /// a real filesystem watcher (which is racy on macOS in CI).
  void debugFireChange(String path) => _onEvent(WatchEvent(ChangeType.MODIFY,
      // Absolute path for realism; the matcher below falls back to
      // basename comparison so relative registrations still work.
      path));

  void _onEvent(WatchEvent event) {
    final direct = _pathCallbacks[event.path];
    if (direct != null) {
      for (final cb in direct) {
        _pending.add(cb);
      }
      return;
    }
    // Fallback: basename match, in case the caller registered a
    // relative path and the watcher reports an absolute one.
    final baseIndex = event.path.lastIndexOf(Platform.pathSeparator);
    final baseName =
        baseIndex >= 0 ? event.path.substring(baseIndex + 1) : event.path;
    _pathCallbacks.forEach((registered, callbacks) {
      final regBaseIndex = registered.lastIndexOf(Platform.pathSeparator);
      final regBase = regBaseIndex >= 0
          ? registered.substring(regBaseIndex + 1)
          : registered;
      if (regBase == baseName) {
        for (final cb in callbacks) {
          _pending.add(cb);
        }
      }
    });
  }

  static String _dirnameOf(String path) {
    final sep = Platform.pathSeparator;
    final idx = path.lastIndexOf(sep);
    if (idx <= 0) return '.';
    return path.substring(0, idx);
  }
}

/// Runs each frame (in [Schedules.first] by convention) to drain
/// queued reload callbacks from [HotReloadWatcher]. Registered
/// automatically by [AssetPlugin] when `enableHotReload: true`.
class HotReloadPollSystem implements System {
  final HotReloadWatcher watcher;

  HotReloadPollSystem(this.watcher);

  @override
  SystemMeta get meta => const SystemMeta(name: 'hotReloadPoll');

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final callbacks = watcher.drainPending();
    for (final cb in callbacks) {
      await cb();
    }
  }
}
