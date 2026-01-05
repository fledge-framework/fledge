# fledge_render_flutter

> **DEPRECATED**: This package has been merged into `fledge_render`. Please use `package:fledge_render/fledge_render.dart` instead.

[![pub package](https://img.shields.io/pub/v/fledge_render_flutter.svg)](https://pub.dev/packages/fledge_render_flutter)

## Migration

```dart
// Before
import 'package:fledge_render_flutter/fledge_render_flutter.dart';

// After
import 'package:fledge_render/fledge_render.dart';
```

All `RenderLayer` classes (`RenderLayer`, `CompositeRenderLayer`, `ClippedRenderLayer`, etc.) are now available directly from `fledge_render`.

This package now re-exports from `fledge_render` for backwards compatibility but will be removed in a future release.

## Related Packages

- [fledge_render](https://pub.dev/packages/fledge_render) - Core render infrastructure (use this instead)
- [fledge_render_2d](https://pub.dev/packages/fledge_render_2d) - 2D rendering components
- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
