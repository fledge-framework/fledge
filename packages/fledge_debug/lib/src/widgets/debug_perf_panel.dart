import 'dart:ui' show FramePhase, FrameTiming;

import 'package:fledge_ecs/fledge_ecs.dart' show App;
import 'package:fledge_render_2d/fledge_render_2d.dart' show RenderWorld;
import 'package:flutter/scheduler.dart' show SchedulerBinding, Ticker;
import 'package:flutter/widgets.dart';

import '../resources/frame_stats.dart';
import '../resources/system_stats.dart';

/// A Flutter performance panel, for games that draw their UI in Flutter
/// rather than `fledge_ui`.
///
/// Shows, refreshed a few times a second so the numbers stay readable:
///
/// - **FPS** and frame time (average, p99, worst) from [FrameStats];
/// - **tick**: time spent in the app's schedules from `first` to `last`,
///   from [SystemStats];
/// - **build / raster**: Flutter's own per-frame cost on the UI and raster
///   threads, and how many recent frames missed their display refresh;
/// - **entities** and **sprites** extracted for drawing.
///
/// Under the text, a graph of recent frame times against the display's
/// refresh interval. Install [DebugStatsPlugin] (or [DebugPlugin]) so the
/// stats resources exist; without them those lines are skipped.
///
/// ```dart
/// Stack(children: [
///   FledgeRenderView(app: app),
///   if (showPerf) Positioned(top: 8, left: 8, child: DebugPerfPanel(app: app)),
/// ])
/// ```
class DebugPerfPanel extends StatefulWidget {
  /// The app whose stats to show.
  final App app;

  /// How often the text refreshes. The graph redraws every frame.
  final Duration refreshInterval;

  /// Text style for the readout; a small monospace style by default.
  final TextStyle? textStyle;

  /// Creates a performance panel for [app].
  const DebugPerfPanel({
    super.key,
    required this.app,
    this.refreshInterval = const Duration(milliseconds: 250),
    this.textStyle,
  });

  @override
  State<DebugPerfPanel> createState() => _DebugPerfPanelState();
}

class _DebugPerfPanelState extends State<DebugPerfPanel>
    with SingleTickerProviderStateMixin {
  static const _timingCap = 120;

  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  final List<FrameTiming> _timings = [];
  Duration _lastText = Duration.zero;
  List<String> _lines = const [];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _ticker = createTicker(_onTick)..start();
    _lines = _readout();
  }

  @override
  void dispose() {
    _ticker.dispose();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _repaint.dispose();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    _timings.addAll(timings);
    if (_timings.length > _timingCap) {
      _timings.removeRange(0, _timings.length - _timingCap);
    }
  }

  void _onTick(Duration elapsed) {
    _repaint.value++;
    if (elapsed - _lastText >= widget.refreshInterval) {
      _lastText = elapsed;
      setState(() => _lines = _readout());
    }
  }

  double get _refreshMs {
    final hz = View.maybeOf(context)?.display.refreshRate ?? 60;
    return 1000 / (hz > 0 ? hz : 60);
  }

  static String _ms(double ms) => ms.toStringAsFixed(1);

  List<String> _readout() {
    final world = widget.app.world;
    final lines = <String>[];
    final frames = world.getResource<FrameStats>();
    if (frames != null && frames.sampleCount > 0) {
      lines
        ..add('FPS ${frames.smoothedFps.toStringAsFixed(0)}')
        ..add(
          'frame ${_ms(frames.avgFrameSeconds * 1000)} ms  '
          'p99 ${_ms(frames.p99FrameSeconds * 1000)}  '
          'max ${_ms(frames.maxFrameSeconds * 1000)}',
        );
    }
    final systems = world.getResource<SystemStats>();
    if (systems != null && systems.totalFrameMicros > 0) {
      lines.add('tick ${_ms(systems.totalFrameMilliseconds)} ms');
    }
    if (_timings.isNotEmpty) {
      var build = 0.0, raster = 0.0;
      var missed = 0;
      final slot = _refreshMs * 1000;
      for (final t in _timings) {
        build += t.buildDuration.inMicroseconds;
        raster += t.rasterDuration.inMicroseconds;
        final span =
            t.timestampInMicroseconds(FramePhase.rasterFinish) -
            t.timestampInMicroseconds(FramePhase.vsyncStart);
        if (span > slot) missed++;
      }
      final n = _timings.length;
      lines
        ..add(
          'build ${_ms(build / n / 1000)} ms  '
          'raster ${_ms(raster / n / 1000)} ms',
        )
        ..add('late frames $missed/$n');
    }
    final sprites = world.getResource<RenderWorld>()?.extractedSpriteCount;
    lines.add(
      'entities ${world.entityCount}'
      '${sprites == null ? '' : '  sprites $sprites'}',
    );
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.textStyle ??
        const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.3,
        );
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xB0000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in _lines) Text(line, style: style),
            const SizedBox(height: 4),
            CustomPaint(
              size: const Size(180, 40),
              painter: _FrameGraphPainter(
                repaint: _repaint,
                history: () =>
                    widget.app.world.getResource<FrameStats>()?.history ??
                    const [],
                refreshMs: _refreshMs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bars of recent frame times, newest on the right. The line marks one
/// display refresh; bars past two refreshes turn red.
class _FrameGraphPainter extends CustomPainter {
  _FrameGraphPainter({
    required Listenable repaint,
    required this.history,
    required this.refreshMs,
  }) : super(repaint: repaint);

  final List<double> Function() history;
  final double refreshMs;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x40FFFFFF),
    );
    final samples = history();
    // The graph spans three refreshes, so one-refresh frames sit a third
    // of the way up and missed refreshes stand out.
    final top = refreshMs * 3;
    if (samples.isNotEmpty) {
      final width = size.width / samples.length;
      final ok = Paint()..color = const Color(0xFF7BD389);
      final slow = Paint()..color = const Color(0xFFF2C14E);
      final bad = Paint()..color = const Color(0xFFE5534B);
      for (var i = 0; i < samples.length; i++) {
        final ms = samples[i] * 1000;
        final h = (ms / top).clamp(0.0, 1.0) * size.height;
        final paint = ms > refreshMs * 2.1
            ? bad
            : ms > refreshMs * 1.1
            ? slow
            : ok;
        canvas.drawRect(
          Rect.fromLTWH(i * width, size.height - h, width, h),
          paint,
        );
      }
    }
    final y = size.height - size.height / 3;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = const Color(0xA0FFFFFF)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FrameGraphPainter old) =>
      old.refreshMs != refreshMs || old.history != history;
}
