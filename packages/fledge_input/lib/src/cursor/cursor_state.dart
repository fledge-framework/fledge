import 'cursor_mode.dart';

/// Tracks cursor state for the input system.
///
/// The cursor mode can be set by:
/// 1. The active [InputContext]'s cursorMode (automatic)
/// 2. Manual override via [requestMode] (temporary)
///
/// Use [requestMode] for temporary changes like pause menus that
/// need to show the cursor regardless of the current context.
class CursorState {
  /// Current effective cursor mode.
  CursorMode _effectiveMode = CursorMode.visible;

  /// Mode from the active input context.
  CursorMode _contextMode = CursorMode.visible;

  /// Manual override mode (null = use context mode).
  CursorMode? _overrideMode;

  /// Callback when cursor mode changes.
  void Function(CursorMode mode)? onModeChanged;

  /// Get the current effective cursor mode.
  CursorMode get mode => _effectiveMode;

  /// Whether cursor is currently visible.
  bool get isVisible => _effectiveMode == CursorMode.visible;

  /// Whether cursor is currently locked (captured for relative movement).
  bool get isLocked => _effectiveMode == CursorMode.locked;

  /// Whether cursor is hidden (but not necessarily locked).
  bool get isHidden => _effectiveMode != CursorMode.visible;

  /// Update the mode from the current input context.
  ///
  /// Called automatically when the active context changes.
  void updateFromContext(CursorMode contextMode) {
    _contextMode = contextMode;
    _updateEffectiveMode();
  }

  /// Temporarily override the cursor mode.
  ///
  /// Use this for pause menus or other UI that needs the cursor
  /// visible regardless of the current input context.
  ///
  /// Call [clearOverride] to return to context-based mode.
  void requestMode(CursorMode mode) {
    _overrideMode = mode;
    _updateEffectiveMode();
  }

  /// Clear any manual override and return to context-based mode.
  void clearOverride() {
    _overrideMode = null;
    _updateEffectiveMode();
  }

  /// Check if there's a manual override active.
  bool get hasOverride => _overrideMode != null;

  void _updateEffectiveMode() {
    final newMode = _overrideMode ?? _contextMode;
    if (newMode != _effectiveMode) {
      _effectiveMode = newMode;
      onModeChanged?.call(_effectiveMode);
    }
  }
}
