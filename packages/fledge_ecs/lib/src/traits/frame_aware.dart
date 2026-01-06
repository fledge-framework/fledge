/// Interface for resources that need per-frame lifecycle callbacks.
///
/// Resources implementing this interface can reset frame-specific
/// state at the beginning of each frame.
///
/// ## Usage
///
/// ```dart
/// class InputState implements FrameAware {
///   bool _jumpPressed = false;
///   bool _jumpPressedThisFrame = false;
///
///   @override
///   void beginFrame() {
///     _jumpPressedThisFrame = false;
///   }
///
///   void onJumpPressed() {
///     _jumpPressed = true;
///     _jumpPressedThisFrame = true;
///   }
///
///   bool get jumpPressedThisFrame => _jumpPressedThisFrame;
/// }
/// ```
///
/// Note: The framework does not automatically call [beginFrame].
/// Games should call it manually at the start of their game loop,
/// or create a system that does so.
abstract class FrameAware {
  /// Called at the beginning of each frame.
  ///
  /// Use this to reset per-frame tracking flags.
  void beginFrame();
}
