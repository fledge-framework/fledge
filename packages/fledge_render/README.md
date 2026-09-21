# fledge_render

**Deprecated — merged into [`fledge_render_2d`](https://pub.dev/packages/fledge_render_2d).**

[![pub package](https://img.shields.io/pub/v/fledge_render.svg)](https://pub.dev/packages/fledge_render)

This package is now a re-export shim. Everything that used to live here
(render graph, two-world architecture, extractors, render layers,
`RenderPlugin`) has moved into `fledge_render_2d` alongside the 2D
component set. Depending on `fledge_render` for one release remains
supported so existing code compiles unchanged, but new code should
depend on `fledge_render_2d` directly.

## Migration

```yaml
dependencies:
-  fledge_render: ^0.2.0
+  fledge_render_2d: ^0.2.0
```

```dart
- import 'package:fledge_render/fledge_render.dart';
+ import 'package:fledge_render_2d/fledge_render_2d.dart';
```

All symbols keep the same names. `SpriteBackendPlugin` has also been
collapsed back into `RenderPlugin` — call `RenderPlugin(backend:
RenderBackend.canvas)` on its own and the matching sprite drawer is
installed automatically.

## Related Packages

- [fledge_render_2d](https://pub.dev/packages/fledge_render_2d) - 2D
  rendering plus the render infrastructure previously in this package.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
