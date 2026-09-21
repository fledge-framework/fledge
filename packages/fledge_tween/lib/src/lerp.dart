import 'package:flutter/painting.dart';

/// Linearly interpolates between two [double] values.
///
/// `t == 0` returns [a]; `t == 1` returns [b]. Values outside `0..1`
/// extrapolate — callers usually clamp via [Tween.sample] first.
double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// Linearly interpolates between two [int] values and rounds to the
/// nearest integer.
///
/// Rounding, not truncation, keeps the interpolation symmetric — a
/// midpoint returns the value closer to the true mean.
int lerpInt(int a, int b, double t) => (a + (b - a) * t).round();

/// Linearly interpolates between two [Offset] values.
///
/// Wraps [Offset.lerp] and asserts the result is non-null: both endpoints
/// are non-null so the underlying implementation cannot return null.
Offset lerpOffset(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

/// Linearly interpolates between two [Color] values in ARGB space.
///
/// Wraps [Color.lerp] with the same non-null guarantee as [lerpOffset].
Color lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t)!;
