import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_test/flutter_test.dart';

/// Batch 7 item 29: a DebugConfig that was already inserted before
/// DebugPlugin.build runs must survive the plugin's build step.
void main() {
  test('DebugPlugin keeps a pre-existing DebugConfig', () {
    final app = App();
    // Game inserts its own — everything off.
    final gameConfig = const DebugConfig(
      showFps: false,
      showEntityCount: false,
      showOrderingAmbiguities: false,
    );
    app.insertResource(gameConfig);

    app.addPlugin(const DebugPlugin());

    // Same instance survives; the plugin's default DebugConfig() with
    // showFps etc. on didn't overwrite it.
    final resolved = app.world.getResource<DebugConfig>();
    expect(identical(resolved, gameConfig), isTrue);
    expect(resolved!.showFps, isFalse);
    expect(resolved.showEntityCount, isFalse);
    expect(resolved.showOrderingAmbiguities, isFalse);
  });

  test('DebugPlugin still installs its config when none exists', () {
    final app = App();
    const pluginConfig = DebugConfig(showAabbGizmos: true);
    app.addPlugin(const DebugPlugin(config: pluginConfig));
    final resolved = app.world.getResource<DebugConfig>();
    expect(resolved, isNotNull);
    expect(resolved!.showAabbGizmos, isTrue);
  });
}
