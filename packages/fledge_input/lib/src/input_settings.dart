/// Plugin-level input settings, inserted as a resource by `InputPlugin`.
///
/// `InputWidget` reads it when it mounts.
class InputSettings {
  /// Whether `InputWidget` polls gamepads. The widget's own
  /// `InputWidget.enableGamepad` must be true as well.
  final bool enableGamepad;

  const InputSettings({this.enableGamepad = true});
}
