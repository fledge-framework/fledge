/// Configuration for the save system.
///
/// Passed to [SavePlugin] to customize save behavior.
class SaveConfig {
  /// Subdirectory name for save files within the app documents directory.
  ///
  /// Example: 'MyGame' creates saves in `Documents/MyGame/saves/`
  final String gameDirectory;

  /// Current save format version.
  ///
  /// Increment this when making breaking changes to save format.
  /// The [SaveManager] includes this in save files and can use it
  /// for migration logic.
  final int formatVersion;

  /// Default slot name for single-slot saves.
  ///
  /// Used when no slot name is specified.
  final String defaultSlot;

  /// Creates save configuration.
  ///
  /// [gameDirectory] - Subdirectory for saves (default: 'saves')
  /// [formatVersion] - Save format version for migration (default: 1)
  /// [defaultSlot] - Default save slot name (default: 'save')
  const SaveConfig({
    this.gameDirectory = 'saves',
    this.formatVersion = 1,
    this.defaultSlot = 'save',
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
