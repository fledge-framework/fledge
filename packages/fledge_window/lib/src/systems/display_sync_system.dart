import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:screen_retriever/screen_retriever.dart' hide Display;

import '../events/window_events.dart';
import '../resources/display_info.dart';
import 'window_event_system.dart';
import 'window_init_system.dart';

/// System that periodically syncs display information.
///
/// This handles monitor connect/disconnect events by polling
/// the display list every few seconds.
///
/// Runs in the [FirstSets.platform] phase of `Schedules.first`, after
/// [WindowInitSystem] (which populates [DisplayInfo] on the first frame)
/// and before [WindowEventSystem] (which reads [DisplayInfo] when
/// applying mode/size requests).
class DisplaySyncSystem implements System {
  /// The `SystemMeta.name` of [DisplaySyncSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'DisplaySyncSystem';

  DateTime _lastSync = DateTime.now();

  /// How often to sync display information.
  static const _syncInterval = Duration(seconds: 5);

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    sets: [FirstSets.platform],
    after: [WindowInitSystem.systemName],
    resourceWrites: {DisplayInfo},
    eventWrites: {WindowOperationFailed},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  /// A display query in flight, started by an earlier frame.
  Future<_DisplayQuery>? _query;

  /// The finished query, waiting for the next frame to apply it.
  _DisplayQuery? _result;

  @override
  Future<void> run(World world) async {
    // Never awaits the platform: a tick that waits on a platform call
    // stalls until a later turn of the event loop, so the frame is drawn
    // before the tick's movement has happened and the next frame shows
    // two steps at once. The query runs in the background; its result is
    // applied on the first frame after it arrives.
    final result = _result;
    if (result != null) {
      _result = null;
      _apply(world, result);
    }
    if (_query != null) return;
    final now = DateTime.now();
    if (now.difference(_lastSync) < _syncInterval) return;
    _lastSync = now;

    final displayInfo = world.getResource<DisplayInfo>();
    if (displayInfo == null || !displayInfo.isInitialized) return;

    _query = _fetch().then((query) {
      _result = query;
      _query = null;
      return query;
    });
  }

  /// Asks the platform for its displays. If the backend throws
  /// (disconnected monitor mid-enumeration, permission revoked, etc.) the
  /// query carries the error, and the cached [DisplayInfo] is left intact.
  static Future<_DisplayQuery> _fetch() async {
    try {
      final screenDisplays = await screenRetriever.getAllDisplays();
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      return _DisplayQuery(screenDisplays, primaryDisplay, null);
    } catch (e) {
      return _DisplayQuery(const [], null, e);
    }
  }

  void _apply(World world, _DisplayQuery query) {
    final error = query.error;
    if (error != null) {
      world.eventWriter<WindowOperationFailed>().send(
        WindowOperationFailed(
          operation: 'syncDisplays',
          reason: error.toString(),
        ),
      );
      return;
    }
    final displayInfo = world.getResource<DisplayInfo>();
    if (displayInfo == null || !displayInfo.isInitialized) return;
    final screenDisplays = query.displays;
    final dynamic primaryDisplay = query.primary;

    // Build updated Display objects
    final displays = <Display>[];
    var primaryIndex = 0;

    for (var i = 0; i < screenDisplays.length; i++) {
      final d = screenDisplays[i];
      final isPrimary = d.id == primaryDisplay.id;
      if (isPrimary) primaryIndex = i;

      displays.add(
        Display(
          index: i,
          name: d.name ?? 'Display $i',
          size: Size(d.size.width, d.size.height),
          bounds: Rect.fromLTWH(
            d.visiblePosition?.dx ?? 0,
            d.visiblePosition?.dy ?? 0,
            d.visibleSize?.width ?? d.size.width,
            d.visibleSize?.height ?? d.size.height,
          ),
          scaleFactor: (d.scaleFactor ?? 1.0).toDouble(),
          refreshRate: 60.0,
          isPrimary: isPrimary,
        ),
      );
    }

    // Only update if something changed
    final currentDisplays = displayInfo.displays;
    if (_displaysChanged(currentDisplays, displays)) {
      displayInfo.updateDisplays(displays, primaryIndex);
    }
  }

  bool _displaysChanged(List<Display> current, List<Display> updated) {
    if (current.length != updated.length) return true;

    for (var i = 0; i < current.length; i++) {
      final c = current[i];
      final u = updated[i];

      if (c.name != u.name ||
          c.size != u.size ||
          c.bounds != u.bounds ||
          c.isPrimary != u.isPrimary) {
        return true;
      }
    }

    return false;
  }
}

/// A finished display query: the platform's displays and primary display,
/// or the error it threw.
class _DisplayQuery {
  const _DisplayQuery(this.displays, this.primary, this.error);

  final List<dynamic> displays;
  final dynamic primary;
  final Object? error;
}
