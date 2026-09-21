import 'dart:math' as math;

/// A curve maps a normalised time `t` in `0..1` to an eased value in the
/// same range.
///
/// Curves are pure functions; they don't hold state. See [Curves] for the
/// standard built-in curves. Games can also supply custom curves — for
/// example a Bezier or a spring:
///
/// ```dart
/// Curve myCurve = (t) => math.pow(t, 3).toDouble();
/// ```
typedef Curve = double Function(double t);

/// A collection of standard easing curves.
///
/// Every function here obeys the same contract as [Curve]: it takes a
/// `t` in `0..1` and returns an eased value in the same range. Callers
/// may pass values slightly outside that range (e.g. from a [Tween] that
/// hasn't been clamped) but the results at those extremes are curve-
/// specific and not defined.
///
/// Naming follows the widely used Penner-style convention: `easeIn*`
/// starts slow and accelerates, `easeOut*` starts fast and decelerates,
/// and `easeInOut*` combines the two symmetrically.
class Curves {
  Curves._();

  /// The identity curve — `linear(t) == t`.
  static double linear(double t) => t;

  /// Quadratic ease-in — accelerating from zero velocity.
  static double easeInQuad(double t) => t * t;

  /// Quadratic ease-out — decelerating to zero velocity.
  static double easeOutQuad(double t) => t * (2 - t);

  /// Quadratic ease-in-out — accelerate then decelerate.
  static double easeInOutQuad(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  /// Cubic ease-in — accelerating from zero velocity, sharper than [easeInQuad].
  static double easeInCubic(double t) => t * t * t;

  /// Cubic ease-out — decelerating to zero velocity, sharper than [easeOutQuad].
  static double easeOutCubic(double t) {
    final u = t - 1;
    return u * u * u + 1;
  }

  /// Cubic ease-in-out — accelerate then decelerate, sharper than
  /// [easeInOutQuad].
  static double easeInOutCubic(double t) {
    if (t < 0.5) return 4 * t * t * t;
    final u = 2 * t - 2;
    return 0.5 * u * u * u + 1;
  }

  /// Quartic ease-in — accelerating from zero velocity, sharper still.
  static double easeInQuart(double t) => t * t * t * t;

  /// Quartic ease-out — decelerating to zero velocity, sharper still.
  static double easeOutQuart(double t) {
    final u = t - 1;
    return 1 - u * u * u * u;
  }

  /// Quartic ease-in-out — accelerate then decelerate, sharper still.
  static double easeInOutQuart(double t) {
    if (t < 0.5) return 8 * t * t * t * t;
    final u = t - 1;
    return 1 - 8 * u * u * u * u;
  }

  /// Sinusoidal ease-in — quarter of a cosine.
  static double easeInSine(double t) => 1 - math.cos((t * math.pi) / 2);

  /// Sinusoidal ease-out — quarter of a sine.
  static double easeOutSine(double t) => math.sin((t * math.pi) / 2);

  /// Sinusoidal ease-in-out — half of a cosine.
  static double easeInOutSine(double t) => -(math.cos(math.pi * t) - 1) / 2;

  /// Bounce out — spring back like a ball bouncing to rest.
  static double bounceOut(double t) {
    if (t < (1 / 2.75)) {
      return 7.5625 * t * t;
    }
    if (t < (2 / 2.75)) {
      final u = t - (1.5 / 2.75);
      return 7.5625 * u * u + 0.75;
    }
    if (t < (2.5 / 2.75)) {
      final u = t - (2.25 / 2.75);
      return 7.5625 * u * u + 0.9375;
    }
    final u = t - (2.625 / 2.75);
    return 7.5625 * u * u + 0.984375;
  }

  /// Bounce in — mirror of [bounceOut].
  static double bounceIn(double t) => 1 - bounceOut(1 - t);

  /// Elastic out — overshoots then settles.
  ///
  /// The `t == 0` and `t == 1` shortcuts guard against the `sin(...)`
  /// term drifting a floating-point epsilon off the expected endpoints.
  static double elasticOut(double t) {
    if (t == 0 || t == 1) return t;
    return math.pow(2, -10 * t) * math.sin((t - 0.075) * (2 * math.pi) / 0.3) +
        1;
  }

  /// Elastic in — mirror of [elasticOut].
  static double elasticIn(double t) {
    if (t == 0 || t == 1) return t;
    return -math.pow(2, 10 * (t - 1)) *
        math.sin(((t - 1) - 0.075) * (2 * math.pi) / 0.3);
  }
}
