/// 2D camera components and cinematics for Fledge.
///
/// Extracted from `fledge_render_2d` in Phase 6a. Depends on
/// `fledge_render_2d` for the [CameraView] and [Viewport] types that
/// flow through the render graph — the reverse dependency does not
/// exist.
///
/// ## Contents
///
/// - [Camera2D], [Projection], [OrthographicProjection],
///   [IsometricProjection], [ObliqueProjection] — camera + projections.
/// - [CameraDriverNode], [CameraDriverContext] — render-graph glue.
/// - [CameraFollow] + [CameraFollowSystem] — smooth follow.
/// - [CameraShake] + [CameraShakeSystem] — trauma-based shake.
/// - [Parallax] + [ParallaxSystem] — parallax scrolling.
/// - [CameraFadeTransition], [CameraWipeTransition] +
///   [CameraTransitionSystem] — fade / wipe.
/// - [LetterboxConfig], [computeLetterbox], [computeGutter] —
///   letterbox helpers.
/// - [ViewportSize] — viewport-size resource used by extractors.
/// - [PixelPerfectVector2] — snap-to-pixel helpers.
/// - [CameraPlugin] — wires the systems into an `App`.
library;

export 'src/camera2d.dart';
export 'src/camera_driver.dart';
export 'src/camera_plugin.dart';
export 'src/follow.dart';
export 'src/letterbox.dart';
export 'src/parallax.dart';
export 'src/pixel_perfect.dart';
export 'src/projection.dart';
export 'src/shake.dart';
export 'src/transitions.dart';
export 'src/viewport_size.dart';
