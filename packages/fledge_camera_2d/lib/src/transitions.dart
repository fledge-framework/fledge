import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';

/// Direction of a [CameraWipeTransition].
enum WipeDirection {
  /// Reveals from the left edge, sweeping to the right.
  leftToRight,

  /// Reveals from the right edge, sweeping to the left.
  rightToLeft,

  /// Reveals from the top, sweeping to the bottom.
  topToBottom,

  /// Reveals from the bottom, sweeping to the top.
  bottomToTop,
}

/// Base type for camera-level fade / wipe transitions.
///
/// Attach as a component to a camera entity; the [CameraTransitionSystem]
/// advances [elapsed] each frame. The widget layer (or a future
/// overlay render node) reads [progress] to draw the transition
/// overlay.
///
/// Named `CameraFadeTransition` / `CameraWipeTransition` (not
/// `FadeTransition` / `WipeTransition`) to avoid clashing with
/// Flutter's `package:flutter/material.dart` widget classes of the
/// same name.
abstract class CameraTransition {
  /// Total duration in seconds.
  double get duration;

  /// Time elapsed since the transition started (seconds).
  double elapsed = 0.0;

  /// Whether the transition should reverse (play "out" instead of
  /// "in"). By default transitions fade / wipe **in**; set to true
  /// to fade / wipe **out**.
  bool reverse = false;

  /// Progress in `[0, 1]`. Zero at start, one when complete.
  double get progress {
    if (duration <= 0) return 1.0;
    return (elapsed / duration).clamp(0.0, 1.0);
  }

  /// Progress with [reverse] applied. Widget code can just read this.
  double get effectiveProgress => reverse ? 1.0 - progress : progress;

  /// Whether the transition has finished.
  bool get isComplete => elapsed >= duration;
}

/// A screen-tinting fade transition.
///
/// The widget layer should render a full-screen rect of [color] at
/// alpha `progress * color.alpha` (or the inverse if [reverse] is
/// set). Set [reverse] to `true` for a "fade out" instead of "fade
/// in".
class CameraFadeTransition extends CameraTransition {
  @override
  final double duration;

  /// Colour used for the fade overlay. Alpha channel is respected —
  /// pass `Color(0xFF000000)` for a solid black fade or
  /// `Color(0x88FF0000)` for a semi-transparent red flash.
  final Color color;

  /// Creates a fade transition.
  CameraFadeTransition({
    required this.duration,
    this.color = const Color(0xFF000000),
    bool reverse = false,
  }) {
    this.reverse = reverse;
  }
}

/// A directional wipe transition.
///
/// The widget layer draws a filled rectangle that grows across the
/// screen along [direction]. Pair a "wipe in" (`reverse = false`) at
/// the start of a scene with a "wipe out" (`reverse = true`) when
/// leaving.
class CameraWipeTransition extends CameraTransition {
  @override
  final double duration;

  /// Direction the wipe sweeps.
  final WipeDirection direction;

  /// Colour of the wiping bar.
  final Color color;

  /// Creates a wipe transition.
  CameraWipeTransition({
    required this.duration,
    this.direction = WipeDirection.leftToRight,
    this.color = const Color(0xFF000000),
    bool reverse = false,
  }) {
    this.reverse = reverse;
  }
}

/// System that advances [CameraTransition.elapsed] each frame.
///
/// Uses `WallTime.delta`. Transitions that hit `isComplete` stay attached
/// (with `progress = 1`) so the game can inspect them and remove
/// them explicitly — this makes it easy to chain transitions or gate
/// game state changes on completion.
class CameraTransitionSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
    name: 'CameraTransitionSystem',
    writes: {},
    reads: {},
    resourceReads: {WallTime},
    after: ['CameraFollowSystem', 'CameraShakeSystem', 'ParallaxSystem'],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final delta = world.getResource<WallTime>()?.delta ?? 0.0;
    if (delta <= 0) return Future.value();

    // Fades.
    for (final (_, fade) in world.query1<CameraFadeTransition>().iter()) {
      if (!fade.isComplete) fade.elapsed += delta;
    }
    // Wipes.
    for (final (_, wipe) in world.query1<CameraWipeTransition>().iter()) {
      if (!wipe.isComplete) wipe.elapsed += delta;
    }
    return Future.value();
  }
}
