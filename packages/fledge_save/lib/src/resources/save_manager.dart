import 'dart:convert';
import 'dart:io';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:path_provider/path_provider.dart';

import '../config/save_config.dart';
import '../traits/saveable.dart';

/// Resource managing save/load operations.
///
/// Aggregates state from all [Saveable] resources and handles file I/O.
/// Save files are stored in the application documents directory.
///
/// ## Save Flow
///
/// The save system uses a request pattern to bridge ECS and async I/O:
///
/// 1. ECS system sets [saveRequested] when trigger occurs (e.g., sleep, checkpoint)
/// 2. Flutter widget layer checks [saveRequested] in game loop
/// 3. Widget calls [save] with current World
/// 4. [saveRequested] is reset after save completes
///
/// ## Usage
///
/// ```dart
/// // In ECS system (synchronous)
/// final saveManager = world.getResource<SaveManager>();
/// saveManager?.requestSave(metadata: {'playerX': 100, 'playerY': 200});
///
/// // In Flutter game loop (async)
/// if (saveManager.saveRequested) {
///   saveManager.clearSaveRequest();
///   await saveManager.save(world, 'slot1');
/// }
/// ```
class SaveManager {
  final SaveConfig config;

  /// Whether save file existence has been checked.
  bool _initialized = false;

  /// Cached list of available save slots.
  List<SaveSlotInfo>? _cachedSlots;

  /// Whether a save was requested (set by ECS, consumed by Flutter).
  bool saveRequested = false;

  /// Metadata to include with the requested save.
  ///
  /// Game-specific data like player position, current scene, etc.
  Map<String, dynamic>? pendingMetadata;

  /// Creates a save manager with the given configuration.
  SaveManager({this.config = const SaveConfig.defaults()});

  /// Whether the manager has been initialized.
  bool get isInitialized => _initialized;

  /// Request a save with optional metadata.
  ///
  /// Called by ECS systems. The actual save is performed asynchronously
  /// by the Flutter layer when it processes the request.
  void requestSave({Map<String, dynamic>? metadata}) {
    saveRequested = true;
    pendingMetadata = metadata;
  }

  /// Clear save request after processing.
  void clearSaveRequest() {
    saveRequested = false;
    pendingMetadata = null;
  }

  /// Initialize the save manager.
  ///
  /// Checks for existing save files and caches slot information.
  /// Call this during game startup.
  Future<void> initialize() async {
    if (_initialized) return;

    await _ensureSaveDirectory();
    await _refreshSlotCache();
    _initialized = true;
  }

  /// Check if a save file exists for the given slot.
  Future<bool> hasSaveFile([String? slotName]) async {
    final slot = slotName ?? config.defaultSlot;
    final file = await _getSaveFile(slot);
    return file.exists();
  }

  /// List all available save slots.
  ///
  /// Returns cached information if available, otherwise reads from disk.
  Future<List<SaveSlotInfo>> listSaveSlots() async {
    if (_cachedSlots == null) {
      await _refreshSlotCache();
    }
    return List.unmodifiable(_cachedSlots ?? []);
  }

  /// Save the current game state.
  ///
  /// Collects data from all [Saveable] resources and writes to disk.
  /// Returns true if save was successful.
  ///
  /// [world] - The ECS world containing saveable resources
  /// [slotName] - Save slot identifier (uses default if not specified)
  /// [metadata] - Optional game-specific data (player position, etc.)
  Future<bool> save(
    World world, {
    String? slotName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final slot = slotName ?? config.defaultSlot;
      final saveData = _collectSaveData(world, metadata);
      final json = const JsonEncoder.withIndent('  ').convert(saveData);

      final file = await _getSaveFile(slot);
      await file.writeAsString(json);

      // Refresh cache
      await _refreshSlotCache();

      return true;
    } catch (e) {
      // Log error but don't crash
      return false;
    }
  }

  /// Load game state from a save file.
  ///
  /// Restores data to all [Saveable] resources.
  /// Returns the metadata from the save, or null if load failed.
  ///
  /// [world] - The ECS world containing saveable resources
  /// [slotName] - Save slot to load (uses default if not specified)
  Future<Map<String, dynamic>?> load(World world, {String? slotName}) async {
    try {
      final slot = slotName ?? config.defaultSlot;
      final file = await _getSaveFile(slot);

      if (!await file.exists()) {
        return null;
      }

      final json = await file.readAsString();
      final saveData = jsonDecode(json) as Map<String, dynamic>;

      // Check version compatibility
      final version = saveData['version'] as int? ?? 0;
      if (version > config.formatVersion) {
        // Save file is from a newer version - can't load
        return null;
      }

      return _restoreSaveData(world, saveData);
    } catch (e) {
      // Log error but don't crash
      return null;
    }
  }

  /// Delete a save file.
  ///
  /// Returns true if deletion was successful or file didn't exist.
  Future<bool> deleteSave([String? slotName]) async {
    try {
      final slot = slotName ?? config.defaultSlot;
      final file = await _getSaveFile(slot);

      if (await file.exists()) {
        await file.delete();
      }

      // Refresh cache
      await _refreshSlotCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the save directory path.
  Future<Directory> _getSaveDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/${config.gameDirectory}');
  }

  /// Get the save file for a slot.
  Future<File> _getSaveFile(String slotName) async {
    final saveDir = await _getSaveDirectory();
    return File('${saveDir.path}/$slotName.json');
  }

  /// Ensure the save directory exists.
  Future<void> _ensureSaveDirectory() async {
    final saveDir = await _getSaveDirectory();
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
  }

  /// Refresh the cached list of save slots.
  Future<void> _refreshSlotCache() async {
    final slots = <SaveSlotInfo>[];
    final saveDir = await _getSaveDirectory();

    if (!await saveDir.exists()) {
      _cachedSlots = slots;
      return;
    }

    await for (final entity in saveDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;

          final slotName = entity.path.split('/').last.replaceAll('.json', '');

          slots.add(
            SaveSlotInfo(
              slotName: slotName,
              timestamp:
                  DateTime.tryParse(data['timestamp'] as String? ?? '') ??
                  DateTime.now(),
              formatVersion: data['version'] as int? ?? 1,
              metadata: data['metadata'] as Map<String, dynamic>? ?? {},
            ),
          );
        } catch (e) {
          // Skip corrupted save files
        }
      }
    }

    // Sort by timestamp (newest first)
    slots.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _cachedSlots = slots;
  }

  /// Collect all saveable data from resources.
  Map<String, dynamic> _collectSaveData(
    World world,
    Map<String, dynamic>? metadata,
  ) {
    final resourceData = <String, dynamic>{};

    // Find all Saveable resources
    for (final resource in getSaveableResources(world)) {
      resourceData[resource.saveKey] = resource.toSaveJson();
    }

    return {
      'version': config.formatVersion,
      'timestamp': DateTime.now().toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      'resources': resourceData,
    };
  }

  /// Restore save data to resources.
  ///
  /// Returns the metadata from the save.
  Map<String, dynamic>? _restoreSaveData(
    World world,
    Map<String, dynamic> saveData,
  ) {
    final resourceData = saveData['resources'] as Map<String, dynamic>? ?? {};

    // Restore each Saveable resource
    for (final resource in getSaveableResources(world)) {
      final data = resourceData[resource.saveKey] as Map<String, dynamic>?;
      if (data != null) {
        resource.loadFromSaveJson(data);
      }
    }

    return saveData['metadata'] as Map<String, dynamic>?;
  }

  /// Get all Saveable resources.
  ///
  /// Override this in subclasses to provide custom saveable discovery.
  /// Default implementation returns empty - use [SaveManagerWithSaveables]
  /// or register saveables via [SavePlugin].
  Iterable<Saveable> getSaveableResources(World world) {
    // Default: return empty, games use SavePlugin to register saveables
    return const [];
  }
}

/// Extension to get resources of a specific type from World.
extension SaveableWorldExtension on World {
  /// Get all resources that implement the given type.
  ///
  /// This is used by SaveManager to find all Saveable resources.
  Iterable<T> getResourcesOfType<T>() {
    // This requires the World to track resource types
    // For now, return empty - games will need to register saveables
    // TODO: Implement proper resource type iteration in fledge_ecs
    return <T>[];
  }
}
