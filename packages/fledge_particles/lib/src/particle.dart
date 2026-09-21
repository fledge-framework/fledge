import 'dart:ui' show Color;

import 'package:vector_math/vector_math.dart';

/// Instance data for one live particle.
///
/// `Particle` values are owned by a [ParticlePool] and reused across
/// spawns to avoid GC pressure. Each field is mutable so systems can
/// update state in place — pool-owned objects are cleared to sensible
/// defaults on despawn (see [ParticlePool.reap]) but not freed.
class Particle {
  /// World-space position (pre-transformed to the emitter's frame at
  /// spawn time).
  Vector2 position;

  /// Linear velocity in world units / second.
  Vector2 velocity;

  /// Linear acceleration in world units / second^2 (gravity, drag).
  Vector2 acceleration;

  /// Seconds since spawn. Advanced by
  /// [ParticleUpdateSystem].
  double lifetime;

  /// Seconds this particle lives for. Once [lifetime] reaches this it
  /// is [isAlive] == false and eligible for reap.
  double maxLifetime;

  /// Base size (half-size or radius, in world units).
  double size;

  /// Size ramp: at `t == 0` the effective size equals [size]; at
  /// `t == 1` it equals `size * sizeStartToEnd`. Values `< 1` shrink,
  /// `> 1` grow. `1.0` = constant size.
  double sizeStartToEnd;

  /// Color at spawn (`t == 0`).
  Color colorStart;

  /// Color at end of life (`t == 1`).
  Color colorEnd;

  /// Rotation in radians.
  double rotation;

  /// Angular velocity in radians / second.
  double angularVelocity;

  /// Creates a particle. Callers should generally not construct these
  /// directly — go through [ParticlePool.spawn], which sources a
  /// pooled instance and resets its fields.
  Particle({
    required this.position,
    required this.velocity,
    Vector2? acceleration,
    this.lifetime = 0.0,
    required this.maxLifetime,
    this.size = 4.0,
    this.sizeStartToEnd = 1.0,
    required this.colorStart,
    required this.colorEnd,
    this.rotation = 0.0,
    this.angularVelocity = 0.0,
  }) : acceleration = acceleration ?? Vector2.zero();

  /// Whether this particle is still alive (`lifetime < maxLifetime`).
  bool get isAlive => lifetime < maxLifetime;

  /// Normalized age in `[0, 1]`.
  double get t => (lifetime / maxLifetime).clamp(0.0, 1.0);

  /// Linearly interpolated color between [colorStart] and [colorEnd]
  /// based on [t]. `Color.lerp` is non-null when both endpoints are
  /// non-null, so the bang here is safe.
  Color get color => Color.lerp(colorStart, colorEnd, t)!;

  /// Interpolated size, blending [size] at `t == 0` with
  /// `size * sizeStartToEnd` at `t == 1`.
  double get currentSize => size * (1 - t + sizeStartToEnd * t);
}

/// Fixed-capacity pool of [Particle] objects.
///
/// The pool preallocates a capped ring of particle instances and hands
/// them out via [spawn]. Dead particles reclaimed by [reap] slide back
/// onto the free list without being freed to the GC, keeping the
/// per-frame allocation footprint of a saturated emitter close to zero.
///
/// The pool is intentionally not iterator-safe against concurrent
/// mutation — [reap] must not be called while a caller is iterating
/// [live], which mirrors how the systems in this package are wired
/// (emit → update → reap, none of them overlapping).
class ParticlePool {
  final List<Particle?> _particles;
  final List<bool> _inUse;
  final List<int> _freeIndices;

  /// Maximum number of simultaneously-live particles.
  final int capacity;

  int _liveCount = 0;

  /// Creates a pool with [capacity] slots. All slots start empty;
  /// [Particle] instances are lazily allocated on first [spawn] into
  /// each slot.
  ParticlePool(this.capacity)
    : assert(capacity > 0, 'ParticlePool.capacity must be positive'),
      _particles = List<Particle?>.filled(capacity, null),
      _inUse = List<bool>.filled(capacity, false),
      _freeIndices = List<int>.generate(capacity, (i) => i);

  /// The current number of live particles.
  int get liveCount => _liveCount;

  /// Whether the pool has no free slots. New spawns will return null.
  bool get isFull => _freeIndices.isEmpty;

  /// Spawn a new particle by copying [prototype] into a pooled slot.
  ///
  /// Returns the pooled [Particle] whose fields now mirror
  /// [prototype], or `null` when the pool is at capacity.
  ///
  /// Callers may hold the returned reference for the rest of the frame
  /// but should not assume it lives past the next [reap] — once a
  /// particle's [Particle.isAlive] flips to false, its slot is
  /// eligible for reuse.
  Particle? spawn({
    required Vector2 position,
    required Vector2 velocity,
    Vector2? acceleration,
    required double maxLifetime,
    double size = 4.0,
    double sizeStartToEnd = 1.0,
    required Color colorStart,
    required Color colorEnd,
    double rotation = 0.0,
    double angularVelocity = 0.0,
  }) {
    if (_freeIndices.isEmpty) return null;
    final index = _freeIndices.removeLast();

    final existing = _particles[index];
    if (existing == null) {
      _particles[index] = Particle(
        position: position.clone(),
        velocity: velocity.clone(),
        acceleration: (acceleration ?? Vector2.zero()).clone(),
        maxLifetime: maxLifetime,
        size: size,
        sizeStartToEnd: sizeStartToEnd,
        colorStart: colorStart,
        colorEnd: colorEnd,
        rotation: rotation,
        angularVelocity: angularVelocity,
      );
    } else {
      existing.position.setFrom(position);
      existing.velocity.setFrom(velocity);
      existing.acceleration.setFrom(acceleration ?? Vector2.zero());
      existing.lifetime = 0.0;
      existing.maxLifetime = maxLifetime;
      existing.size = size;
      existing.sizeStartToEnd = sizeStartToEnd;
      existing.colorStart = colorStart;
      existing.colorEnd = colorEnd;
      existing.rotation = rotation;
      existing.angularVelocity = angularVelocity;
    }
    _inUse[index] = true;
    _liveCount++;
    return _particles[index];
  }

  /// Reclaim every particle whose [Particle.isAlive] is false.
  ///
  /// Returns the number of slots freed this call. Idempotent — slots
  /// already returned to the free list are skipped on the next call,
  /// so a saturated pool followed by two [reap]s doesn't
  /// double-decrement [liveCount].
  int reap() {
    var freed = 0;
    for (var i = 0; i < _particles.length; i++) {
      if (!_inUse[i]) continue;
      final p = _particles[i];
      // `_inUse[i]` guarantees the slot has a Particle instance.
      if (p == null || p.isAlive) continue;
      _inUse[i] = false;
      _freeIndices.add(i);
      _liveCount--;
      freed++;
      // Pin lifetime at maxLifetime so any stale reader observes
      // `isAlive == false`. The slot itself is retained for the next
      // spawn — this is the whole point of pooling.
      p.lifetime = p.maxLifetime;
    }
    return freed;
  }

  /// Iterable of every live particle in the pool.
  ///
  /// Order is arbitrary and may change across frames as slots are
  /// recycled — do not depend on it for rendering priority. The
  /// underlying storage is retained across iterations, so this is
  /// allocation-free per frame beyond the wrapping iterable.
  ///
  /// Between [ParticleUpdateSystem] and [ParticleReapSystem] there is
  /// a small window where a slot is `_inUse` but the particle has
  /// aged out; iteration filters those so consumers (like the
  /// extractor) never observe dead particles.
  Iterable<Particle> get live sync* {
    for (var i = 0; i < _particles.length; i++) {
      if (!_inUse[i]) continue;
      final p = _particles[i];
      if (p == null || !p.isAlive) continue;
      yield p;
    }
  }
}
