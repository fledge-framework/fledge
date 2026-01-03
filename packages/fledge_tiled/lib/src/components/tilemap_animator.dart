/// Component tracking animated tiles for a tilemap.
///
/// Attached to the Tilemap entity when the map contains animated tiles.
/// Updated each frame by the TileAnimationSystem.
///
/// Example:
/// ```dart
/// // Check if a tilemap has animations
/// final animator = world.get<TilemapAnimator>(mapEntity);
/// if (animator != null) {
///   print('Map has ${animator.animations.length} animated tiles');
/// }
///
/// // Get current frame for an animated tile during extraction
/// final currentFrame = animator?.getCurrentFrame(tile.localId) ?? tile.localId;
/// ```
class TilemapAnimator {
  /// Map of tile local ID to animation data.
  ///
  /// Only tiles with animations are included in this map.
  final Map<int, TileAnimation> animations;

  /// Current global animation time accumulator in seconds.
  double time = 0;

  TilemapAnimator({required this.animations});

  /// Updates all animations with delta time.
  ///
  /// Called by TileAnimationSystem each frame.
  void update(double dt) {
    time += dt;
  }

  /// Gets the current frame index for an animated tile.
  ///
  /// Returns the original [localId] if the tile is not animated.
  int getCurrentFrame(int localId) {
    final anim = animations[localId];
    if (anim == null) return localId;
    return anim.getFrameAtTime(time);
  }

  /// Returns true if a tile has an animation.
  bool hasAnimation(int localId) => animations.containsKey(localId);

  /// Resets all animation timers.
  void reset() {
    time = 0;
  }
}

/// Animation data for a single animated tile.
///
/// Stores the sequence of frames and their durations.
class TileAnimation {
  /// Frames with their tile IDs and durations.
  final List<TileAnimationFrame> frames;

  /// Total duration of one animation cycle in seconds.
  final double totalDuration;

  /// Cached frame boundaries for faster lookup.
  late final List<double> _frameBoundaries;

  TileAnimation({required this.frames})
      : totalDuration = frames.fold(0.0, (sum, f) => sum + f.duration) {
    // Pre-compute frame boundaries for binary search
    _frameBoundaries = [];
    double accumulated = 0;
    for (final frame in frames) {
      accumulated += frame.duration;
      _frameBoundaries.add(accumulated);
    }
  }

  /// Creates a TileAnimation from Tiled's animation data.
  ///
  /// Tiled stores durations in milliseconds, so we convert to seconds.
  factory TileAnimation.fromTiled(List<TiledAnimationFrame> tiledFrames) {
    return TileAnimation(
      frames: tiledFrames
          .map((f) => TileAnimationFrame(
                tileId: f.tileId,
                duration: f.durationMs / 1000.0,
              ))
          .toList(),
    );
  }

  /// Gets the tile ID for the frame at the given time.
  int getFrameAtTime(double globalTime) {
    if (frames.isEmpty) return 0;
    if (frames.length == 1) return frames[0].tileId;

    // Wrap time to animation duration (looping)
    final cycleTime = globalTime % totalDuration;

    // Binary search for the current frame
    int low = 0;
    int high = _frameBoundaries.length - 1;

    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_frameBoundaries[mid] <= cycleTime) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    return frames[low].tileId;
  }

  /// Gets the current frame index (0-based).
  int getFrameIndexAtTime(double globalTime) {
    if (frames.isEmpty) return 0;
    if (frames.length == 1) return 0;

    final cycleTime = globalTime % totalDuration;

    int low = 0;
    int high = _frameBoundaries.length - 1;

    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_frameBoundaries[mid] <= cycleTime) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    return low;
  }

  /// Number of frames in the animation.
  int get frameCount => frames.length;

  /// Whether this is a single-frame animation.
  bool get isSingleFrame => frames.length <= 1;
}

/// A single frame in a tile animation.
class TileAnimationFrame {
  /// The tile ID to display for this frame.
  final int tileId;

  /// Duration of this frame in seconds.
  final double duration;

  const TileAnimationFrame({
    required this.tileId,
    required this.duration,
  });
}

/// Intermediate representation of Tiled animation frame data.
///
/// Used during map loading before converting to TileAnimationFrame.
class TiledAnimationFrame {
  /// The tile ID to display.
  final int tileId;

  /// Duration in milliseconds (Tiled's native format).
  final int durationMs;

  const TiledAnimationFrame({
    required this.tileId,
    required this.durationMs,
  });
}
