# fledge_particles

CPU-driven particle system for [Fledge](https://fledge-framework.dev) games — emitters, pooling, and presets (fire, smoke, spark, trail).

[![pub package](https://img.shields.io/pub/v/fledge_particles.svg)](https://pub.dev/packages/fledge_particles)

## Installation

```yaml
dependencies:
  fledge_particles: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_particles/fledge_particles.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

Future<void> main() async {
  final app = App()
    ..addPlugin(RenderPlugin())
    ..addPlugin(const ParticlePlugin());

  app.world.spawn()
    ..insert(Transform2D.from(100, 100))
    ..insert(GlobalTransform2D.identity())
    ..insert(ParticleEmitterPresets.fire(texture: myParticleTexture));

  await app.run();
}
```

### One-off bursts

For impacts and pickups, give an emitter `emitRate: 0` and call `burst`:

```dart
final chips = ParticleEmitter(
  template: myChipTemplate,
  emitRate: 0,
  texture: whitePixel,
  pool: ParticlePool(128),
);
// ...later, when something is hit:
chips.burst(6, Vector2(x, y));
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/particles) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
