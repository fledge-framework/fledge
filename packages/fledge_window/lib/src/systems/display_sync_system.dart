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

  @override
  Future<void> run(World world) async {
    final now = DateTime.now();
    if (now.difference(_lastSync) < _syncInterval) return;
    _lastSync = now;

    final displayInfo = world.getResource<DisplayInfo>();
    if (displayInfo == null || !displayInfo.isInitialized) return;

    // Fetch current display info. If the backend throws (disconnected
    // monitor mid-enumeration, permission revoked, etc.) we leave the
    // cached DisplayInfo intact and emit a failure event instead.
    final List<dynamic> screenDisplays;
    final dynamic primaryDisplay;
    try {
      screenDisplays = await screenRetriever.getAllDisplays();
      primaryDisplay = await screenRetriever.getPrimaryDisplay();
    } catch (e) {
      world.eventWriter<WindowOperationFailed>().send(
        WindowOperationFailed(operation: 'syncDisplays', reason: e.toString()),
      );
      return;
    }

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
