import 'dart:ui'
    show Canvas, Color, Offset, Paint, PaintingStyle, Path, Rect, Size;

import 'package:fledge_camera_2d/fledge_camera_2d.dart' show Camera2D;
import 'package:fledge_ecs/fledge_ecs.dart' show App, Entity, World;
import 'package:fledge_physics/fledge_physics.dart'
    show
        Collider,
        CollisionShape,
        EllipseShape,
        PointShape,
        PolygonShape,
        PolylineShape,
        RectangleShape;
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show GlobalTransform2D, RenderSize, withActiveCameraCanvas;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        CustomPaint,
        CustomPainter,
        Positioned,
        SizedBox,
        Stack,
        StatelessWidget,
        Widget;

import '../resources/debug_config.dart';

/// Overlay widget that paints debug gizmos on top of [child].
///
/// Games wrap their render tree like so:
///
/// ```dart
/// DebugGizmosLayer(
///   app: app,
///   child: FledgeUiOverlay(
///     app: app,
///     child: FledgeRenderView(app: app),
///   ),
/// )
/// ```
///
/// When no gizmo flag is enabled in the app's [DebugConfig] (which is
/// the default), the widget skips inserting the `CustomPaint` and
/// simply returns [child] — zero cost when gizmos are off.
///
/// The current implementation assumes a **1:1 world → screen** mapping
/// (which matches Drifter's setup and the default `fledge_render_2d`
/// render view). A game that scales or translates the world through a
/// camera view-projection will see gizmos drawn in world coordinates,
/// not screen coordinates. Applying the active camera's projection is a
/// follow-up — the hook is [_GizmoPainter._worldToScreen]; the
/// signature already threads the canvas size through so it can grow
/// into a full [Camera2D.worldToScreen] call without touching call
/// sites.
class DebugGizmosLayer extends StatelessWidget {
  /// The Fledge app whose world holds the entities to visualise.
  final App app;

  /// Underlying widget (usually the game render view).
  final Widget child;

  /// Creates a debug gizmos overlay.
  const DebugGizmosLayer({super.key, required this.app, required this.child});

  @override
  Widget build(BuildContext context) {
    final config = app.world.getResource<DebugConfig>();
    if (config == null || !config.anyGizmoEnabled) {
      // No gizmos enabled — skip the extra Stack/Paint work.
      return child;
    }
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _GizmoPainter(app: app, config: config),
            ),
          ),
        ),
      ],
    );
  }
}

class _GizmoPainter extends CustomPainter {
  final App app;
  final DebugConfig config;

  _GizmoPainter({required this.app, required this.config});

  static final Paint _aabbPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = const Color(0xFFFF00FF); // magenta

  static final Paint _colliderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = const Color(0xFF00FF00); // green

  static final Paint _frustumPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = const Color(0xFFFFFF00); // yellow

  @override
  void paint(Canvas canvas, Size size) {
    final world = app.world;

    // Gizmos draw in world space, so follow the active camera the
    // same way the sprite pass does. Falls through to world = screen
    // when no ActiveCameraView resource is installed.
    withActiveCameraCanvas(world, canvas, size, () {
      if (config.showAabbGizmos) {
        _paintAabbs(world, canvas, size);
      }
      if (config.showColliderGizmos) {
        _paintColliders(world, canvas, size);
      }
      if (config.showCameraFrustum) {
        _paintCameraFrustum(world, canvas, size);
      }
    });
  }

  void _paintAabbs(World world, Canvas canvas, Size size) {
    for (final entry in _colliderEntities(world)) {
      final transform = entry.$2;
      final collider = entry.$3;
      final bounds = collider.bounds;
      if (bounds.width == 0 && bounds.height == 0) continue;
      final worldRect = bounds.shift(Offset(transform.x, transform.y));
      final screenRect = _rectWorldToScreen(worldRect, size);
      canvas.drawRect(screenRect, _aabbPaint);
    }
  }

  void _paintColliders(World world, Canvas canvas, Size size) {
    for (final entry in _colliderEntities(world)) {
      final transform = entry.$2;
      final collider = entry.$3;
      for (final shape in collider.shapes) {
        _paintShape(canvas, size, shape, transform);
      }
    }
  }

  void _paintShape(
    Canvas canvas,
    Size size,
    CollisionShape shape,
    GlobalTransform2D transform,
  ) {
    final dx = transform.x;
    final dy = transform.y;
    if (shape is RectangleShape) {
      final worldRect = Rect.fromLTWH(
        shape.x + dx,
        shape.y + dy,
        shape.width,
        shape.height,
      );
      canvas.drawRect(_rectWorldToScreen(worldRect, size), _colliderPaint);
    } else if (shape is EllipseShape) {
      final worldRect = Rect.fromCenter(
        center: Offset(shape.centerX + dx, shape.centerY + dy),
        width: shape.radiusX * 2,
        height: shape.radiusY * 2,
      );
      canvas.drawOval(_rectWorldToScreen(worldRect, size), _colliderPaint);
    } else if (shape is PolygonShape) {
      final path = _pathFromPoints(
        shape.worldPoints,
        dx,
        dy,
        size,
        close: true,
      );
      if (path != null) canvas.drawPath(path, _colliderPaint);
    } else if (shape is PolylineShape) {
      final path = _pathFromPoints(
        shape.worldPoints,
        dx,
        dy,
        size,
        close: false,
      );
      if (path != null) canvas.drawPath(path, _colliderPaint);
    } else if (shape is PointShape) {
      final screen = _worldToScreen(shape.x + dx, shape.y + dy, size);
      canvas.drawCircle(screen, 2.0, _colliderPaint);
    }
    // Unknown shape kinds are silently skipped — better than crashing
    // when a new shape type ships before this file catches up.
  }

  Path? _pathFromPoints(
    List<Offset> points,
    double dx,
    double dy,
    Size size, {
    required bool close,
  }) {
    if (points.isEmpty) return null;
    final path = Path();
    final first = _worldToScreen(
      points.first.dx + dx,
      points.first.dy + dy,
      size,
    );
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final p = _worldToScreen(points[i].dx + dx, points[i].dy + dy, size);
      path.lineTo(p.dx, p.dy);
    }
    if (close) path.close();
    return path;
  }

  void _paintCameraFrustum(World world, Canvas canvas, Size size) {
    // Pick the first active camera. When there are several the
    // first-listed wins — the same policy the render pipeline uses
    // (it renders per-camera; the frustum overlay picks a single
    // representative).
    Camera2D? camera;
    GlobalTransform2D? cameraTransform;
    for (final (_, cam, transform)
        in world.query2<Camera2D, GlobalTransform2D>().iter()) {
      if (!cam.isActive) continue;
      camera = cam;
      cameraTransform = transform;
      break;
    }
    if (camera == null || cameraTransform == null) return;

    // Visible world rect: centred on the camera transform, extent
    // taken from the projection at the current canvas size. Under a
    // 1:1 world→screen mapping this outlines the same area the sprite
    // pipeline draws through the camera.
    final renderSize = RenderSize(size.width, size.height);
    final halfW = camera.projection.visibleWidth(renderSize) / 2.0;
    final halfH = camera.projection.visibleHeight(renderSize) / 2.0;
    final cx = cameraTransform.x;
    final cy = cameraTransform.y;

    final worldRect = Rect.fromLTRB(
      cx - halfW,
      cy - halfH,
      cx + halfW,
      cy + halfH,
    );
    canvas.drawRect(_rectWorldToScreen(worldRect, size), _frustumPaint);
  }

  /// Materialise (entity, transform, collider) triples into a list up
  /// front — the query iterator's snapshot spares us from holding an
  /// active iteration across the paint call.
  List<(Entity, GlobalTransform2D, Collider)> _colliderEntities(World world) {
    final out = <(Entity, GlobalTransform2D, Collider)>[];
    for (final (entity, transform, collider)
        in world.query2<GlobalTransform2D, Collider>().iter()) {
      out.add((entity, transform, collider));
    }
    return out;
  }

  /// Convert a world point to screen (canvas-local) coordinates.
  ///
  /// Currently a straight pass-through — see the class-level doc on
  /// [DebugGizmosLayer] for the "camera transform is a follow-up"
  /// note. The unused [size] parameter is retained so future work can
  /// plug in `Camera2D.worldToScreen` without touching every call
  /// site.
  Offset _worldToScreen(double x, double y, Size size) => Offset(x, y);

  Rect _rectWorldToScreen(Rect worldRect, Size size) {
    final tl = _worldToScreen(worldRect.left, worldRect.top, size);
    final br = _worldToScreen(worldRect.right, worldRect.bottom, size);
    return Rect.fromPoints(tl, br);
  }

  @override
  bool shouldRepaint(covariant _GizmoPainter oldDelegate) => true;
}
