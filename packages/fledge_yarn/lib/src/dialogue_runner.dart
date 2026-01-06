import 'command_handler.dart';
import 'variable_storage.dart';
import 'yarn_line.dart';
import 'yarn_node.dart';
import 'yarn_project.dart';

/// The current state of the dialogue runner.
enum DialogueState {
  /// No dialogue is running.
  inactive,

  /// Displaying a line of dialogue.
  line,

  /// Waiting for the player to select a choice.
  choices,

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
/// while (runner.state != DialogueState.ended) {
///   switch (runner.state) {
///     case DialogueState.line:
///       final line = runner.currentDialogueLine!;
///       print('${line.character}: ${line.text}');
///       runner.advance();
///       break;
///     case DialogueState.choices:
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

  DialogueState _state = DialogueState.inactive;
  YarnNode? _currentNode;
  List<YarnLine> _lineQueue = [];
  int _lineIndex = 0;
  DialogueLine? _currentLine;
  List<Choice>? _currentChoices;
  final List<String> _nodeHistory = [];

  /// Current state of the dialogue runner.
  DialogueState get state => _state;

  /// Whether dialogue can continue (not ended or inactive).
  bool get canContinue =>
      _state == DialogueState.line || _state == DialogueState.choices;

  /// Whether the runner is waiting for a choice selection.
  bool get isWaitingForChoice => _state == DialogueState.choices;

  /// The current dialogue line being displayed.
  DialogueLine? get currentDialogueLine => _currentLine;

  /// The current choices available (if state is [DialogueState.choices]).
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
    if (_state != DialogueState.line) return;

    _lineIndex++;
    _processNext();
  }

  /// Select a choice by index.
  ///
  /// Call this when the player makes a choice.
  void selectChoice(int index) {
    if (_state != DialogueState.choices) return;
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

  /// Stop the current dialogue.
  void stop() {
    _state = DialogueState.ended;
    _currentNode = null;
    _lineQueue = [];
    _lineIndex = 0;
    _currentLine = null;
    _currentChoices = null;
    onDialogueEnd?.call();
  }

  /// Reset the runner to inactive state.
  void reset() {
    _state = DialogueState.inactive;
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
          _state = DialogueState.line;
          onLine?.call(line);
          return;

        case ChoiceSet():
          _processChoices(line);
          if (_state == DialogueState.choices) return;
          break;

        case CommandLine():
          _executeCommand(line);
          _lineIndex++;
          break;

        case ConditionalBlock():
          _processConditional(line);
          break;

        case JumpLine():
          if (!startNode(line.targetNode)) {
            // Jump target not found, continue
            _lineIndex++;
          }
          return;
      }
    }

    // Reached end of node
    _state = DialogueState.ended;
    onDialogueEnd?.call();
  }

  void _processChoices(ChoiceSet choiceSet) {
    // Filter choices based on conditions
    final availableChoices = <Choice>[];

    for (final choice in choiceSet.choices) {
      if (choice.condition != null) {
        choice.isAvailable =
            variableStorage.evaluateCondition(choice.condition!);
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
    _state = DialogueState.choices;
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
        // Try custom handler
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
