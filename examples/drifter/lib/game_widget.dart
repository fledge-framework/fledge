import 'package:flutter/material.dart' hide Color;
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_save/fledge_save.dart';

import 'components.dart';
import 'game_app.dart';
import 'render/game_painter.dart';
import 'resources.dart';

/// The Drifter game widget.
///
/// Hosts the Fledge `App`, drives it from an `AnimationController` ticker,
/// and pauses when the `InputWidget` loses keyboard focus (click the
/// canvas to resume). `SaveManager.save` + `SaveManager.load` are
/// awaited on the flutter side when the game's `SaveLoadSystem` flips
/// the request flags.
class DrifterWidget extends StatefulWidget {
  const DrifterWidget({super.key, this.saveConfig});

  /// Override the save slot directory — handy for tests.
  final SaveConfig? saveConfig;

  @override
  State<DrifterWidget> createState() => _DrifterWidgetState();
}

class _DrifterWidgetState extends State<DrifterWidget>
    with SingleTickerProviderStateMixin {
  late App _app;
  late AnimationController _ticker;
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChanged);

  World get _world => _app.world;

  @override
  void initState() {
    super.initState();
    _app = buildApp(saveConfig: widget.saveConfig);
    spawnScene(_app);

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_gameLoop);
    // Start paused — ticker only runs while the InputWidget has focus.
  }

  void _onFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (focused && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!focused && _ticker.isAnimating) {
      _ticker.stop();
    }
    setState(() {});
  }

  void _gameLoop() {
    _app.tick();

    // Drain save/load/reset requests produced by SaveLoadSystem.
    final saveManager = _world.getResource<SaveManager>();
    if (saveManager?.saveRequested ?? false) {
      saveManager!.clearSaveRequest();
      // Fire-and-forget; we don't want to block the ticker on disk I/O.
      // Surface success/failure by reading the Future if desired.
      saveManager.save(_world);
    }

    final load = _world.getResource<LoadRequested>();
    if (load?.pending ?? false) {
      load!.pending = false;
      saveManager?.load(_world);
    }

    final reset = _world.getResource<ResetRequested>();
    if (reset?.pending ?? false) {
      reset!.pending = false;
      clearScene(_app);
      spawnScene(_app);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _world.getResource<GameBounds>()!;
    final renderWorld = _world.getResource<RenderWorld>();
    final runScore = _world.getResource<RunScore>()?.value ?? 0;
    final highScore = _world.getResource<HighScore>()?.value ?? 0;
    final isPaused = !_focusNode.hasFocus;
    final totalPickups = _countPickups();

    return InputWidget(
      world: _world,
      focusNode: _focusNode,
      autofocus: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Canvas
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4CAF50), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(bounds.width, bounds.height),
                    painter: renderWorld != null
                        ? DrifterPainter(renderWorld)
                        : null,
                  ),
                  if (isPaused)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _focusNode.requestFocus,
                        child: Container(
                          color: const Color(0xCC000000),
                          alignment: Alignment.center,
                          child: const Text(
                            'Click to play',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // HUD — Wrap so narrow viewports flow the instructions to a
          // second row instead of overflowing.
          DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 14,
            ),
            child: SizedBox(
              width: bounds.width,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _hudChip('Run', '$runScore'),
                  _hudChip('Best', '$highScore'),
                  _hudChip('Pickups left', '$totalPickups'),
                  const Text(
                    'Arrows/WASD · S=save · L=load · R=reset',
                    style: TextStyle(color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudChip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  int _countPickups() {
    var n = 0;
    for (final _
        in _world.query1<Transform2D>(filter: const With<Pickup>()).iter()) {
      n++;
    }
    return n;
  }
}
