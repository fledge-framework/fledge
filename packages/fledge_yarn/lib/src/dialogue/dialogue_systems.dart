part of 'dialogue_state.dart';

// =============================================================================
// Core dialogue systems + run conditions
// =============================================================================

/// Whether a dialogue is active. For `SystemMeta`-level gating
/// (`runCondition`) and plain checks (`dialogueActive(world)`).
final RunCondition dialogueActive = RunConditions.resource<DialogueState>(
  (state) => state.isActive,
);

/// The inverse of [dialogueActive] (true without a [DialogueState]): for
/// gameplay systems that pause while a dialogue is up.
final RunCondition unlessDialogueActive = RunConditions.not(dialogueActive);

/// What the Yarn command handlers registered on fledge_yarn's
/// `CommandHandler` touch. They run inside the core systems (starting or
/// advancing the runner executes the commands it passes), so the core
/// systems declare these in their `SystemMeta` and the scheduler orders
/// them against the domain systems that consume the effects.
///
/// Command handlers should only send request events ([eventWrites]); a
/// handler that writes a resource directly lists it in [resourceWrites].
class DialogueCommandAccess {
  final Set<Type> resourceWrites;
  final Set<Type> eventWrites;

  const DialogueCommandAccess({
    this.resourceWrites = const {},
    this.eventWrites = const {},
  });
}

/// Where the typewriter's per-tick delta (seconds) comes from, and the
/// resource the system reads for it (declared in its `SystemMeta`).
class DialogueTimeSource {
  final Type resource;
  final double Function(World world) delta;

  const DialogueTimeSource({required this.resource, required this.delta});

  /// Real time: fledge_ecs's [WallTime] (default). The typewriter is
  /// presentation, so it runs on the wall clock, not the game calendar.
  static const DialogueTimeSource wallTime = DialogueTimeSource(
    resource: WallTime,
    delta: _wallTimeDelta,
  );
}

double _wallTimeDelta(World world) => world.getResource<WallTime>()?.delta ?? 0;

/// Registers Yarn command [name] on [handler] as a **holding command**: a
/// command the dialogue waits on (a minigame, a cutscene, a timed beat).
///
/// When the runner reaches `<<name args…>>` during an active dialogue,
/// [onCommand] runs with the arguments (it typically sends a request event
/// that starts the thing being waited on — declare that event in
/// [DialogueCommandAccess]). If it returns a token, the dialogue is
/// **held**: `DialogueState.isHeld`, nothing shown, and every request but
/// [DialogueStopRequested] ignored, until a [DialogueHoldReleased] with
/// that token arrives (from any sender — typically the system that ran the
/// awaited thing). Then the dialogue shows what comes after the command:
/// the next line, choice, or the end ([DialogueEnded]). Returning null
/// doesn't hold (e.g. malformed arguments: log and carry on).
///
/// Holds are **exact**: they use fledge_yarn's pausing command callback
/// ([CommandHandler.registerPausing]), so commands between the holding
/// command and the next line or choice do NOT run until the hold is
/// released. This is the design's Phase F upgrade: `registerHoldingCommand`
/// used to run those commands eagerly and only defer presentation, which
/// let a command mutate world state before the awaited beat finished.
///
/// Several holds can be in place at once (the game can add extra holds
/// externally, e.g. from another system); the dialogue resumes when all
/// are released. A stop drops them. [world] is the one whose
/// `DialogueState` is held.
void registerHoldingCommand(
  CommandHandler handler,
  World world,
  String name,
  Object? Function(List<String> arguments) onCommand,
) {
  handler.registerPausing(name, (command, arguments) {
    final state = world.getResource<DialogueState>();
    if (state == null || !state.isActive) {
      _log('<<$name>> outside a dialogue: ignored', level: 900);
      return false;
    }
    final token = onCommand(arguments);
    if (token == null) return false;
    state._hold(token);
    return true;
  });
}

/// Names of the core systems, for `before:` / `after:` lists of systems that
/// conflict with both (e.g. read [DialogueState], or consume the events the
/// command handlers send).
const List<String> dialogueCoreSystemNames = [
  DialogueStartSystem.systemName,
  DialogueAdvanceSystem.systemName,
];

/// Starts dialogues: on [DialogueStartRequested], unless a dialogue is
/// already active (the request is refused and logged), creates the runner
/// and runs the node up to its first line or choice — executing the leading
/// commands — then sends [DialogueStarted] and [DialogueLineShown] /
/// [DialogueChoicesReady] (or [DialogueEnded] if the node had nothing to
/// show). Only the first acceptable request per tick starts; the rest are
/// refused as "already active".
class DialogueStartSystem implements System {
  final DialogueCommandAccess commandAccess;

  const DialogueStartSystem({
    this.commandAccess = const DialogueCommandAccess(),
  });

  static const String systemName = 'DialogueStartSystem';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    resourceReads: const {YarnProject, CommandHandler},
    resourceWrites: {
      DialogueState,
      VariableStorage,
      ...commandAccess.resourceWrites,
    },
    eventReads: const {DialogueStartRequested},
    eventWrites: {
      DialogueStarted,
      DialogueLineShown,
      DialogueChoicesReady,
      DialogueEnded,
      ...commandAccess.eventWrites,
    },
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final state = world.getResource<DialogueState>();
    if (state == null) return Future.value();
    for (final request in world.eventReader<DialogueStartRequested>().read()) {
      if (state.isActive) {
        _log(
          'Refused $request: "${state.startNode}" is already active',
          level: 900,
        );
        continue;
      }
      final project = world.getResource<YarnProject>();
      final storage = world.getResource<VariableStorage>();
      if (project == null || storage == null) {
        _log('Refused $request: Yarn isn\'t set up', level: 900);
        continue;
      }
      if (!project.hasNode(request.node)) {
        _log('Refused $request: no such node', level: 900);
        continue;
      }
      final runner = DialogueRunner(
        project: project,
        variableStorage: storage,
        commandHandler: world.getResource<CommandHandler>(),
      );
      state._begin(runner, request.node, request.context);
      world.eventWriter<DialogueStarted>().send(
        DialogueStarted(request.node, context: request.context),
      );
      runner.startNode(request.node);
      _syncFromRunner(world, state);
    }
    return Future.value();
  }
}

/// The per-tick driver of the active dialogue. First:
///
/// - [DialogueStopRequested] (matching context, see there): ends the
///   dialogue at once ([DialogueEnded] with `stopped: true`); nothing else
///   is applied.
/// - While held (a holding command, [registerHoldingCommand]): applies
///   [DialogueHoldReleased]s; once no hold is left it shows what the runner
///   stopped at. Every other request that tick is ignored.
///
/// Otherwise it types the current line, then applies this tick's requests:
///
/// 1. [DialogueSkipRequested] (unless a choice is pending): passes over
///    every remaining line, running every command and `<<set>>`, and stops
///    at the next choice ([DialogueChoicesReady], the leading line shown
///    fully) or the end ([DialogueEnded] with `skipped: true`). Nothing
///    else is applied that tick. With a choice pending it does nothing.
/// 2. [DialogueChoiceSelected] (from any sender): the first in-range one
///    selects that option ([DialogueChoiceMade], then the option's body
///    runs).
/// 3. [DialogueCursorMoved]: moves the highlight.
/// 4. [DialogueAdvanceRequested] (coalesced): with a choice pending,
///    selects the highlighted option; else completes the line's typing if
///    it's still typing; else advances.
///
/// A dialogue started this tick (by [DialogueStartSystem], which runs
/// first) ignores the tick's requests — they predate it.
class DialogueAdvanceSystem implements System {
  final DialogueCommandAccess commandAccess;
  final DialogueTimeSource timeSource;

  const DialogueAdvanceSystem({
    this.commandAccess = const DialogueCommandAccess(),
    this.timeSource = DialogueTimeSource.wallTime,
  });

  static const String systemName = 'DialogueAdvanceSystem';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    resourceReads: {YarnProject, CommandHandler, timeSource.resource},
    resourceWrites: {
      DialogueState,
      VariableStorage,
      ...commandAccess.resourceWrites,
    },
    eventReads: const {
      DialogueStopRequested,
      DialogueHoldReleased,
      DialogueAdvanceRequested,
      DialogueChoiceSelected,
      DialogueCursorMoved,
      DialogueSkipRequested,
    },
    eventWrites: {
      DialogueLineShown,
      DialogueChoicesReady,
      DialogueChoiceMade,
      DialogueEnded,
      ...commandAccess.eventWrites,
    },
    after: const [DialogueStartSystem.systemName],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final state = world.getResource<DialogueState>();
    if (state == null || !state.isActive) return Future.value();

    // Stop.
    for (final stop in world.eventReader<DialogueStopRequested>().read()) {
      final applies = stop.context == null
          ? !state._startedThisTick
          : stop.context == state.context;
      if (applies) {
        _stop(world, state);
        return Future.value();
      }
    }

    if (state._startedThisTick) {
      state._startedThisTick = false;
      return Future.value();
    }
    final runner = state._runner!;

    // Held by a holding command: only releases count.
    if (state.isHeld) {
      for (final release in world.eventReader<DialogueHoldReleased>().read()) {
        state._release(release.token);
      }
      if (!state.isHeld) {
        runner.resume();
        _syncFromRunner(world, state);
      }
      return Future.value();
    }

    state._type(timeSource.delta(world));

    // 1. Skip.
    if (world.eventReader<DialogueSkipRequested>().isNotEmpty &&
        !state.isWaitingForChoice) {
      _skip(world, state, runner);
      return Future.value();
    }

    // 2. A choice from any sender.
    if (state.isWaitingForChoice) {
      for (final request
          in world.eventReader<DialogueChoiceSelected>().read()) {
        if (request.index >= 0 && request.index < state.choices.length) {
          _select(world, state, runner, request.index);
          return Future.value();
        }
      }
      // 3. Keyboard highlight.
      for (final move in world.eventReader<DialogueCursorMoved>().read()) {
        state._moveCursor(move.delta);
      }
    }

    // 4. Continue.
    if (world.eventReader<DialogueAdvanceRequested>().isEmpty) {
      return Future.value();
    }
    if (state.isWaitingForChoice) {
      _select(world, state, runner, state.cursorIndex);
    } else if (!state.isLineComplete) {
      state._completeLine();
    } else {
      runner.advance();
      _syncFromRunner(world, state);
    }
    return Future.value();
  }

  static void _select(
    World world,
    DialogueState state,
    DialogueRunner runner,
    int index,
  ) {
    final choice = state.choices[index];
    world.eventWriter<DialogueChoiceMade>().send(
      DialogueChoiceMade(
        index,
        text: choice.text,
        tags: choice.tags,
        context: state.context,
      ),
    );
    runner.selectChoice(index);
    _syncFromRunner(world, state);
  }

  /// Upper bound on lines passed over by one skip (a runaway `<<jump>>`
  /// loop without choices can't hang the frame).
  static const int _maxSkippedLines = 10000;

  static void _skip(World world, DialogueState state, DialogueRunner runner) {
    var passed = 0;
    while (runner.state == DialogueRunnerState.line &&
        !state.isHeld &&
        passed++ < _maxSkippedLines) {
      runner.advance();
    }
    // A holding command stops the skip: the rest waits for the release.
    if (state.isHeld) return;
    if (runner.state == DialogueRunnerState.line) {
      _log('Skip stopped after $_maxSkippedLines lines', level: 900);
      _syncFromRunner(world, state);
      return;
    }
    _syncFromRunner(world, state, skipped: true);
  }
}

/// Ends the dialogue now ([DialogueStopRequested]).
void _stop(World world, DialogueState state) {
  world.eventWriter<DialogueEnded>().send(
    DialogueEnded(
      state._startNode ?? '',
      context: state._context,
      stopped: true,
    ),
  );
  state._clear();
}

/// Mirrors the runner into [state] after it moved, and announces it —
/// unless a holding command is holding it (then nothing is shown until the
/// release, which calls this again).
void _syncFromRunner(World world, DialogueState state, {bool skipped = false}) {
  final runner = state._runner;
  if (runner == null || state.isHeld) return;
  switch (runner.state) {
    case DialogueRunnerState.line:
      final line = runner.currentDialogueLine!;
      state._showLine(line);
      world.eventWriter<DialogueLineShown>().send(DialogueLineShown(line));
    case DialogueRunnerState.choices:
      final lead = runner.currentDialogueLine;
      if (lead == null) {
        state._line = null;
      } else if (!identical(lead, state._line)) {
        state._showLine(lead, complete: true);
      }
      final choices = [
        for (final choice in runner.currentChoices)
          DialogueChoice(
            text: choice.text,
            tags: List.unmodifiable(choice.tags),
            isAvailable: choice.isAvailable,
          ),
      ];
      state._showChoices(choices);
      world.eventWriter<DialogueChoicesReady>().send(
        DialogueChoicesReady(state.choices),
      );
    case DialogueRunnerState.paused:
      // A pausing command (registerHoldingCommand) that did not hold —
      // e.g. it received malformed arguments and returned null. Resume
      // the runner in place, sync from the next stop.
      runner.resume();
      _syncFromRunner(world, state, skipped: skipped);
    case DialogueRunnerState.ended:
    case DialogueRunnerState.inactive:
      world.eventWriter<DialogueEnded>().send(
        DialogueEnded(
          state._startNode ?? '',
          context: state._context,
          skipped: skipped,
        ),
      );
      state._clear();
  }
}
