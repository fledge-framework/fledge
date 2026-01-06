// ignore_for_file: avoid_print
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_save/fledge_save.dart';

// Example: Make a resource saveable
class Inventory with Saveable {
  final List<String> items = [];

  @override
  String get saveKey => 'inventory';

  @override
  Map<String, dynamic> toSaveJson() => {'items': items};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    items.clear();
    items.addAll((json['items'] as List?)?.cast<String>() ?? []);
  }
}

class PlayerProgress with Saveable {
  int level = 1;
  int experience = 0;

  @override
  String get saveKey => 'progress';

  @override
  Map<String, dynamic> toSaveJson() => {
    'level': level,
    'experience': experience,
  };

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    level = json['level'] as int? ?? 1;
    experience = json['experience'] as int? ?? 0;
  }
}

void main() async {
  // Create saveable resources
  final inventory = Inventory()..items.addAll(['sword', 'shield', 'potion']);
  final progress =
      PlayerProgress()
        ..level = 5
        ..experience = 1250;

  // Set up app with save plugin
  final savePlugin = SavePlugin(
    config: const SaveConfig(gameDirectory: 'ExampleGame'),
  );

  final app = App()..addPlugin(savePlugin);

  // Register saveables after adding the plugin
  savePlugin.registerSaveable(inventory);
  savePlugin.registerSaveable(progress);

  // Initialize
  await app.tick();

  // Get the save manager
  final saveManager = app.world.getResource<SaveManager>()!;

  // Check for existing saves
  final hasSave = await saveManager.hasSaveFile('slot1');
  print('Has existing save: $hasSave');

  // Save the game
  final saved = await saveManager.save(
    app.world,
    slotName: 'slot1',
    metadata: {'checkpoint': 'town_square'},
  );
  print('Game saved: $saved');

  // Modify the state
  inventory.items.add('bow');
  progress.level = 10;

  // Load the previous save
  final loaded = await saveManager.load(app.world, slotName: 'slot1');
  print('Game loaded: $loaded');
  print('Inventory after load: ${inventory.items}');
  print('Level after load: ${progress.level}');

  // Request-based saving (for use in ECS systems)
  saveManager.requestSave(metadata: {'playerX': 100, 'playerY': 200});
  if (saveManager.saveRequested) {
    final metadata = saveManager.pendingMetadata;
    saveManager.clearSaveRequest();
    await saveManager.save(app.world, slotName: 'autosave', metadata: metadata);
    print('Autosave completed with metadata: $metadata');
  }

  // List all save slots
  final slots = await saveManager.listSaveSlots();
  for (final slot in slots) {
    print('Slot: ${slot.slotName}, saved at: ${slot.timestamp}');
  }

  print('Save system example completed');
}
