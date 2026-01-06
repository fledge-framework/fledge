/// Callback type for handling Yarn commands.
///
/// Commands are executed when the dialogue runner encounters a `<<command>>`
/// line. The handler receives the command name and arguments.
///
/// Return `true` if the command was handled, `false` otherwise.
typedef CommandCallback = bool Function(String command, List<String> arguments);

/// Registry for custom Yarn command handlers.
///
/// Games can register handlers for custom commands like `<<give_item sword>>`
/// or `<<play_sound bell>>`.
///
/// Example:
/// ```dart
/// final commands = CommandHandler();
///
/// commands.register('give_item', (args) {
///   if (args.isNotEmpty) {
///     inventory.addItem(args[0]);
///   }
///   return true;
/// });
///
/// commands.register('play_sound', (args) {
///   if (args.isNotEmpty) {
///     audioPlayer.play(args[0]);
///   }
///   return true;
/// });
/// ```
class CommandHandler {
  final Map<String, CommandCallback> _handlers = {};

  /// Register a handler for a command.
  ///
  /// The [name] should not include the `<<` and `>>` delimiters.
  void register(String name, CommandCallback handler) {
    _handlers[name.toLowerCase()] = handler;
  }

  /// Remove a command handler.
  void unregister(String name) {
    _handlers.remove(name.toLowerCase());
  }

  /// Check if a handler exists for a command.
  bool hasHandler(String name) {
    return _handlers.containsKey(name.toLowerCase());
  }

  /// Execute a command with the given arguments.
  ///
  /// Returns `true` if the command was handled, `false` if no handler exists.
  bool execute(String command, List<String> arguments) {
    final handler = _handlers[command.toLowerCase()];
    if (handler != null) {
      return handler(command, arguments);
    }
    return false;
  }

  /// Clear all registered handlers.
  void clear() {
    _handlers.clear();
  }
}
