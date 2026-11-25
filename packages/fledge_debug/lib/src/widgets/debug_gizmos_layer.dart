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
    show
        ActiveCameraView,
        GlobalTransform2D,
        activeCameraVisibleWorldRect,
        activeCameraZoom,
        withActiveCameraCanvas;
import 'package:flutter/foundation.dart' show visibleForTesting;
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
/// Gizmos are drawn in world space through the active camera, with the
/// same translation and zoom `FledgeRenderView` uses (from the
/// `ActiveCameraView` resource that `CameraPlugin` publishes), so they
/// line up with the sprites underneath. Without that resource the world
/// is drawn 1:1 (world = screen), as the render view does.
///
/// The camera-frustum gizmo outlines the world area the lowest-`order`
/// active [Camera2D] shows in this widget (see
/// [debugCameraFrustumWorldRect]). Under a full-screen camera that is the
/// widget's own edge, drawn just inside it.
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
    final worldRect = debugCameraFrustumWorldRect(world, size);
    if (worldRect == null) return;
    // Pull the outline in by half its stroke so a frustum on the widget's
    // edge is still visible. The canvas is in world units at the camera's
    // zoom, so convert the stroke from logical pixels.
    final zoom = world.hasResource<ActiveCameraView>()
        ? activeCameraZoom(world, size)
        : 1.0;
    final inset = _frustumPaint.strokeWidth / 2 / zoom;
    canvas.drawRect(
      _rectWorldToScreen(worldRect.deflate(inset), size),
      _frustumPaint,
    );
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

  /// Convert a world point to coordinates on the gizmo canvas. The canvas
  /// is already in world space (see [withActiveCameraCanvas]), so this is
  /// the identity.
  Offset _worldToScreen(double x, double y, Size size) => Offset(x, y);

  Rect _rectWorldToScreen(Rect worldRect, Size size) {
    final tl = _worldToScreen(worldRect.left, worldRect.top, size);
    final br = _worldToScreen(worldRect.right, worldRect.bottom, size);
    return Rect.fromPoints(tl, br);
  }

  @override
  bool shouldRepaint(covariant _GizmoPainter oldDelegate) => true;
}

/// The world-space rectangle the camera-frustum gizmo outlines in a
/// widget of [size], or `null` when there is no active camera.
///
/// The camera is the lowest-`order` active [Camera2D], the one
/// `ActiveCameraViewSystem` publishes. With an `ActiveCameraView` resource
/// the rect is exactly what the widget render path shows
/// ([activeCameraVisibleWorldRect], shake and zoom included). Without one
/// it is the area that camera would show: centred on its
/// `GlobalTransform2D`, [size] divided by [Camera2D.widgetZoom].
@visibleForTesting
Rect? debugCameraFrustumWorldRect(World world, Size size) {
  Camera2D? camera;
  GlobalTransform2D? cameraTransform;
  for (final (_, cam, transform)
      in world.query2<Camera2D, GlobalTransform2D>().iter()) {
    if (!cam.isActive) continue;
    if (camera == null || cam.order < camera.order) {
      camera = cam;
      cameraTransform = transform;
    }
  }
  if (camera == null || cameraTransform == null) return null;

  if (world.hasResource<ActiveCameraView>()) {
    return activeCameraVisibleWorldRect(world, size);
  }
  final zoom = camera.widgetZoom(size);
  return Rect.fromCenter(
    center: Offset(cameraTransform.x, cameraTransform.y),
    width: size.width / zoom,
    height: size.height / zoom,
  );
}
