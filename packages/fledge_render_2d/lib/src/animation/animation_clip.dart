/// A single frame in an animation.
class AnimationFrame {
  /// The sprite index in the atlas.
  final int index;

  /// Duration of this frame in seconds.
  final double duration;

  /// Creates an animation frame.
  const AnimationFrame({
    required this.index,
    required this.duration,
  });

  @override
  String toString() => 'AnimationFrame(index: $index, duration: $duration)';
}

/// A sequence of animation frames.
///
/// An animation clip defines a series of frames that can be played
/// by an [AnimationPlayer].
///
/// Example:
/// ```dart
/// // Create a walk animation from sprite indices 0-3
/// final walkClip = AnimationClip.fromIndices(
///   name: 'walk',
///   startIndex: 0,
///   endIndex: 3,
///   frameDuration: 0.1,
///   looping: true,
/// );
/// ```
class AnimationClip {
  /// Name of the animation.
  final String name;

  /// The animation frames.
  final List<AnimationFrame> frames;

  /// Whether the animation loops.
  final bool looping;

  /// Total duration of the animation in seconds.
  late final double duration;

  /// Creates an animation clip.
  AnimationClip({
    required this.name,
    required this.frames,
    this.looping = true,
  }) {
    duration = frames.fold(0.0, (sum, frame) => sum + frame.duration);
  }

  /// Creates an animation clip from a range of sprite indices.
  ///
  /// All frames have the same duration.
  factory AnimationClip.fromIndices({
    required String name,
    required int startIndex,
    required int endIndex,
    required double frameDuration,
    bool looping = true,
  }) {
    final frames = <AnimationFrame>[];
    for (var i = startIndex; i <= endIndex; i++) {
      frames.add(AnimationFrame(index: i, duration: frameDuration));
    }
    return AnimationClip(
      name: name,
      frames: frames,
      looping: looping,
    );
  }

  /// Creates an animation clip from a list of indices.
  ///
  /// All frames have the same duration.
  factory AnimationClip.fromIndexList({
    required String name,
    required List<int> indices,
    required double frameDuration,
    bool looping = true,
  }) {
    return AnimationClip(
      name: name,
      frames: indices
          .map((i) => AnimationFrame(index: i, duration: frameDuration))
          .toList(),
      looping: looping,
    );
  }

  /// Creates an animation clip with variable frame durations.
  factory AnimationClip.withDurations({
    required String name,
    required List<int> indices,
    required List<double> durations,
    bool looping = true,
  }) {
    if (indices.length != durations.length) {
      throw ArgumentError('indices and durations must have the same length');
    }
    final frames = <AnimationFrame>[];
    for (var i = 0; i < indices.length; i++) {
      frames.add(AnimationFrame(index: indices[i], duration: durations[i]));
    }
    return AnimationClip(
      name: name,
      frames: frames,
      looping: looping,
    );
  }

  /// Number of frames in the animation.
  int get frameCount => frames.length;

  /// Whether this is a single-frame (static) animation.
  bool get isStatic => frames.length == 1;

  /// Get the frame index at a given time.
  ///
  /// If looping, time wraps around. Otherwise, clamps to the last frame.
  int getFrameAtTime(double time) {
    if (frames.isEmpty) return 0;
    if (duration <= 0) return frames.first.index;

    // Handle looping
    double effectiveTime = time;
    if (looping && duration > 0) {
      effectiveTime = time % duration;
      if (effectiveTime < 0) effectiveTime += duration;
    } else {
      effectiveTime = time.clamp(0, duration);
    }

    // Find the frame
    double accumulated = 0;
    for (final frame in frames) {
      accumulated += frame.duration;
      if (effectiveTime < accumulated) {
        return frame.index;
      }
    }
    return frames.last.index;
  }

  /// Get the frame at a given frame index (not time-based).
  AnimationFrame operator [](int index) => frames[index];

  @override
  String toString() =>
      'AnimationClip($name, frames: ${frames.length}, looping: $looping)';
}
