import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D;

import 'camera2d.dart';

/// Trauma-based screen shake component.
///
/// Attach to a camera entity alongside `Camera2D` + `Transform2D`.
/// [CameraShakeSystem] decays [trauma] each frame and applies a
/// per-frame offset + rotation scaled by `trauma²`. Use
/// [addTrauma] to bump the shake amount from a game event:
///
/// ```dart
/// world.get<CameraShake>(cameraEntity)!.addTrauma(0.5);
/// ```
///
/// The `trauma²` scaling (from Kasper Kamperman's / Squirrel Eiserloh's
/// GDC talks) makes small hits feel light while big hits feel violent.
class CameraShake {
  /// Current trauma value in `[0, 1]`. Shake magnitude scales as
  /// `trauma * trauma`, so 0.5 trauma produces 25% peak amplitude.
  double trauma;

  /// Trauma units subtracted per second. Default 1.5 gives roughly
  /// 700ms shake for a full 1.0 trauma bump.
  double traumaDecayPerSec;

  /// Maximum horizontal shake offset in world units.
  double maxOffsetX;

  /// Maximum vertical shake offset in world units.
  double maxOffsetY;

  /// Maximum rotation in radians. `0.15 rad ≈ 8.5°`.
  double maxRotationRadians;

  /// RNG seed. Change per shake or leave alone for a deterministic
  /// sequence. Overridable for tests.
  math.Random rng;

  // Internal: last applied delta so we can undo it before writing
  // the new one. Keeps [Transform2D] free of accumulated drift.
  double _lastOffsetX = 0;
  double _lastOffsetY = 0;
  double _lastRotation = 0;

  /// Creates a camera shake component.
  CameraShake({
    this.trauma = 0.0,
    this.traumaDecayPerSec = 1.5,
    this.maxOffsetX = 12.0,
    this.maxOffsetY = 12.0,
    this.maxRotationRadians = 0.15,
    math.Random? rng,
  }) : rng = rng ?? math.Random();

  /// Add [amount] to [trauma], clamped to `[0, 1]`.
  ///
  /// Multiple additions stack — call this whenever an event fires
  /// (explosion, hit, screen flash).
  void addTrauma(double amount) {
    trauma = (trauma + amount).clamp(0.0, 1.0);
  }

  /// Peak shake amplitude currently active (`trauma²`).
  double get intensity => trauma * trauma;
}

/// System that decays trauma and applies per-frame shake to camera
/// [Transform2D]s.
///
/// Runs in `Schedules.postUpdate` **after** [CameraFollowSystem] so
/// shake wobbles the followed-target position rather than fighting
/// with it.
///
/// The system undoes the previous frame's shake before recomputing
/// the new offset — this way `Transform2D.translation` stays the
/// "true" camera position and other systems (follow, save/load) can
/// read/write it without accounting for shake drift.
class CameraShakeSystem implements System {
  final double _fixedDelta;

  /// Optional fixed delta (in seconds). If null the system reads
  /// `WallTime.delta` from the world at run time. Passing a fixed value
  /// makes tests deterministic.
  CameraShakeSystem({double? fixedDelta}) : _fixedDelta = fixedDelta ?? -1;

  @override
  SystemMeta get meta => SystemMeta(
        name: 'CameraShakeSystem',
        writes: {ComponentId.of<Transform2D>()},
        reads: {
          ComponentId.of<CameraShake>(),
          ComponentId.of<Camera2D>(),
        },
        resourceReads: {WallTime},
        after: const ['CameraFollowSystem'],
        before: const ['ParallaxSystem', 'CameraTransitionSystem'],
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final delta = _fixedDelta >= 0
        ? _fixedDelta
        : (world.getResource<WallTime>()?.delta ?? 0.0);

    for (final (_, shake, _, transform)
        in world.query3<CameraShake, Camera2D, Transform2D>().iter()) {
      // Undo last frame's delta first so we never accumulate.
      transform.translation.x -= shake._lastOffsetX;
      transform.translation.y -= shake._lastOffsetY;
      transform.rotation -= shake._lastRotation;

      // Decay trauma. clamp to 0 in case the caller poked a negative.
      shake.trauma =
          (shake.trauma - shake.traumaDecayPerSec * delta).clamp(0.0, 1.0);

      if (shake.trauma <= 0) {
        shake._lastOffsetX = 0;
        shake._lastOffsetY = 0;
        shake._lastRotation = 0;
        continue;
      }

      final intensity = shake.intensity;
      // Random offsets in [-1, 1] scaled by max*intensity. `nextDouble`
      // gives [0,1); mapped to [-1, 1) is close enough.
      final ox =
          shake.maxOffsetX * intensity * (shake.rng.nextDouble() * 2 - 1);
      final oy =
          shake.maxOffsetY * intensity * (shake.rng.nextDouble() * 2 - 1);
      final orot = shake.maxRotationRadians *
          intensity *
          (shake.rng.nextDouble() * 2 - 1);

      transform.translation.x += ox;
      transform.translation.y += oy;
      transform.rotation += orot;

      shake._lastOffsetX = ox;
      shake._lastOffsetY = oy;
      shake._lastRotation = orot;
    }
    return Future.value();
  }
}
