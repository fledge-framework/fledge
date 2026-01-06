/// Phases of a scene transition.
enum TransitionPhase {
  /// No transition in progress.
  idle,

  /// Screen is fading out (to black).
  fadeOut,

  /// Screen is black, loading new scene.
  loading,

  /// Screen is fading back in (from black).
  fadeIn,
}

/// Resource tracking scene transition state.
///
/// Manages fade animations between scenes. The transition flow is:
/// ```
/// idle → fadeOut → loading → fadeIn → idle
/// ```
///
/// ## Usage
///
/// ```dart
/// // Request a transition
/// transitionState.requestTransition(
///   'level2',
///   metadata: {'spawnX': 100, 'spawnY': 200},
/// );
///
/// // In your game loop, check for loading phase
/// if (transitionState.phase == TransitionPhase.loading && !transitionState.isLoadingAsync) {
///   transitionState.isLoadingAsync = true;
///   await loadNewScene();
///   transitionState.beginFadeIn();
///   transitionState.isLoadingAsync = false;
/// }
///
/// // Render fade overlay
/// canvas.drawRect(
///   screenRect,
///   Paint()..color = Color.fromRGBO(0, 0, 0, transitionState.fadeProgress),
/// );
/// ```
class TransitionState {
  /// Current phase of the transition.
  TransitionPhase phase = TransitionPhase.idle;

  /// Target scene identifier.
  ///
  /// Can be any type - string name, enum, object reference, etc.
  Object? targetScene;

  /// Optional metadata for the transition.
  ///
  /// Game-specific data like spawn position, facing direction, etc.
  Map<String, dynamic>? metadata;

  /// Progress of current fade (0.0 to 1.0).
  ///
  /// 0.0 = fully visible, 1.0 = fully black.
  double fadeProgress = 0.0;

  /// Duration of fade in/out in seconds.
  double fadeDuration;

  /// Guard flag to prevent re-entry during async scene loading.
  ///
  /// Set this to true before starting async operations in the loading phase,
  /// and reset to false when complete.
  bool isLoadingAsync = false;

  /// Creates a transition state.
  ///
  /// [fadeDuration] - How long fade in/out takes in seconds (default: 0.3)
  TransitionState({
    this.fadeDuration = 0.3,
  });

  /// Whether a transition is currently in progress.
  bool get isTransitioning => phase != TransitionPhase.idle;

  /// Request a transition to a new scene.
  ///
  /// Does nothing if a transition is already in progress.
  ///
  /// [scene] - Target scene identifier (any type)
  /// [metadata] - Optional game-specific data
  void requestTransition(Object scene, {Map<String, dynamic>? metadata}) {
    if (isTransitioning) return;

    targetScene = scene;
    this.metadata = metadata;
    phase = TransitionPhase.fadeOut;
    fadeProgress = 0.0;
  }

  /// Called when fade out completes. Transitions to loading phase.
  void beginLoading() {
    phase = TransitionPhase.loading;
  }

  /// Called when loading completes. Transitions to fade in phase.
  void beginFadeIn() {
    phase = TransitionPhase.fadeIn;
    fadeProgress = 1.0;
  }

  /// Called when fade in completes. Resets to idle.
  void complete() {
    phase = TransitionPhase.idle;
    targetScene = null;
    metadata = null;
    fadeProgress = 0.0;
    isLoadingAsync = false;
  }

  /// Cancel a transition in progress.
  ///
  /// Use with caution - only safe during fadeOut phase.
  void cancel() {
    if (phase == TransitionPhase.fadeOut) {
      complete();
    }
  }
}
