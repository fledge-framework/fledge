import 'package:fledge_ecs/fledge_ecs.dart';

import '../command_handler.dart';
import '../variable_storage.dart';
import 'declare_command.dart';
import 'dialogue_events.dart';
import 'dialogue_state.dart';

/// The generic dialogue layer on top of fledge_yarn's `DialogueRunner`:
///
/// - the [DialogueState] resource (typewriter at [charactersPerSecond]);
/// - the request events ([DialogueStartRequested],
///   [DialogueAdvanceRequested], [DialogueChoiceSelected],
///   [DialogueCursorMoved], [DialogueSkipRequested],
///   [DialogueStopRequested], [DialogueHoldReleased]) and notifications
///   ([DialogueStarted], [DialogueLineShown], [DialogueChoicesReady],
///   [DialogueChoiceMade], [DialogueEnded]);
/// - [DialogueStartSystem] → [DialogueAdvanceSystem] in [schedule];
/// - the built-in `<<declare>>` command ([declareCommand]);
/// - holding commands, which the dialogue waits on until released
///   ([registerHoldingCommand], [DialogueHoldReleased]).
///
/// Requires `YarnPlugin` (added first: it provides the `YarnProject`,
/// `VariableStorage` and `CommandHandler`). Game command handlers are
/// registered on that `CommandHandler` as usual; declare what they touch
/// in [commandAccess] so the scheduler can order the dialogue systems
/// against the systems consuming their effects.
class DialogueCorePlugin implements Plugin {
  final double charactersPerSecond;
  final DialogueCommandAccess commandAccess;
  final DialogueTimeSource timeSource;
  final Schedule schedule;

  DialogueCorePlugin({
    this.charactersPerSecond = 40,
    this.commandAccess = const DialogueCommandAccess(),
    this.timeSource = DialogueTimeSource.wallTime,
    this.schedule = Schedules.update,
  });

  App? _app;

  @override
  void build(App app) {
    final commands = app.world.getResource<CommandHandler>();
    if (commands == null) {
      throw StateError('DialogueCorePlugin needs YarnPlugin: add it first.');
    }
    _app = app;
    final world = app.world;
    commands.register(declareCommandName, (command, arguments) {
      final storage = world.getResource<VariableStorage>();
      return storage == null ? false : declareCommand(storage, arguments);
    });

    app
      ..insertResource(DialogueState(charactersPerSecond: charactersPerSecond))
      ..addEvent<DialogueStartRequested>()
      ..addEvent<DialogueAdvanceRequested>()
      ..addEvent<DialogueChoiceSelected>()
      ..addEvent<DialogueCursorMoved>()
      ..addEvent<DialogueSkipRequested>()
      ..addEvent<DialogueStopRequested>()
      ..addEvent<DialogueHoldReleased>()
      ..addEvent<DialogueStarted>()
      ..addEvent<DialogueLineShown>()
      ..addEvent<DialogueChoicesReady>()
      ..addEvent<DialogueChoiceMade>()
      ..addEvent<DialogueEnded>()
      ..addSystem(
        DialogueStartSystem(commandAccess: commandAccess),
        schedule: schedule,
      )
      ..addSystem(
        DialogueAdvanceSystem(
          commandAccess: commandAccess,
          timeSource: timeSource,
        ),
        schedule: schedule,
      );
  }

  @override
  void cleanup() {
    _app?.world.getResource<CommandHandler>()?.unregister(declareCommandName);
    _app?.world.removeResource<DialogueState>();
    _app = null;
  }
}
