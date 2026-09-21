import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/save_config.dart';
import '../traits/saveable.dart';

const _logName = 'fledge_save';
const _saveSuffix = '.json';
const _backupSuffix = '.backup.json';
const _tempSuffix = '.tmp';

/// Resource managing save/load operations.
///
/// Aggregates state from all [Saveable] resources and handles file I/O.
/// Save files are stored in the application documents directory, or in
/// [SaveConfig.baseDirectory] when set.
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
  /// Creates the save directory and caches slot information. Optional:
  /// [save], [load] and [listSaveSlots] work without it (the directory is
  /// created on first save). Call it at startup if you want the slot list
  /// warmed up front.
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

  /// Check if a backup file (`<slot>.backup.json`) exists for the given slot.
  ///
  /// Backups are only written when [SaveConfig.keepBackup] is true.
  Future<bool> hasBackup([String? slotName]) async {
    final slot = slotName ?? config.defaultSlot;
    final file = await _getBackupFile(slot);
    return file.exists();
  }

  /// List all available save slots.
  ///
  /// Returns cached information if available, otherwise reads from disk.
  /// Backup (`.backup.json`) and temporary (`.tmp`) files are not slots.
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
  /// The write is crash-safe: data goes to `<slot>.json.tmp` first (flushed),
  /// and is then renamed over `<slot>.json`, so an interrupted save never
  /// leaves a truncated current file. When [SaveConfig.keepBackup] is true
  /// the previous `<slot>.json` is moved to `<slot>.backup.json` first.
  ///
  /// [world] - The ECS world containing saveable resources
  /// [slotName] - Save slot identifier (uses default if not specified)
  /// [metadata] - Optional game-specific data (player position, etc.)
  Future<bool> save(
    World world, {
    String? slotName,
    Map<String, dynamic>? metadata,
  }) async {
    final slot = slotName ?? config.defaultSlot;
    try {
      final saveData = _collectSaveData(world, metadata);
      final json = const JsonEncoder.withIndent('  ').convert(saveData);

      await _ensureSaveDirectory();
      final file = await _getSaveFile(slot);
      final tmp = await _getTempFile(slot);

      await tmp.writeAsString(json, flush: true);

      if (config.keepBackup && await file.exists()) {
        final backup = await _getBackupFile(slot);
        await file.rename(backup.path);
      }

      await tmp.rename(file.path);

      // Refresh cache
      await _refreshSlotCache();

      return true;
    } catch (e, st) {
      developer.log(
        'Failed to save slot "$slot"',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Load game state from a save file.
  ///
  /// Applies any [SaveConfig.migrations] needed to bring an older file up
  /// to [SaveConfig.formatVersion], then restores data to all [Saveable]
  /// resources. Returns the metadata from the save, or null if the load
  /// failed — the file is missing or unreadable, it was written by a newer
  /// format version, or a migration step is missing — or if the save was
  /// written without metadata. On failure no resource is touched.
  ///
  /// [world] - The ECS world containing saveable resources
  /// [slotName] - Save slot to load (uses default if not specified)
  /// [fromBackup] - Load `<slot>.backup.json` instead of `<slot>.json`
  Future<Map<String, dynamic>?> load(
    World world, {
    String? slotName,
    bool fromBackup = false,
  }) async {
    final slot = slotName ?? config.defaultSlot;
    try {
      final file = fromBackup
          ? await _getBackupFile(slot)
          : await _getSaveFile(slot);

      if (!await file.exists()) {
        return null;
      }

      final json = await file.readAsString();
      final saveData = _migrate(
        jsonDecode(json) as Map<String, dynamic>,
        file.path,
      );
      if (saveData == null) return null;

      return _restoreSaveData(world, saveData);
    } catch (e, st) {
      developer.log(
        'Failed to load slot "$slot"${fromBackup ? ' (backup)' : ''}',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Bring [saveData] up to [SaveConfig.formatVersion].
  ///
  /// Returns null (and logs) if the file is too new or a step is missing.
  Map<String, dynamic>? _migrate(Map<String, dynamic> saveData, String path) {
    final fileVersion = saveData['version'] as int? ?? 0;

    if (fileVersion > config.formatVersion) {
      developer.log(
        'Refusing to load $path: file version $fileVersion is newer than '
        'supported format version ${config.formatVersion}',
        name: _logName,
      );
      return null;
    }

    // Backward compatibility: with no migrations registered, older files
    // load as-is (pre-migration behavior).
    if (config.migrations.isEmpty) return saveData;

    var data = saveData;
    for (var v = fileVersion; v < config.formatVersion; v++) {
      final step = config.migrations[v];
      if (step == null) {
        developer.log(
          'Cannot load $path: no migration registered from version $v to '
          '${v + 1} (file version $fileVersion, format version '
          '${config.formatVersion})',
          name: _logName,
        );
        return null;
      }
      data = Map<String, dynamic>.of(step(data));
      data['version'] = v + 1;
    }
    return data;
  }

  /// Delete a save file, along with its backup and any leftover temp file.
  ///
  /// Returns true if deletion was successful or file didn't exist.
  Future<bool> deleteSave([String? slotName]) async {
    final slot = slotName ?? config.defaultSlot;
    try {
      for (final file in [
        await _getSaveFile(slot),
        await _getBackupFile(slot),
        await _getTempFile(slot),
      ]) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Refresh cache
      await _refreshSlotCache();

      return true;
    } catch (e, st) {
      developer.log(
        'Failed to delete slot "$slot"',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Get the save directory path.
  Future<Directory> _getSaveDirectory() async {
    final base =
        config.baseDirectory ?? (await getApplicationDocumentsDirectory()).path;
    return Directory(p.join(base, config.gameDirectory));
  }

  /// Get the save file for a slot.
  Future<File> _getSaveFile(String slotName) async {
    final saveDir = await _getSaveDirectory();
    return File(p.join(saveDir.path, '$slotName$_saveSuffix'));
  }

  /// Get the backup file for a slot.
  Future<File> _getBackupFile(String slotName) async {
    final saveDir = await _getSaveDirectory();
    return File(p.join(saveDir.path, '$slotName$_backupSuffix'));
  }

  /// Get the in-progress temp file for a slot.
  Future<File> _getTempFile(String slotName) async {
    final saveDir = await _getSaveDirectory();
    return File(p.join(saveDir.path, '$slotName$_saveSuffix$_tempSuffix'));
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
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.endsWith(_saveSuffix) ||
          name.endsWith(_backupSuffix) ||
          name.endsWith(_tempSuffix)) {
        continue;
      }

      try {
        final content = await entity.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        final slotName = name.substring(0, name.length - _saveSuffix.length);

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
      } catch (e, st) {
        // Skip corrupted save files
        developer.log(
          'Skipping unreadable save file ${entity.path}',
          name: _logName,
          error: e,
          stackTrace: st,
        );
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
  /// Default implementation auto-discovers any resource in [world] that
  /// mixes in [Saveable]. Override in subclasses to merge with manually
  /// registered saveables (see [SaveManagerWithSaveables]).
  Iterable<Saveable> getSaveableResources(World world) {
    return world.resourcesOfType<Saveable>();
  }
}
