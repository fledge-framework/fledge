/// Easing curves and tweens for the Fledge ECS game framework.
///
/// This library provides:
///
/// - [Curve] / [Curves] — a small collection of standard easing
///   functions that map `t in 0..1` to an eased value in the same range.
/// - [Tween] — a value class that interpolates from [Tween.from] to
///   [Tween.to] over [Tween.duration], using a [Curve] and a type-specific
///   `lerp` function.
/// - [Tweener] + [TweenSystem] — a component/system pair that advances
///   active tweens each frame and invokes a per-entity sample callback.
/// - [TweenPlugin] — the plugin entry point; installs [TweenSystem] on
///   either the wall-time or fixed-timestep update schedule.
/// - Type-specific lerp helpers ([lerpDouble], [lerpInt], [lerpOffset],
///   [lerpColor]) — users can also supply their own for custom types.
///
/// ## Quick start
///
/// ```dart
/// import 'package:fledge_ecs/fledge_ecs.dart';
/// import 'package:fledge_tween/fledge_tween.dart';
///
/// Future<void> main() async {
///   final position = Position(0, 0);
///
///   final app = App()
///     ..addPlugin(const TweenPlugin());
///
///   app.world.spawn().insert(Tweener(
///     tween: Tween<double>(
///       from: 0,
///       to: 100,
///       duration: const Duration(seconds: 1),
///       curve: Curves.easeOutCubic,
///       lerp: lerpDouble,
///     ),
///     onSample: (value) => position.x = value as double,
///   ));
///
///   await app.tick();
/// }
/// ```
library;

export 'src/curve.dart';
export 'src/lerp.dart';
export 'src/tween.dart';
export 'src/tween_plugin.dart';
export 'src/tween_system.dart';
