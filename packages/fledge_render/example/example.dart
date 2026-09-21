// ignore_for_file: avoid_print
//
// fledge_render is a re-export shim — the real implementation now
// lives in `fledge_render_2d`. Prefer importing that package directly:
//
//   import 'package:fledge_render_2d/fledge_render_2d.dart';
//
// Importing this shim is still supported for one release for
// backwards compatibility.
import 'package:fledge_render/fledge_render.dart';

void main() {
  // Any symbol that used to live in fledge_render is available through
  // the shim, e.g. RenderWorld / Extractors / DrawLayer.
  final world = RenderWorld();
  print('render world entity count: ${world.entityCount}');
}
