import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:fledge_render_2d/fledge_render_2d.dart'
    show DrawLayer, TextureHandle;
import 'package:vector_math/vector_math.dart';

import 'particle.dart';

/// A recipe describing how to instantiate a [Particle].
///
/// Templates supply randomizable ranges for lifetime, velocity, size,
/// and angular velocity, plus fixed color endpoints and acceleration.
/// A single template can be shared across many emitters — none of its
/// fields are mutated at spawn time.
class ParticleTemplate {
  /// Minimum lifetime in seconds (inclusive).
  final double lifetimeMin;

  /// Maximum lifetime in seconds (inclusive).
  final double lifetimeMax;

  /// Minimum spawn velocity, per-component. Draw uniformly in the
  /// rectangle `[velocityMin, velocityMax]`.
  final Vector2 velocityMin;

  /// Maximum spawn velocity, per-component.
  final Vector2 velocityMax;

  /// Constant acceleration applied every frame (gravity, drag).
  final Vector2 acceleration;

  /// Minimum spawn size in world units.
  final double sizeMin;

  /// Maximum spawn size in world units.
  final double sizeMax;

  /// Multiplier applied to spawn size at end of life. `< 1` shrinks,
  /// `> 1` grows. See [Particle.sizeStartToEnd].
  final double sizeStartToEnd;

  /// Color at spawn (`t == 0`).
  final Color colorStart;

  /// Color at end of life (`t == 1`).
  final Color colorEnd;

  /// Minimum angular velocity in radians / second.
  final double angularVelocityMin;

  /// Maximum angular velocity in radians / second.
  final double angularVelocityMax;

  /// Creates a particle template.
  const ParticleTemplate({
    required this.lifetimeMin,
    required this.lifetimeMax,
    required this.velocityMin,
    required this.velocityMax,
    required this.acceleration,
    required this.sizeMin,
    required this.sizeMax,
    this.sizeStartToEnd = 1.0,
    required this.colorStart,
    required this.colorEnd,
    this.angularVelocityMin = 0.0,
    this.angularVelocityMax = 0.0,
  });

  /// Draws a single particle from this template into [pool].
  ///
  /// Returns the pooled [Particle], or `null` when the pool is full.
  /// The particle's position is initialized to [origin]; callers are
  /// expected to have already resolved that to world space (e.g. from
  /// `GlobalTransform2D.translation`).
  Particle? spawnInto(
    ParticlePool pool, {
    required Vector2 origin,
    required math.Random rng,
  }) {
    final lifetime = _lerp(rng, lifetimeMin, lifetimeMax);
    final vx = _lerp(rng, velocityMin.x, velocityMax.x);
    final vy = _lerp(rng, velocityMin.y, velocityMax.y);
    final size = _lerp(rng, sizeMin, sizeMax);
    final angVel = _lerp(rng, angularVelocityMin, angularVelocityMax);

    return pool.spawn(
      position: origin,
      velocity: Vector2(vx, vy),
      acceleration: acceleration,
      maxLifetime: lifetime,
      size: size,
      sizeStartToEnd: sizeStartToEnd,
      colorStart: colorStart,
      colorEnd: colorEnd,
      angularVelocity: angVel,
    );
  }

  static double _lerp(math.Random rng, double lo, double hi) {
    if (lo == hi) return lo;
    return lo + rng.nextDouble() * (hi - lo);
  }
}

/// Component: emits particles over time.
///
/// Attach alongside a `GlobalTransform2D` — the particle system spawns
/// particles at the transform's world-space translation.
///
/// Each emitter owns its own [ParticlePool]; the effective per-frame
/// particle cap is the sum of `pool.capacity` across all emitters in
/// the world. Two emitters can share a template but not a pool.
class ParticleEmitter {
  /// Recipe for the particles this emitter spawns.
  final ParticleTemplate template;

  /// Emit rate in particles per second. `0` = stopped.
  double emitRate;

  /// Fractional accumulator for sub-frame emit timing. Advanced by
  /// [ParticleEmitSystem]; not intended for direct manipulation.
  double emitAccumulator = 0.0;

  /// Handle to the texture used for these particles. Rendered through
  /// the standard sprite pipeline via [ExtractedSprite].
  final TextureHandle texture;

  /// Draw layer for these particles. Defaults to
  /// [DrawLayer.particles], which is the reserved sort range on
  /// `DrawLayer`.
  final DrawLayer layer;

  /// Explicit sub-order inside [layer]. `0` uses a Y-based sub-order.
  final int layerSubOrder;

  /// Pool that owns the live particles for this emitter.
  final ParticlePool pool;

  /// Optional maximum lifetime for the emitter itself in seconds.
  /// When set, [ParticleEmitSystem] stops emitting once
  /// [elapsedSinceStart] reaches this value — existing particles run
  /// to their own lifetimes. `null` = infinite.
  double? maxDuration;

  /// Seconds elapsed since the emitter started. Advanced by
  /// [ParticleEmitSystem]. Internal.
  double elapsedSinceStart = 0.0;

  /// Whether this emitter is currently active. Set to `false` to
  /// pause emission without destroying live particles.
  bool isActive;

  /// Deterministic RNG source for spawn randomization. `null` means
  /// use a shared default `math.Random`.
  final math.Random? rng;

  /// Creates a particle emitter component.
  ParticleEmitter({
    required this.template,
    required this.emitRate,
    required this.texture,
    required this.pool,
    this.layer = DrawLayer.particles,
    this.layerSubOrder = 0,
    this.maxDuration,
    this.isActive = true,
    this.rng,
  });

  /// Whether this emitter is currently within its emit window.
  ///
  /// `true` when the emitter is active *and* either has no
  /// [maxDuration] or the emitter's own clock hasn't reached it.
  bool get canEmit {
    if (!isActive) return false;
    final duration = maxDuration;
    if (duration != null && elapsedSinceStart >= duration) return false;
    return true;
  }
}
