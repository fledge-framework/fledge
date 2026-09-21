import 'package:fledge_ecs/fledge_ecs.dart';

import 'tween.dart';

/// How a [Tweener] behaves once its elapsed time reaches
/// [Tween.duration].
enum TweenLoopMode {
  /// Runs exactly once. The [Tweener.onComplete] callback fires and the
  /// component is removed from its entity.
  once,

  /// Restarts from `elapsed = 0` and keeps running indefinitely.
  ///
  /// `onComplete` is *not* called for looping tweens — they never
  /// finish.
  loop,

  /// Alternates direction each cycle by swapping [Tween.from] and
  /// [Tween.to], restarting from `elapsed = 0`.
  ///
  /// `onComplete` is *not* called for ping-pong tweens.
  pingPong,
}

/// Component that runs an active [Tween] on an entity.
///
/// [Tweener] is intentionally **not** generic. Fledge's archetype
/// storage uses the component's runtime `Type` as its identity, so a
/// `Tweener<double>` and a `Tweener<Color>` would be different
/// archetypes and would each need to be queried and advanced separately.
/// Keeping [Tweener] non-generic lets a single [TweenSystem] iterate
/// every tween in the world in one query, regardless of the type being
/// interpolated.
///
/// The trade-off is that the [Tween]'s value type parameter is erased
/// on the way into [Tweener]: the sample callback takes `dynamic`.
/// Users typically pin the type by using a typed closure:
///
/// ```dart
/// world.spawn().insert(Tweener(
///   tween: Tween<double>(
///     from: 0,
///     to: 100,
///     duration: const Duration(seconds: 1),
///     lerp: lerpDouble,
///   ),
///   onSample: (v) => transform.x = v as double,
/// ));
/// ```
class Tweener {
  /// The tween being sampled. Stored with an erased type parameter — see
  /// the class docs for why.
  final Tween<dynamic> tween;

  /// Time elapsed since this tween started (or last looped).
  ///
  /// Advanced by [TweenSystem] each frame it runs. Public so games can
  /// pause a tween by simply not scheduling [TweenSystem], or scrub it
  /// manually.
  Duration elapsed;

  /// Called on every frame [TweenSystem] runs with the sampled value.
  ///
  /// The value is `dynamic` because [tween] is stored with an erased
  /// type parameter. In practice the closure knows the concrete type
  /// and can cast.
  final void Function(dynamic value) onSample;

  /// Called once when a [TweenLoopMode.once] tween finishes.
  ///
  /// Not called for [TweenLoopMode.loop] or [TweenLoopMode.pingPong] —
  /// those never truly complete.
  final void Function()? onComplete;

  /// Loop behaviour once elapsed reaches [Tween.duration].
  final TweenLoopMode loop;

  /// Creates a tweener.
  Tweener({
    required this.tween,
    required this.onSample,
    this.onComplete,
    this.loop = TweenLoopMode.once,
    this.elapsed = Duration.zero,
  });
}

/// System that advances every [Tweener] in the world by the current
/// frame's delta and invokes each tweener's sample callback.
///
/// The system reads the [WallTime] resource (from `fledge_ecs`'s
/// `WallTimePlugin`) to compute the frame delta. If no [WallTime]
/// resource is present the system falls back to a zero delta — every
/// tweener still gets sampled at its current elapsed time so `onSample`
/// fires at least once for `sample(0)`. Games that don't add
/// `WallTimePlugin` should advance elapsed manually.
///
/// Completion, by loop mode:
///
/// - [TweenLoopMode.once]: fires [Tweener.onComplete] (if any) and
///   removes the component from its entity at the end of the frame.
/// - [TweenLoopMode.loop]: resets elapsed to zero and keeps running.
/// - [TweenLoopMode.pingPong]: swaps [Tween.from] / [Tween.to] and
///   resets elapsed to zero.
class TweenSystem implements System {
  /// Creates the tween system.
  TweenSystem();

  static final SystemMeta _meta = SystemMeta(
    name: 'tweenSystem',
    // Advertise Tweener as written — the system mutates elapsed in
    // place and adds/removes the component around loop boundaries.
    writes: {ComponentId.of<Tweener>()},
    // Reads WallTime for the frame delta. Advertising it as a resource
    // read keeps the scheduler honest if a game adds a system that
    // writes WallTime.
    resourceReads: const {WallTime},
  );

  @override
  SystemMeta get meta => _meta;

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final delta = _frameDelta(world);
    // Collect entities to touch after iteration so we don't mutate the
    // archetype while iterating it.
    final toRemove = <Entity>[];
    final toReplace = <(Entity, Tweener)>[];

    for (final (entity, tweener) in world.query1<Tweener>().iter()) {
      tweener.elapsed += delta;
      final duration = tweener.tween.duration;

      if (tweener.elapsed < duration) {
        tweener.onSample(tweener.tween.sample(tweener.elapsed));
        continue;
      }

      // Reached (or passed) the end this frame — sample the terminal
      // value once so the callback observes the exact endpoint.
      tweener.onSample(tweener.tween.sample(duration));

      switch (tweener.loop) {
        case TweenLoopMode.once:
          tweener.onComplete?.call();
          toRemove.add(entity);
        case TweenLoopMode.loop:
          tweener.elapsed = Duration.zero;
        case TweenLoopMode.pingPong:
          // Rebuild the tween with from/to swapped. Tween is immutable,
          // so we allocate a new Tweener with the flipped tween and
          // replace the old one — the archetype stays the same either
          // way, but this keeps Tween.from/to final. Tween.reversed()
          // dispatches on the concrete generic type, avoiding the
          // function-contravariance mismatch you'd hit reconstructing
          // a Tween<dynamic> directly from a Tween<double>.
          toReplace.add(
            (
              entity,
              Tweener(
                tween: tweener.tween.reversed(),
                onSample: tweener.onSample,
                onComplete: tweener.onComplete,
                loop: tweener.loop,
              ),
            ),
          );
      }
    }

    for (final entity in toRemove) {
      world.remove<Tweener>(entity);
    }
    for (final (entity, replacement) in toReplace) {
      world.remove<Tweener>(entity);
      world.insert<Tweener>(entity, replacement);
    }

    return Future.value();
  }

  Duration _frameDelta(World world) {
    final time = world.getResource<WallTime>();
    if (time == null) return Duration.zero;
    // WallTime.delta is in seconds. Convert via microseconds to preserve
    // sub-millisecond precision for small deltas.
    final micros = (time.delta * Duration.microsecondsPerSecond).round();
    return Duration(microseconds: micros);
  }
}
