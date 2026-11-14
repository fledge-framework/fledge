import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A small JSON file of the player's preferences (volume, keys, display),
/// kept beside the saves but apart from them: it belongs to the machine, not
/// to a save, and is read before any save is loaded.
///
/// Writes are crash-safe like [SaveManager.save]: the data goes to
/// `<name>.json.tmp` first and is renamed over `<name>.json`.
///
/// ```dart
/// final prefs = PreferencesFile(gameDirectory: 'MyGame');
/// final data = await prefs.read() ?? {};
/// await prefs.write({...data, 'music': 0.6});
/// ```
class PreferencesFile {
  PreferencesFile({
    required this.gameDirectory,
    this.name = 'settings',
    this.baseDirectory,
  });

  /// The folder under [baseDirectory], usually the game's
  /// [SaveConfig.gameDirectory] so preferences sit with the saves.
  final String gameDirectory;

  /// The file's name, without `.json`.
  final String name;

  /// Overrides the documents directory (tests, portable installs).
  final String? baseDirectory;

  static const _logName = 'fledge_save.preferences';

  Future<File> _file([String suffix = '']) async {
    final base =
        baseDirectory ?? (await getApplicationDocumentsDirectory()).path;
    return File(p.join(base, gameDirectory, '$name.json$suffix'));
  }

  /// The stored preferences, or null if there are none yet or the file
  /// can't be read (a broken file falls back to defaults rather than
  /// stopping the game).
  Future<Map<String, Object?>?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, Object?> ? data : null;
    } catch (e, st) {
      developer.log(
        'Failed to read $name',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Replaces the stored preferences with [data]. Returns false if the
  /// write failed; the previous file is then left as it was.
  Future<bool> write(Map<String, Object?> data) async {
    try {
      final file = await _file();
      final tmp = await _file('.tmp');
      await file.parent.create(recursive: true);
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
      await tmp.rename(file.path);
      return true;
    } catch (e, st) {
      developer.log(
        'Failed to write $name',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
