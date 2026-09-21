/// A single save-format migration step.
///
/// Receives the decoded save file (the full top-level map, including
/// `version`, `timestamp`, `metadata` and `resources`) at version `N` and
/// returns the equivalent data at version `N + 1`. The [SaveManager] sets
/// `version` on the returned map itself, so steps don't need to.
///
/// Steps may mutate and return [data] or build a new map.
typedef SaveMigration =
    Map<String, dynamic> Function(Map<String, dynamic> data);

/// Configuration for the save system.
///
/// Passed to [SavePlugin] to customize save behavior.
class SaveConfig {
  /// Subdirectory name for save files within the base directory.
  ///
  /// Example: 'MyGame' creates saves in `Documents/MyGame/`
  final String gameDirectory;

  /// Current save format version.
  ///
  /// Increment this when making breaking changes to save format, and add
  /// a matching entry to [migrations] so older files can be upgraded.
  /// Files written with a version greater than this are refused.
  final int formatVersion;

  /// Default slot name for single-slot saves.
  ///
  /// Used when no slot name is specified.
  final String defaultSlot;

  /// Migration steps keyed by the version they migrate **from**.
  ///
  /// When a file with version `v < formatVersion` is loaded, the steps
  /// `migrations[v]`, `migrations[v + 1]`, ... `migrations[formatVersion - 1]`
  /// are applied in order before any resource is restored. If any step in
  /// the chain is missing the load fails (returns `null`) without touching
  /// the world.
  ///
  /// If this map is empty (the default), older files are loaded as-is with
  /// no migration — the pre-migration behavior.
  final Map<int, SaveMigration> migrations;

  /// Whether to keep the previous save as `<slot>.backup.json`.
  ///
  /// When true, every successful save moves the existing `<slot>.json`
  /// to `<slot>.backup.json` before the new file takes its place. Load it
  /// with `SaveManager.load(world, fromBackup: true)`.
  final bool keepBackup;

  /// Absolute directory to store saves under, instead of the platform
  /// application documents directory (from `path_provider`).
  ///
  /// Saves go to `<baseDirectory>/<gameDirectory>/`. Useful for tests,
  /// portable installs, and custom save locations.
  final String? baseDirectory;

  /// Creates save configuration.
  ///
  /// [gameDirectory] - Subdirectory for saves (default: 'saves')
  /// [formatVersion] - Save format version for migration (default: 1)
  /// [defaultSlot] - Default save slot name (default: 'save')
  /// [migrations] - Migration steps keyed by from-version (default: none)
  /// [keepBackup] - Keep the previous save as a backup (default: false)
  /// [baseDirectory] - Overrides the documents directory (default: null)
  const SaveConfig({
    this.gameDirectory = 'saves',
    this.formatVersion = 1,
    this.defaultSlot = 'save',
    this.migrations = const {},
    this.keepBackup = false,
    this.baseDirectory,
  });

  /// Default configuration.
  const SaveConfig.defaults() : this();
}

/// Information about a save slot.
///
/// Returned by [SaveManager.listSaveSlots] to display
/// save file information without loading the full save.
class SaveSlotInfo {
  /// Slot name/identifier.
  final String slotName;

  /// When the save was created.
  final DateTime timestamp;

  /// Save format version.
  final int formatVersion;

  /// Optional metadata stored with the save.
  ///
  /// Can contain game-specific info like player name, play time, etc.
  final Map<String, dynamic> metadata;

  const SaveSlotInfo({
    required this.slotName,
    required this.timestamp,
    required this.formatVersion,
    this.metadata = const {},
  });
}
