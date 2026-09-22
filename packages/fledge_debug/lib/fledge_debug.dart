/// Runtime observability for Fledge — FPS, entity count, schedule
/// ordering ambiguities, and debug gizmos for colliders and cameras.
///
/// Phase 9 of the restructure. This package is intentionally
/// **runtime observability only** — a reflection-based inspector
/// (editable component fields, entity tree drilling) is deferred; it
/// needs `@reflectable` codegen + a full `TypeRegistry`, which is
/// bigger than a v0.2 phase.
///
/// ## Contents
///
/// - [DebugConfig] — runtime toggles for every subsystem.
/// - [FrameStats], [SystemStats] — resources.
/// - [FrameStatsSystem], [SystemStatsStartSystem],
///   [SystemStatsEndSystem], [OverlayPopulateSystem] — systems.
/// - [DebugAabbGizmo], [DebugColliderGizmo],
///   [DebugCameraFrustumGizmo], [DebugOverlayEntity] — component
///   markers.
/// - [DebugGizmosLayer] — `CustomPainter` overlay for gizmos.
/// - [DebugPlugin] — one-plugin setup.
/// - [SystemProfilerHook] — reserved callback shape for a future
///   per-system profiler hook (see the README).
library;

export 'src/components/gizmo_marker.dart';
export 'src/debug_plugin.dart';
export 'src/debug_stats_plugin.dart';
export 'src/resources/debug_config.dart';
export 'src/resources/frame_stats.dart';
export 'src/resources/schedule_ordering_report.dart';
export 'src/resources/system_stats.dart';
export 'src/systems/frame_stats_system.dart';
export 'src/systems/overlay_populate_system.dart' show OverlayPopulateSystem;
export 'src/systems/schedule_ordering_report_system.dart';
export 'src/systems/system_stats_system.dart';
export 'src/widgets/debug_gizmos_layer.dart';
