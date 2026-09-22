import 'dart:developer' as developer;

import 'command_handler.dart';
import 'variable_storage.dart';
import 'yarn_line.dart';
import 'yarn_node.dart';
import 'yarn_project.dart';

/// The current state of the dialogue runner.
enum DialogueRunnerState {
  /// No dialogue is running.
  inactive,

  /// Displaying a line of dialogue.
  line,

  /// Waiting for the player to select a choice.
  choices,

  /// A pausing command handler has run and the runner is holding
  /// until [DialogueRunner.resume] is called. Statements after the
  /// pausing command have NOT been processed yet, so the pause is
  /// exact — matches the "pause here" semantics [CommandHandler]
  /// exposes via [CommandHandler.registerPausing].
  paused,

  /// Dialogue has ended (reached end of node or stop command).
  ended,
}

/// Runs through Yarn dialogue, tracking state and handling choices.
///
/// The runner processes dialogue line by line, pausing for player interaction
/// when choices are presented.
///
/// Example:
/// ```dart
/// final runner = DialogueRunner(
///   project: project,
///   variableStorage: storage,
///   commandHandler: commands,
/// );
///
/// runner.startNode('greeting');
///
/// while (runner.state != DialogueRunnerState.ended) {
///   switch (runner.state) {
///     case DialogueRunnerState.line:
///       final line = runner.currentDialogueLine!;
///       print('${line.character}: ${line.text}');
///       runner.advance();
///       break;
///     case DialogueRunnerState.choices:
///       for (var i = 0; i < runner.currentChoices.length; i++) {
///         print('$i: ${runner.currentChoices[i].text}');
///       }
///       runner.selectChoice(0); // Player selects first choice
///       break;
///   }
/// }
/// ```
class DialogueRunner {
  /// The Yarn project containing dialogue nodes.
  final YarnProject project;

  /// Storage for dialogue variables.
  final VariableStorage variableStorage;

  /// Handler for custom commands.
  final CommandHandler? commandHandler;

  /// Called when a line is ready to be displayed.
  final void Function(DialogueLine line)? onLine;

  /// Called when choices are available.
  final void Function(List<Choice> choices)? onChoices;

  /// Called when a command is executed.
  final void Function(String command, List<String> args)? onCommand;

  /// Called when the dialogue ends.
  final void Function()? onDialogueEnd;

  /// Called when jumping to a new node.
  final void Function(String nodeTitle)? onNodeStart;

  DialogueRunnerState _state = DialogueRunnerState.inactive;
  YarnNode? _currentNode;
  List<YarnLine> _lineQueue = [];
  int _lineIndex = 0;
  DialogueLine? _currentLine;
  List<Choice>? _currentChoices;
  final List<String> _nodeHistory = [];

  /// Current state of the dialogue runner.
  DialogueRunnerState get state => _state;

  /// Whether dialogue can continue (not ended or inactive).
  bool get canContinue =>
      _state == DialogueRunnerState.line ||
      _state == DialogueRunnerState.choices;

  /// Whether the runner is waiting for a choice selection.
  bool get isWaitingForChoice => _state == DialogueRunnerState.choices;

  /// The current dialogue line being displayed.
  DialogueLine? get currentDialogueLine => _currentLine;

  /// The current choices available (if state is [DialogueRunnerState.choices]).
  List<Choice> get currentChoices => _currentChoices ?? [];

  /// The title of the current node.
  String? get currentNodeTitle => _currentNode?.title;

  /// History of visited node titles.
  List<String> get nodeHistory => List.unmodifiable(_nodeHistory);

  /// Create a dialogue runner.
  DialogueRunner({
    required this.project,
    required this.variableStorage,
    this.commandHandler,
    this.onLine,
    this.onChoices,
    this.onCommand,
    this.onDialogueEnd,
    this.onNodeStart,
  });

  /// Start dialogue at a specific node.
  ///
  /// Returns `false` if the node doesn't exist.
  bool startNode(String nodeTitle) {
    final node = project.getNode(nodeTitle);
    if (node == null) return false;

    _currentNode = node;
    _lineQueue = List.from(node.lines);
    _lineIndex = 0;
    _currentLine = null;
    _currentChoices = null;
    _nodeHistory.add(nodeTitle);

    onNodeStart?.call(nodeTitle);

    // Process until we hit a line or choices
    _processNext();

    return true;
  }

  /// Advance to the next line of dialogue.
  ///
  /// Call this after displaying a line to the player.
  void advance() {
    if (_state != DialogueRunnerState.line) return;

    _lineIndex++;
    _processNext();
  }

  /// Select a choice by index.
  ///
  /// Call this when the player makes a choice.
  void selectChoice(int index) {
    if (_state != DialogueRunnerState.choices) return;
    if (_currentChoices == null ||
        index < 0 ||
        index >= _currentChoices!.length) {
      return;
    }

    final choice = _currentChoices![index];

    // Execute choice body, then continue past the ChoiceSet
    // _lineIndex + 1 skips the ChoiceSet so we don't loop back to choices
    final remaining = _lineQueue.sublist(_lineIndex + 1);
    if (choice.body.isNotEmpty) {
      _lineQueue = [...choice.body, ...remaining];
      _lineIndex = 0;
    } else {
      _lineQueue = remaining;
      _lineIndex = 0;
    }

    _currentChoices = null;
    _processNext();
  }

  /// Resume the runner after a pausing command has held it.
  ///
  /// See [CommandHandler.registerPausing]. Call this once the game-
  /// side work triggered by a `<<pausingCommand>>` is done and the
  /// dialogue can move on. No-op unless the runner is currently in
  /// [DialogueRunnerState.paused].
  void resume() {
    if (_state != DialogueRunnerState.paused) return;
    _state = DialogueRunnerState.inactive;
    _processNext();
  }

  /// Stop the current dialogue.
  void stop() {
    _state = DialogueRunnerState.ended;
    _currentNode = null;
    _lineQueue = [];
    _lineIndex = 0;
    _currentLine = null;
    _currentChoices = null;
    onDialogueEnd?.call();
  }

  /// Reset the runner to inactive state.
  void reset() {
    _state = DialogueRunnerState.inactive;
    _currentNode = null;
    _lineQueue = [];
    _lineIndex = 0;
    _currentLine = null;
    _currentChoices = null;
    _nodeHistory.clear();
  }

  void _processNext() {
    while (_lineIndex < _lineQueue.length) {
      final line = _lineQueue[_lineIndex];

      switch (line) {
        case DialogueLine():
          _currentLine = line;
          _state = DialogueRunnerState.line;
          onLine?.call(line);
          return;

        case ChoiceSet():
          _processChoices(line);
          if (_state == DialogueRunnerState.choices) return;
          break;

        case CommandLine():
          _executeCommand(line);
          _lineIndex++;
          // A pausing command handler flipped _state = paused. Stop
          // processing here; DialogueRunner.resume() picks up at the
          // next statement.
          if (_state == DialogueRunnerState.paused) return;
          break;

        case ConditionalBlock():
          _processConditional(line);
          break;

        case JumpLine():
          if (!startNode(line.targetNode)) {
            // Jump target not found. The pre-Batch-8 behaviour was
            // to `_lineIndex++` and `return`, which left `_state` at
            // whatever it was (typically `line`) and kept the
            // previous line visible on the box. That produced a
            // stale line that never advanced. Log the miss and end
            // the dialogue — matches the "end the dialogue" choice
            // documented in the Batch 8 handoff.
            developer.log(
              'Jump target "${line.targetNode}" not found; '
              'ending dialogue.',
              name: 'fledge_yarn.dialogue_runner',
            );
            _lineIndex = _lineQueue.length; // stop the outer loop
            _currentLine = null;
            _state = DialogueRunnerState.ended;
            onDialogueEnd?.call();
          }
          return;
      }
    }

    // Reached end of node
    _state = DialogueRunnerState.ended;
    onDialogueEnd?.call();
  }

  void _processChoices(ChoiceSet choiceSet) {
    // Filter choices based on conditions
    final availableChoices = <Choice>[];

    for (final choice in choiceSet.choices) {
      if (choice.condition != null) {
        choice.isAvailable = variableStorage.evaluateCondition(
          choice.condition!,
        );
      } else {
        choice.isAvailable = true;
      }

      if (choice.isAvailable) {
        availableChoices.add(choice);
      }
    }

    if (availableChoices.isEmpty) {
      // No valid choices, skip
      _lineIndex++;
      return;
    }

    _currentChoices = availableChoices;
    _state = DialogueRunnerState.choices;
    onChoices?.call(availableChoices);
  }

  void _executeCommand(CommandLine line) {
    final command = line.command;
    final args = line.arguments;

    onCommand?.call(command, args);

    // Handle built-in commands
    switch (command) {
      case 'set':
        if (args.isNotEmpty) {
          variableStorage.executeSet(args.join(' '));
        }
        break;

      case 'stop':
        stop();
        break;

      case 'wait':
        // Wait is typically handled by the game
        break;

      default:
        // Pausing handler takes priority — it runs synchronously and
        // decides via its return value whether to pause. When it
        // pauses, the runner stops until DialogueRunner.resume() is
        // called. Statements between the pausing command and the
        // next line / choice haven't been processed yet, so the
        // pause is exact.
        if (commandHandler != null &&
            commandHandler!.hasPausingHandler(command)) {
          final shouldPause = commandHandler!.executePausing(command, args);
          if (shouldPause) {
            _state = DialogueRunnerState.paused;
            return;
          }
          break;
        }
        // Fall back to the regular handler.
        commandHandler?.execute(command, args);
    }
  }

  void _processConditional(ConditionalBlock block) {
    final result = variableStorage.evaluateCondition(block.condition);

    // Insert the appropriate branch into the queue
    final branch = result ? block.thenBranch : block.elseBranch;
    if (branch.isNotEmpty) {
      final remaining = _lineQueue.sublist(_lineIndex + 1);
      _lineQueue = [
        ..._lineQueue.sublist(0, _lineIndex),
        ...branch,
        ...remaining,
      ];
    } else {
      _lineIndex++;
    }
  }
}
