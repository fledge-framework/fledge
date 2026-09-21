import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tween/fledge_tween.dart';

/// Minimal fledge_tween example.
///
/// [Tween] is a pure value class — build one, then [Tween.sample] at
/// any [Duration] to read the eased value. Curves live on [Curves];
/// game-specific types plug in through the `lerp` callback.
///
/// To animate an entity across frames, attach a [Tweener] and the
/// [TweenPlugin]'s [TweenSystem] will call `onSample` every frame,
/// advancing by `WallTime.delta`.
void main() async {
  // A scalar tween sampled at a handful of timesteps.
  final rise = Tween<double>(
    from: 0,
    to: 100,
    duration: const Duration(seconds: 1),
    curve: Curves.easeInOutCubic,
    lerp: lerpDouble,
  );
  assert(rise.sample(Duration.zero) == 0);
  assert(rise.sample(const Duration(milliseconds: 500)) == 50);
  assert(rise.sample(const Duration(seconds: 1)) == 100);

  // A color tween — same shape, `lerpColor` in place of `lerpDouble`.
  final fade = Tween<Color>(
    from: const Color(0xFF000000),
    to: const Color(0xFFFFFFFF),
    duration: const Duration(seconds: 1),
    lerp: lerpColor,
  );
  assert(fade.sample(const Duration(milliseconds: 500)).a > 0);

  // Wire the plugin and drive a tween via a [Tweener] component.
  final app = App()
    ..addPlugin(const WallTimePlugin())
    ..addPlugin(const TweenPlugin());

  var latest = 0.0;
  app.world.spawn().insert(
    Tweener(
      tween: Tween<double>(
        from: 0,
        to: 1,
        duration: const Duration(seconds: 2),
        lerp: lerpDouble,
      ),
      onSample: (value) => latest = value as double,
      loop: TweenLoopMode.pingPong,
    ),
  );

  await app.tick();
  assert(latest >= 0 && latest <= 1);
}
