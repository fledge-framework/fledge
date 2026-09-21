import 'package:meta/meta.dart';

import 'curve.dart';

/// A tween interpolates a value from [from] to [to] over [duration].
///
/// [Tween] itself is a pure value class — it holds no timing state. To
/// actually animate a value across frames, attach a [Tweener] component
/// (see `tween_system.dart`) that owns the elapsed duration and calls
/// [sample] each frame.
///
/// ## Example
///
/// ```dart
/// final t = Tween<double>(
///   from: 0,
///   to: 100,
///   duration: const Duration(seconds: 1),
///   curve: Curves.easeOutCubic,
///   lerp: lerpDouble,
/// );
///
/// t.sample(Duration.zero);              // 0
/// t.sample(const Duration(seconds: 1)); // 100
/// t.sample(const Duration(seconds: 2)); // 100 (clamped)
/// ```
@immutable
class Tween<T> {
  /// Value returned when `elapsed <= 0`.
  final T from;

  /// Value returned when `elapsed >= duration`.
  final T to;

  /// How long the tween takes to go from [from] to [to].
  ///
  /// Must be greater than zero. A zero-duration tween is undefined —
  /// use the target value directly instead.
  final Duration duration;

  /// Easing curve applied to normalised time before [lerp].
  final Curve curve;

  /// Interpolator for [T]. Given [from], [to], and an eased `t` in `0..1`,
  /// returns the intermediate value.
  ///
  /// Use one of the type-specific helpers in `lerp.dart` (e.g.
  /// [lerpDouble], [lerpColor]) or supply a custom implementation for
  /// game-specific types.
  final T Function(T a, T b, double t) lerp;

  /// Creates a tween.
  ///
  /// [duration] must be positive; the constructor asserts on this in
  /// debug builds.
  const Tween({
    required this.from,
    required this.to,
    required this.duration,
    required this.lerp,
    this.curve = Curves.linear,
  }) : assert(duration > Duration.zero, 'Tween.duration must be positive');

  /// Samples the tween at [elapsed].
  ///
  /// - `elapsed <= Duration.zero` returns [from].
  /// - `elapsed >= duration` returns [to].
  /// - Otherwise returns `lerp(from, to, curve(elapsed / duration))`.
  T sample(Duration elapsed) {
    if (elapsed <= Duration.zero) return from;
    if (elapsed >= duration) return to;
    final t = elapsed.inMicroseconds / duration.inMicroseconds;
    return lerp(from, to, curve(t));
  }

  /// Returns a new tween with [from] and [to] swapped.
  ///
  /// [duration], [curve], and [lerp] are preserved. Used by
  /// [TweenSystem] to implement [TweenLoopMode.pingPong].
  ///
  /// This method preserves the tween's generic parameter [T], which
  /// matters because [Tweener] stores its tween as `Tween<dynamic>`
  /// even though the underlying object is a `Tween<double>` /
  /// `Tween<Color>` / etc. Reusing a `Tween<dynamic>`'s `lerp` field
  /// directly on a fresh `Tween<dynamic>` fails Dart's function-
  /// contravariance check — building the flipped tween through
  /// [reversed] keeps the dispatch on the concrete type.
  Tween<T> reversed() => Tween<T>(
        from: to,
        to: from,
        duration: duration,
        curve: curve,
        lerp: lerp,
      );
}
