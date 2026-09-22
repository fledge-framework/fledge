/// Callback type for handling Yarn commands.
///
/// Commands are executed when the dialogue runner encounters a `<<command>>`
/// line. The handler receives the command name and arguments.
///
/// Return `true` if the command was handled, `false` otherwise.
typedef CommandCallback = bool Function(String command, List<String> arguments);

/// Callback type for a **pausing** Yarn command handler.
///
/// Runs synchronously when `DialogueRunner._processNext` reaches a
/// `<<command>>` line whose name was registered via
/// [CommandHandler.registerPausing]. After the callback returns, the
/// runner enters [DialogueState.paused] and stops processing until
/// `DialogueRunner.resume()` is called — statements between this
/// command and the next line / choice have NOT run yet, so any
/// asynchronous game-side work triggered by the command (start a
/// hold, wait for a modal to close) can finish before the dialogue
/// moves on.
typedef PausingCommandCallback = void Function(
  String command,
  List<String> arguments,
);

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
  final Map<String, PausingCommandCallback> _pausingHandlers = {};

  /// Register a handler for a command.
  ///
  /// The [name] should not include the `<<` and `>>` delimiters.
  void register(String name, CommandCallback handler) {
    _handlers[name.toLowerCase()] = handler;
  }

  /// Register a **pausing** handler for a command.
  ///
  /// See [PausingCommandCallback]. When `DialogueRunner` executes a
  /// `<<command>>` whose name has a pausing handler, the handler runs
  /// synchronously and the runner then pauses until
  /// `DialogueRunner.resume()` is called. Any regular handler
  /// registered under the same name is bypassed while a pausing
  /// handler is in place.
  void registerPausing(String name, PausingCommandCallback handler) {
    _pausingHandlers[name.toLowerCase()] = handler;
  }

  /// Remove a command handler.
  void unregister(String name) {
    _handlers.remove(name.toLowerCase());
    _pausingHandlers.remove(name.toLowerCase());
  }

  /// Check if a handler exists for a command (regular or pausing).
  bool hasHandler(String name) {
    final lower = name.toLowerCase();
    return _handlers.containsKey(lower) ||
        _pausingHandlers.containsKey(lower);
  }

  /// True when [name] is bound to a pausing handler. Consulted by
  /// `DialogueRunner` to decide whether to pause after execution.
  bool hasPausingHandler(String name) {
    return _pausingHandlers.containsKey(name.toLowerCase());
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

  /// Execute a pausing command with the given arguments. No-op if
  /// no pausing handler is registered under [command].
  void executePausing(String command, List<String> arguments) {
    final handler = _pausingHandlers[command.toLowerCase()];
    if (handler != null) {
      handler(command, arguments);
    }
  }

  /// Clear all registered handlers (regular AND pausing).
  void clear() {
    _handlers.clear();
    _pausingHandlers.clear();
  }
}
