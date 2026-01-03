import 'animation_clip.dart';

/// State of an animation player.
enum AnimationState {
  /// Animation is playing.
  playing,

  /// Animation is paused.
  paused,

  /// Animation has stopped (reached end for non-looping).
  stopped,
}

/// Plays animation clips on entities.
///
/// An [AnimationPlayer] manages a set of animation clips and
/// plays them in response to game events.
///
/// Example:
/// ```dart
/// final player = AnimationPlayer(
///   animations: {
///     'idle': AnimationClip.fromIndices(
///       name: 'idle',
///       startIndex: 0,
///       endIndex: 3,
///       frameDuration: 0.2,
///     ),
///     'walk': AnimationClip.fromIndices(
///       name: 'walk',
///       startIndex: 4,
///       endIndex: 7,
///       frameDuration: 0.1,
///     ),
///   },
/// );
///
/// player.play('walk');
/// ```
class AnimationPlayer {
  /// Available animations by name.
  final Map<String, AnimationClip> animations;

  /// Current animation clip.
  AnimationClip? _currentClip;

  /// Current playback time in seconds.
  double _time = 0;

  /// Current playback speed multiplier.
  double speed = 1.0;

  /// Current state.
  AnimationState _state = AnimationState.stopped;

  /// Whether to auto-play the first animation on creation.
  final bool autoPlay;

  /// Creates an animation player.
  AnimationPlayer({
    required this.animations,
    String? initialAnimation,
    this.autoPlay = false,
    this.speed = 1.0,
  }) {
    if (initialAnimation != null) {
      play(initialAnimation);
    } else if (autoPlay && animations.isNotEmpty) {
      play(animations.keys.first);
    }
  }

  /// Current animation name, or null if none.
  String? get currentAnimation => _currentClip?.name;

  /// Current animation clip, or null if none.
  AnimationClip? get currentClip => _currentClip;

  /// Current playback time.
  double get time => _time;

  /// Current playback state.
  AnimationState get state => _state;

  /// Whether the animation is playing.
  bool get isPlaying => _state == AnimationState.playing;

  /// Whether the animation is paused.
  bool get isPaused => _state == AnimationState.paused;

  /// Whether the animation is stopped.
  bool get isStopped => _state == AnimationState.stopped;

  /// Current sprite index in the animation.
  int get currentIndex {
    if (_currentClip == null) return 0;
    return _currentClip!.getFrameAtTime(_time);
  }

  /// Current frame (0-based index within the animation).
  int get currentFrame {
    if (_currentClip == null || _currentClip!.frames.isEmpty) return 0;

    double accumulated = 0;
    for (var i = 0; i < _currentClip!.frames.length; i++) {
      accumulated += _currentClip!.frames[i].duration;
      if (_time < accumulated) {
        return i;
      }
    }
    return _currentClip!.frames.length - 1;
  }

  /// Play an animation by name.
  ///
  /// If [restart] is true, restarts even if already playing this animation.
  void play(String name, {bool restart = false}) {
    final clip = animations[name];
    if (clip == null) {
      throw ArgumentError('Animation not found: $name');
    }

    if (_currentClip == clip && !restart && _state == AnimationState.playing) {
      return; // Already playing
    }

    _currentClip = clip;
    _time = 0;
    _state = AnimationState.playing;
  }

  /// Pause the current animation.
  void pause() {
    if (_state == AnimationState.playing) {
      _state = AnimationState.paused;
    }
  }

  /// Resume a paused animation.
  void resume() {
    if (_state == AnimationState.paused) {
      _state = AnimationState.playing;
    }
  }

  /// Stop the animation and reset to the beginning.
  void stop() {
    _state = AnimationState.stopped;
    _time = 0;
  }

  /// Toggle between playing and paused.
  void toggle() {
    if (_state == AnimationState.playing) {
      pause();
    } else if (_state == AnimationState.paused) {
      resume();
    }
  }

  /// Update the animation by the given delta time.
  ///
  /// Returns true if the animation just finished (for non-looping clips).
  bool update(double dt) {
    if (_currentClip == null || _state != AnimationState.playing) {
      return false;
    }

    _time += dt * speed;

    // Check for animation end
    if (!_currentClip!.looping && _time >= _currentClip!.duration) {
      _time = _currentClip!.duration;
      _state = AnimationState.stopped;
      return true;
    }

    return false;
  }

  /// Set the playback position as a normalized value (0-1).
  void setProgress(double progress) {
    if (_currentClip == null) return;
    _time = progress.clamp(0, 1) * _currentClip!.duration;
  }

  /// Get the playback progress as a normalized value (0-1).
  double get progress {
    if (_currentClip == null || _currentClip!.duration <= 0) return 0;
    final p = _time / _currentClip!.duration;
    return _currentClip!.looping ? p % 1.0 : p.clamp(0, 1);
  }

  /// Whether the specified animation exists.
  bool hasAnimation(String name) => animations.containsKey(name);

  /// Add an animation to the player.
  void addAnimation(AnimationClip clip) {
    animations[clip.name] = clip;
  }

  /// Remove an animation from the player.
  void removeAnimation(String name) {
    animations.remove(name);
    if (_currentClip?.name == name) {
      _currentClip = null;
      _state = AnimationState.stopped;
    }
  }

  @override
  String toString() =>
      'AnimationPlayer(current: ${_currentClip?.name}, state: $_state)';
}
