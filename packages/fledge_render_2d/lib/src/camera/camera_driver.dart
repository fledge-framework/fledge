import 'package:fledge_ecs/fledge_ecs.dart' show Entity;
import 'package:fledge_render/fledge_render.dart';

import '../transform/global_transform.dart';
import 'camera2d.dart';

/// Render node that sets up the camera for subsequent nodes.
///
/// This node queries for active cameras and outputs the view data
/// for use by render nodes that need camera information.
class CameraDriverNode implements RenderNode {
  final RenderSize _screenSize;

  /// Creates a camera driver node.
  ///
  /// The [screenSize] is the current render target size.
  CameraDriverNode(this._screenSize);

  @override
  String get name => 'camera_driver_2d';

  @override
  List<SlotInfo> get inputs => const [];

  @override
  List<SlotInfo> get outputs => const [
        SlotInfo(name: 'view', type: SlotType.camera),
      ];

  @override
  void run(RenderGraphContext graph, Object context) {
    if (context is! CameraDriverContext) {
      throw ArgumentError(
          'CameraDriverNode requires CameraDriverContext, got ${context.runtimeType}');
    }

    final renderWorld = context.renderWorld;

    // Find active camera with lowest order
    Camera2D? bestCamera;
    GlobalTransform2D? bestTransform;
    Entity? bestEntity;
    var bestOrder = double.maxFinite.toInt();

    for (final (entity, camera, transform)
        in renderWorld.query2<Camera2D, GlobalTransform2D>().iter()) {
      if (!camera.isActive) continue;

      if (camera.order < bestOrder) {
        bestOrder = camera.order;
        bestCamera = camera;
        bestTransform = transform;
        bestEntity = entity;
      }
    }

    if (bestCamera == null || bestTransform == null || bestEntity == null) {
      return;
    }

    final vpMatrix =
        bestCamera.viewProjectionMatrix(bestTransform, _screenSize);

    graph.setOutput(
      'view',
      SlotValue(
        SlotType.camera,
        CameraView(bestEntity, vpMatrix, bestCamera.viewport),
      ),
    );
  }
}

/// Context for the camera driver node.
class CameraDriverContext {
  /// The render world containing camera entities.
  final RenderWorld renderWorld;

  /// Creates a camera driver context.
  CameraDriverContext(this.renderWorld);
}
