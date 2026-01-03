/// Component marking an entity as the audio listener.
///
/// There should typically be only one active listener.
/// Attach to the player or camera entity along with Transform2D.
///
/// ```dart
/// // Attach to player
/// world.spawn()
///   ..insert(Transform2D.from(0, 0))
///   ..insert(AudioListener());
///
/// // Or attach to camera
/// world.spawn()
///   ..insert(Transform2D.from(0, 0))
///   ..insert(Camera2D())
///   ..insert(AudioListener());
/// ```
class AudioListener {
  /// Whether this listener is active.
  bool isActive;

  /// Optional velocity for Doppler effect (future enhancement).
  double velocityX;
  double velocityY;

  AudioListener({
    this.isActive = true,
    this.velocityX = 0.0,
    this.velocityY = 0.0,
  });
}
