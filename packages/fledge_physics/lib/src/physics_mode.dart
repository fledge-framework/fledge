/// Controls which clock fledge_physics's per-step systems read from.
///
/// Physics has two supported cadences:
///
/// - [PhysicsMode.variable] — the default; runs in `Schedules.update`
///   and scales velocity by `WallTime.delta` against a 60 Hz reference
///   frame. `Velocity(max: 4)` still produces 240 px/s at any real
///   frame rate.
/// - [PhysicsMode.fixed] — runs in `Schedules.fixedUpdate` and scales
///   velocity by `FixedTimestep.stepSeconds` against the same 60 Hz
///   reference. `Velocity(max: 4)` produces 240 px/s regardless of
///   fixed step (60 Hz → 4 px/step, 120 Hz → 2 px/step, ...).
///
/// Both modes share the same "velocity is expressed in
/// pixels-per-60Hz-frame" semantic so game code doesn't need to be
/// rewritten to move between them.
enum PhysicsMode {
  /// Variable timestep — scales by `WallTime.delta`.
  variable,

  /// Fixed timestep — scales by `FixedTimestep.stepSeconds`.
  fixed,
}

/// One 60 Hz frame in seconds — the reference used to convert
/// per-frame-at-60fps velocity into per-second movement.
///
/// Aligned to `FixedTimestep`'s default `stepDuration` of 16667μs so
/// `Velocity(max: 4)` produces exactly 4 px per fixed step at the
/// default cadence (down to floating-point precision). Games that
/// switch to a different fixed step get proportional movement.
const double physicsReferenceFrameSeconds = 16667 / 1e6;
