import 'dart:ui';

/// Information about a single display/monitor.
class Display {
  /// Display index (0-based).
  final int index;

  /// Display name (e.g., "DELL U2718Q").
  final String name;

  /// Native resolution of the display.
  final Size size;

  /// Display bounds in virtual screen coordinates.
  ///
  /// This includes the position of the display in multi-monitor setups.
  final Rect bounds;

  /// Display scale factor (DPI scaling).
  ///
  /// 1.0 = 100%, 1.5 = 150%, 2.0 = 200%, etc.
  final double scaleFactor;

  /// Refresh rate in Hz.
  final double refreshRate;

  /// Whether this is the primary display.
  final bool isPrimary;

  /// Creates display information.
  const Display({
    required this.index,
    required this.name,
    required this.size,
    required this.bounds,
    required this.scaleFactor,
    required this.refreshRate,
    required this.isPrimary,
  });

  @override
  String toString() {
    return 'Display($name, ${size.width.toInt()}x${size.height.toInt()}, '
        '${refreshRate.toInt()}Hz${isPrimary ? ', primary' : ''})';
  }
}

/// Resource containing information about all connected displays.
///
/// Access via `world.getResource<DisplayInfo>()` or `world.displayInfo`.
///
/// ```dart
/// final displayInfo = world.displayInfo;
/// if (displayInfo != null) {
///   print('Primary: ${displayInfo.primary.name}');
///   print('Resolution: ${displayInfo.primary.size}');
///   print('Displays: ${displayInfo.displays.length}');
/// }
/// ```
class DisplayInfo {
  List<Display> _displays;
  int _primaryIndex;

  /// Creates empty display info (populated during startup).
  ///
  /// This is used internally by the WindowPlugin.
  DisplayInfo.empty()
      : _displays = [],
        _primaryIndex = 0;

  /// All connected displays.
  List<Display> get displays => List.unmodifiable(_displays);

  /// Index of the primary display.
  int get primaryIndex => _primaryIndex;

  /// The primary display.
  ///
  /// Throws if no displays are available (shouldn't happen in practice).
  Display get primary => _displays[_primaryIndex];

  /// Whether display info has been populated.
  bool get isInitialized => _displays.isNotEmpty;

  /// Gets a display by index, or null if not found.
  Display? getDisplay(int index) {
    if (index >= 0 && index < _displays.length) {
      return _displays[index];
    }
    return null;
  }

  /// Updates display information.
  ///
  /// Called by the display sync system.
  void updateDisplays(List<Display> displays, int primaryIndex) {
    _displays = displays;
    _primaryIndex = primaryIndex;
  }

  @override
  String toString() {
    return 'DisplayInfo(${_displays.length} displays, primary: $_primaryIndex)';
  }
}
