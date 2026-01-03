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

/// Input state resource - tracks held direction keys for continuous movement.
///
/// Tracks which direction keys are currently held and manages
/// movement timing for smooth continuous movement.
class InputState {
  /// Currently held directions (can hold multiple keys).
  bool leftHeld = false;
  bool rightHeld = false;
  bool upHeld = false;
  bool downHeld = false;

  /// Time since last movement.
  double _moveTimer = 0;

  /// Delay before first repeat (slightly longer for responsiveness).
  final double initialDelay = 0.15;

  /// Interval between movements while held.
  final double repeatInterval = 0.1;

  /// Whether initial move has happened.
  bool _initialMoveDone = false;

  /// Computed movement direction from held keys.
  int get dx {
    if (leftHeld && !rightHeld) return -1;
    if (rightHeld && !leftHeld) return 1;
    return 0;
  }

  int get dy {
    if (upHeld && !downHeld) return -1;
    if (downHeld && !upHeld) return 1;
    return 0;
  }

  bool get hasHeldDirection => leftHeld || rightHeld || upHeld || downHeld;

  /// Updates timer and returns true if movement should occur.
  bool tick(double delta) {
    if (!hasHeldDirection) {
      _moveTimer = 0;
      _initialMoveDone = false;
      return false;
    }

    // Immediate movement on first press
    if (!_initialMoveDone) {
      _initialMoveDone = true;
      _moveTimer = 0;
      return true;
    }

    _moveTimer += delta;
    final threshold = _initialMoveDone ? repeatInterval : initialDelay;

    if (_moveTimer >= threshold) {
      _moveTimer -= threshold;
      return true;
    }
    return false;
  }

  void clear() {
    leftHeld = false;
    rightHeld = false;
    upHeld = false;
    downHeld = false;
    _moveTimer = 0;
    _initialMoveDone = false;
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

