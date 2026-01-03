import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:screen_retriever/screen_retriever.dart' hide Display;

import '../resources/display_info.dart';

/// System that periodically syncs display information.
///
/// This handles monitor connect/disconnect events by polling
/// the display list every few seconds.
class DisplaySyncSystem implements System {
  DateTime _lastSync = DateTime.now();

  /// How often to sync display information.
  static const _syncInterval = Duration(seconds: 5);

  @override
  SystemMeta get meta => const SystemMeta(
        name: 'DisplaySyncSystem',
        resourceWrites: {DisplayInfo},
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

    // Fetch current display info
    final screenDisplays = await screenRetriever.getAllDisplays();
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();

    // Build updated Display objects
    final displays = <Display>[];
    var primaryIndex = 0;

    for (var i = 0; i < screenDisplays.length; i++) {
      final d = screenDisplays[i];
      final isPrimary = d.id == primaryDisplay.id;
      if (isPrimary) primaryIndex = i;

      displays.add(Display(
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
      ));
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
