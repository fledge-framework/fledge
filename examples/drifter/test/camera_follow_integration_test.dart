import 'package:drifter_example/game_app.dart';
import 'package:drifter_example/components.dart';
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end check that Phase 6a's [CameraFollowSystem] is actually
/// wired into Drifter — after `spawnScene` a camera exists, and
/// ticking the app moves the camera toward the player position.
void main() {
  testWidgets('camera follows the player after spawnScene', (tester) async {
    final app = buildApp();
    spawnScene(app);
    await app.tick();
    await tester.pump();

    // A single camera entity should exist.
    final cameras = app.world.query1<Camera2D>().iter().toList();
    expect(cameras, hasLength(1),
        reason: 'spawnScene should create exactly one camera');

    final cameraEntity = cameras.first.$1;
    expect(app.world.get<CameraFollow>(cameraEntity), isNotNull);

    // Move the player far off-centre and tick. The camera should
    // lerp toward the new player position (not snap — smoothing=0.15).
    final (player, playerTransform) = app.world
        .query1<Transform2D>(filter: const With<Player>())
        .iter()
        .first;
    // Silence unused_local: `player` proves the query returns the marker.
    expect(app.world.get<Player>(player), isNotNull);
    playerTransform.translation.x = 100;
    playerTransform.translation.y = 100;

    // Store starting camera position.
    final cameraTransform = app.world.get<Transform2D>(cameraEntity)!;
    final startX = cameraTransform.translation.x;
    final startY = cameraTransform.translation.y;

    // Advance a few ticks; camera should move toward player.
    for (var i = 0; i < 5; i++) {
      await app.tick();
    }

    final endX = cameraTransform.translation.x;
    final endY = cameraTransform.translation.y;
    // Camera should have moved closer to (100, 100) than it started.
    expect(
      (endX - 100).abs(),
      lessThan((startX - 100).abs()),
      reason: 'camera X should converge toward player X',
    );
    expect(
      (endY - 100).abs(),
      lessThan((startY - 100).abs()),
      reason: 'camera Y should converge toward player Y',
    );
  });
}
