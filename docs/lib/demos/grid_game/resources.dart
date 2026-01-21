/// Grid configuration resource.
///
/// Defines the size and scale of the game grid.
class GridConfig {
  /// Number of tiles horizontally.
  final int width;

  /// Number of tiles vertically.
  final int height;

  /// Size of each tile in pixels.
  final double tileSize;

  /// Gap between tiles in pixels.
  final double gap;

  const GridConfig({
    this.width = 10,
    this.height = 10,
    this.tileSize = 28,
    this.gap = 2,
  });

  /// Total pixel width of the grid.
  double get totalWidth => width * (tileSize + gap) - gap;

  /// Total pixel height of the grid.
  double get totalHeight => height * (tileSize + gap) - gap;
}

/// Game score resource.
class GameScore {
  int value = 0;

  void add(int points) => value += points;

  void reset() => value = 0;
}

/// Movement timer resource - manages timing for smooth continuous movement.
///
/// Used alongside ActionState to control movement repeat rate when
/// direction keys are held.
class MoveTimer {
  /// Time since last movement.
  double _elapsed = 0;

  /// Interval between movements while held.
  final double repeatInterval = 0.1;

  /// Whether any direction is currently being held.
  bool _wasHeld = false;

  /// Updates timer and returns true if movement should occur.
  ///
  /// Pass [isHeld] = true if any direction key is currently held.
  bool tick(double delta, {required bool isHeld}) {
    if (!isHeld) {
      _elapsed = 0;
      _wasHeld = false;
      return false;
    }

    // Immediate movement on first press
    if (!_wasHeld) {
      _wasHeld = true;
      _elapsed = 0;
      return true;
    }

    _elapsed += delta;

    if (_elapsed >= repeatInterval) {
      _elapsed -= repeatInterval;
      return true;
    }
    return false;
  }

  void reset() {
    _elapsed = 0;
    _wasHeld = false;
  }
}

/// Spawn timer resource - controls collectible spawning rate.
class SpawnTimer {
  double elapsed = 0;
  final double interval;

  SpawnTimer([this.interval = 2.0]);

  /// Returns true if it's time to spawn and resets the timer.
  bool tick(double delta) {
    elapsed += delta;
    if (elapsed >= interval) {
      elapsed -= interval;
      return true;
    }
    return false;
  }

  void reset() => elapsed = 0;
}
