/// Component marking an entity as the audio listener.
///
/// There should typically be only one active listener.
/// Attach to the player or camera entity along with Transform2D. Its
/// position is world-space: the entity's `GlobalTransform2D` when it has
/// one, else its `Transform2D`.
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

  /// Not used: there's no Doppler effect, so setting it changes nothing.
  @Deprecated(
    'Never read: fledge_audio has no Doppler effect. Remove it; it will '
    'be deleted in a future release.',
  )
  double velocityX;

  /// Not used: there's no Doppler effect, so setting it changes nothing.
  @Deprecated(
    'Never read: fledge_audio has no Doppler effect. Remove it; it will '
    'be deleted in a future release.',
  )
  double velocityY;

  AudioListener({
    this.isActive = true,
    @Deprecated(
      'Never read: fledge_audio has no Doppler effect. Remove it; it will '
      'be deleted in a future release.',
    )
    this.velocityX = 0.0,
    @Deprecated(
      'Never read: fledge_audio has no Doppler effect. Remove it; it will '
      'be deleted in a future release.',
    )
    this.velocityY = 0.0,
  });
}
