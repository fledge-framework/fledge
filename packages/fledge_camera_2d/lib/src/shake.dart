import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';

import 'active_camera_view_system.dart';
import 'camera2d.dart';
import 'follow.dart';
import 'parallax.dart';
import 'transitions.dart';

/// Trauma-based screen shake component.
///
/// Attach to a camera entity alongside `Camera2D`. [CameraShakeSystem]
/// decays [trauma] each frame and picks a random offset ([offsetX],
/// [offsetY]) and [rotationOffset] scaled by `trauma²`. Use [addTrauma] to
/// bump the shake amount from a game event:
///
/// ```dart
/// world.get<CameraShake>(cameraEntity)!.addTrauma(0.5);
/// ```
///
/// The shake is a **render-time offset**: the camera's `Transform2D` is
/// never touched. [ActiveCameraViewSystem] adds the offset to the position
/// it publishes for the widget render path, and [ParallaxSystem] includes
/// it so camera-fixed layers stay put. Camera follow, bounds, and anything
/// else that reads or writes the camera transform see the steady position.
/// The widget path doesn't rotate the view, so [rotationOffset] is only
/// there for games that apply rotation themselves.
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

  double _offsetX = 0;
  double _offsetY = 0;
  double _rotation = 0;

  /// This frame's horizontal shake offset in world units (0 when still).
  double get offsetX => _offsetX;

  /// This frame's vertical shake offset in world units (0 when still).
  double get offsetY => _offsetY;

  /// This frame's shake rotation in radians (0 when still). Not applied by
  /// the widget render path.
  double get rotationOffset => _rotation;

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

/// System that decays [CameraShake.trauma] and picks each frame's shake
/// offset.
///
/// Runs in `Schedules.postUpdate` after [CameraFollowSystem] and before
/// [ParallaxSystem] and [ActiveCameraViewSystem], which apply the offset.
/// It only writes the [CameraShake] component, never the camera's
/// `Transform2D`, so the follow (and save/load, bounds, ...) always work
/// with the steady camera position.
class CameraShakeSystem implements System {
  /// The `SystemMeta.name` of [CameraShakeSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'CameraShakeSystem';

  final double _fixedDelta;

  /// Optional fixed delta (in seconds). If null the system reads
  /// `WallTime.delta` from the world at run time. Passing a fixed value
  /// makes tests deterministic.
  CameraShakeSystem({double? fixedDelta}) : _fixedDelta = fixedDelta ?? -1;

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<CameraShake>()},
    reads: {ComponentId.of<Camera2D>()},
    resourceReads: {WallTime},
    after: const [CameraFollowSystem.systemName],
    before: const [
      ParallaxSystem.systemName,
      CameraTransitionSystem.systemName,
      ActiveCameraViewSystem.systemName,
    ],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final delta = _fixedDelta >= 0
        ? _fixedDelta
        : (world.getResource<WallTime>()?.delta ?? 0.0);

    for (final (_, shake, _) in world.query2<CameraShake, Camera2D>().iter()) {
      // Decay trauma. clamp to 0 in case the caller poked a negative.
      shake.trauma = (shake.trauma - shake.traumaDecayPerSec * delta).clamp(
        0.0,
        1.0,
      );

      if (shake.trauma <= 0) {
        shake._offsetX = 0;
        shake._offsetY = 0;
        shake._rotation = 0;
        continue;
      }

      final intensity = shake.intensity;
      // Random offsets in [-1, 1] scaled by max*intensity. `nextDouble`
      // gives [0,1); mapped to [-1, 1) is close enough.
      shake._offsetX =
          shake.maxOffsetX * intensity * (shake.rng.nextDouble() * 2 - 1);
      shake._offsetY =
          shake.maxOffsetY * intensity * (shake.rng.nextDouble() * 2 - 1);
      shake._rotation =
          shake.maxRotationRadians *
          intensity *
          (shake.rng.nextDouble() * 2 - 1);
    }
  }
}
