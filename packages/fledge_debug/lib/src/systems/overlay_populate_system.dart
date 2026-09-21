import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/painting.dart' show Alignment;

import '../components/gizmo_marker.dart';
import '../resources/debug_config.dart';
import '../resources/frame_stats.dart';
import '../resources/system_stats.dart';

/// Populates and updates the debug HUD.
///
/// Runs in `Schedules.preUpdate`. That is early enough to see the
/// current frame's `FrameStats` (updated in `Schedules.first`) and
/// leaves the entire `Schedules.update` schedule free of debug UI
/// writes — so a game's own HUD-mutator (e.g. Drifter's
/// `HudUpdateSystem` writing `UiText`) does not collide with the
/// debug plugin's writes and produce a `checkScheduleOrdering()`
/// ambiguity. The `LayoutSystem` from `fledge_ui` runs in
/// `Schedules.postUpdate`, so both this system's mutations and the
/// game's HUD mutations are visible when the layout pass walks the
/// tree in the same tick.
///
/// Retained-mode contract:
///
/// - Each overlay line is an independent UI entity keyed by a short
///   string ([DebugOverlayEntity.key], e.g. `"fps"`, `"ambiguity:2"`).
/// - On each run, the system builds this frame's desired line map,
///   walks existing entities to update text (or leave them alone) and
///   spawn missing ones, then despawns any entity whose key is not in
///   the desired set.
/// - No entity is respawned per frame unless the set of active lines
///   changes — a HUD update is a text mutation in place.
///
/// The lines are laid out top-to-bottom (or bottom-to-top, when the
/// overlay anchors to a bottom edge) using a fixed `fontSize * 1.35`
/// row height. The overlay does not use a `UiContainer` because that
/// would require managing hierarchy each frame; standalone anchored
/// texts are cheaper and give the same visual result for the MVP.
class OverlayPopulateSystem implements System {
  /// Horizontal padding from the anchor edge, in logical pixels.
  static const double kHorizontalPad = 8.0;

  /// Vertical padding from the anchor edge, in logical pixels.
  static const double kVerticalPad = 8.0;

  /// Row-height multiplier applied to `overlayFontSize`.
  static const double kRowHeightFactor = 1.35;

  /// Creates the overlay-populate system.
  const OverlayPopulateSystem();

  @override
  SystemMeta get meta => SystemMeta(
    name: 'debug_overlay_populate',
    reads: {ComponentId.of<DebugOverlayEntity>()},
    writes: {
      ComponentId.of<UiText>(),
      ComponentId.of<UiNode>(),
      ComponentId.of<UiAnchorComponent>(),
      ComponentId.of<UiOffset>(),
      ComponentId.of<UiSize>(),
    },
    resourceReads: {DebugConfig, FrameStats, SystemStats},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final config = world.getResource<DebugConfig>();
    if (config == null) return Future.value();

    final desired = _buildDesiredLines(world, config);

    // Snapshot existing overlay entities before mutating. `query1.iter()`
    // already snapshots but taking our own map here keeps the update
    // logic transparent.
    final existing = <String, Entity>{};
    for (final (entity, marker) in world.query1<DebugOverlayEntity>().iter()) {
      existing[marker.key] = entity;
    }

    final anchor = _alignmentToAnchor(config.overlayAnchor);
    final anchorSign = _anchorVerticalSign(anchor);
    final anchorXSign = _anchorHorizontalSign(anchor);
    final rowHeight = config.overlayFontSize * kRowHeightFactor;

    // Update / spawn lines from the desired order.
    for (var i = 0; i < desired.length; i++) {
      final line = desired[i];
      final entity = existing.remove(line.key);
      final yOffset = kVerticalPad + i * rowHeight;

      if (entity != null) {
        // Update path — mutate the existing UiText.text so retained
        // mode holds up across frames.
        final text = world.get<UiText>(entity);
        if (text != null) {
          text.text = line.text;
        }
        // Overlays can move if the anchor changes at runtime; make sure
        // the offset stays in step with the current line index.
        final offset = world.get<UiOffset>(entity);
        final expectedX = kHorizontalPad * anchorXSign;
        final expectedY = yOffset * anchorSign;
        if (offset == null || offset.x != expectedX || offset.y != expectedY) {
          world.insert(entity, UiOffset(x: expectedX, y: expectedY));
        }
      } else {
        _spawnLine(
          world,
          config,
          anchor,
          line,
          yOffset,
          anchorSign,
          anchorXSign,
        );
      }
    }

    // Anything left in `existing` was not in this frame's desired set
    // — despawn so lines don't linger after a config toggle.
    for (final stale in existing.values) {
      world.despawn(stale);
    }
    return Future.value();
  }

  void _spawnLine(
    World world,
    DebugConfig config,
    UiAnchor anchor,
    _OverlayLine line,
    double yOffset,
    double anchorSign,
    double anchorXSign,
  ) {
    world.spawn()
      ..insert(const UiNode())
      ..insert(UiAnchorComponent(anchor))
      ..insert(
        UiOffset(x: kHorizontalPad * anchorXSign, y: yOffset * anchorSign),
      )
      ..insert(
        UiSize(width: 260, height: config.overlayFontSize * kRowHeightFactor),
      )
      ..insert(
        UiText(
          text: line.text,
          fontSize: config.overlayFontSize,
          color: config.overlayTextColor,
        ),
      )
      ..insert(DebugOverlayEntity(line.key));
  }

  /// Build the frame's line list from the current config and resources.
  ///
  /// The returned order is also the top-to-bottom paint order — keep
  /// the sequence deterministic so the readout doesn't flicker.
  List<_OverlayLine> _buildDesiredLines(World world, DebugConfig config) {
    final lines = <_OverlayLine>[];

    if (config.showFps) {
      final stats = world.getResource<FrameStats>();
      final fps = stats?.smoothedFps ?? 0.0;
      lines.add(
        _OverlayLine(key: 'fps', text: 'FPS: ${fps.toStringAsFixed(1)}'),
      );
    }

    if (config.showEntityCount) {
      lines.add(
        _OverlayLine(
          key: 'entityCount',
          text: 'Entities: ${world.entityCount}',
        ),
      );
    }

    if (config.showSystemTimings) {
      final stats = world.getResource<SystemStats>();
      if (stats != null) {
        lines.add(
          _OverlayLine(
            key: 'frameTime',
            text:
                'Frame: '
                '${stats.totalFrameMilliseconds.toStringAsFixed(2)}ms '
                '(first..last)',
          ),
        );
        // One line per non-empty schedule keeps the readout short in
        // typical apps and never grows unboundedly.
        final counts = stats.scheduleSystemCounts;
        final orderedNames = counts.keys.toList()..sort();
        for (final name in orderedNames) {
          final count = counts[name] ?? 0;
          if (count == 0) continue;
          lines.add(
            _OverlayLine(key: 'schedule:$name', text: '  $name: $count sys'),
          );
        }
      }
    }

    if (config.showOrderingAmbiguities) {
      // Rather than reach through the world for the App instance, the
      // plugin publishes the last-known ambiguity list as an internal
      // resource. Reading it here keeps this system pure with respect
      // to what it depends on.
      final report = world.getResource<_AmbiguityReport>();
      final items = report?.items ?? const <String>[];
      if (items.isNotEmpty) {
        lines.add(
          _OverlayLine(
            key: 'ambiguityHeader',
            text: 'Ambiguities: ${items.length}',
          ),
        );
        for (var i = 0; i < items.length; i++) {
          lines.add(_OverlayLine(key: 'ambiguity:$i', text: '  ${items[i]}'));
        }
      }
    }

    return lines;
  }

  /// Map a Flutter [Alignment] to the nine-way [UiAnchor] enum.
  ///
  /// Only the corners and edge centres round-trip cleanly; anything
  /// else falls back to `topLeft` — matching the doc note on
  /// [DebugConfig.overlayAnchor].
  static UiAnchor _alignmentToAnchor(Alignment a) {
    if (a == Alignment.topLeft) return UiAnchor.topLeft;
    if (a == Alignment.topCenter) return UiAnchor.topCenter;
    if (a == Alignment.topRight) return UiAnchor.topRight;
    if (a == Alignment.centerLeft) return UiAnchor.centerLeft;
    if (a == Alignment.center) return UiAnchor.center;
    if (a == Alignment.centerRight) return UiAnchor.centerRight;
    if (a == Alignment.bottomLeft) return UiAnchor.bottomLeft;
    if (a == Alignment.bottomCenter) return UiAnchor.bottomCenter;
    if (a == Alignment.bottomRight) return UiAnchor.bottomRight;
    return UiAnchor.topLeft;
  }

  /// +1 when the anchor is at the top (rows grow downward), -1 when
  /// bottom-anchored (rows grow upward), 0 for centre.
  static double _anchorVerticalSign(UiAnchor a) {
    switch (a) {
      case UiAnchor.topLeft:
      case UiAnchor.topCenter:
      case UiAnchor.topRight:
        return 1.0;
      case UiAnchor.bottomLeft:
      case UiAnchor.bottomCenter:
      case UiAnchor.bottomRight:
        return -1.0;
      case UiAnchor.centerLeft:
      case UiAnchor.center:
      case UiAnchor.centerRight:
        return 1.0;
    }
  }

  /// +1 for a left anchor, -1 for a right anchor, 0 for a centre one.
  /// Used so the horizontal padding pushes the overlay away from the
  /// viewport edge regardless of anchor.
  static double _anchorHorizontalSign(UiAnchor a) {
    switch (a) {
      case UiAnchor.topLeft:
      case UiAnchor.centerLeft:
      case UiAnchor.bottomLeft:
        return 1.0;
      case UiAnchor.topRight:
      case UiAnchor.centerRight:
      case UiAnchor.bottomRight:
        return -1.0;
      case UiAnchor.topCenter:
      case UiAnchor.center:
      case UiAnchor.bottomCenter:
        return 0.0;
    }
  }
}

/// One computed HUD line. Kept private — the overlay's schema is the
/// public contract on [DebugConfig], not on individual line shapes.
class _OverlayLine {
  final String key;
  final String text;
  const _OverlayLine({required this.key, required this.text});
}

/// Internal resource: the last known list of ordering ambiguities.
///
/// Written by `DebugPlugin`'s startup hook and refreshed on demand.
/// Read (only) by [OverlayPopulateSystem]. Not exported.
class _AmbiguityReport {
  final List<String> items;
  const _AmbiguityReport(this.items);
}

/// Public writer for the internal ambiguity report. `DebugPlugin`
/// calls this after building the schedule so the overlay reflects the
/// current state; games that add plugins later can call it again.
void publishAmbiguityReport(World world, List<String> items) {
  world.insertResource(_AmbiguityReport(List.unmodifiable(items)));
}
