/// This package has been merged into `fledge_render_2d`.
///
/// This file re-exports the moved symbols so downstream code that
/// imports `package:fledge_render/fledge_render.dart` continues to
/// compile for one release. Migrate to
/// `package:fledge_render_2d/fledge_render_2d.dart`.
@Deprecated(
  'fledge_render was merged into fledge_render_2d. Import '
  'package:fledge_render_2d/fledge_render_2d.dart directly.',
)
library;

export 'package:fledge_render_2d/fledge_render_2d.dart';
