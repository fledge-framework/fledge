/// A single line of dialogue in a Yarn node.
///
/// Lines can be:
/// - **Dialogue lines**: Text spoken by a character
/// - **Choice options**: Player choices that branch the dialogue
/// - **Commands**: Instructions to the game (e.g., `<<give_item sword>>`)
sealed class YarnLine {
  const YarnLine();
}

/// A line of dialogue spoken by a character.
///
/// Example: `Sara: Hello there!`
class DialogueLine extends YarnLine {
  /// The character speaking this line, or null for narrator.
  final String? character;

  /// The text content of the line.
  final String text;

  /// Optional tags attached to this line (e.g., `#excited #whisper`).
  final List<String> tags;

  /// Optional line ID for localization.
  final String? lineId;

  const DialogueLine({
    this.character,
    required this.text,
    this.tags = const [],
    this.lineId,
  });

  @override
  String toString() => character != null ? '$character: $text' : text;
}

/// A set of choices presented to the player.
///
/// Example:
/// ```yarn
/// -> Choice 1
///     Response 1
/// -> Choice 2
///     Response 2
/// ```
class ChoiceSet extends YarnLine {
  /// The available choices.
  final List<Choice> choices;

  const ChoiceSet({required this.choices});
}

/// A single choice option within a [ChoiceSet].
class Choice {
  /// The text displayed for this choice.
  final String text;

  /// Optional condition that must be true to show this choice.
  final String? condition;

  /// Lines to execute when this choice is selected.
  final List<YarnLine> body;

  /// Optional tags attached to this choice.
  final List<String> tags;

  /// Whether this choice is currently available (condition passed).
  bool isAvailable;

  Choice({
    required this.text,
    this.condition,
    this.body = const [],
    this.tags = const [],
    this.isAvailable = true,
  });

  @override
  String toString() => '-> $text';
}

/// A command to be executed by the game.
///
/// Example: `<<set $hasKey = true>>` or `<<give_item sword>>`
class CommandLine extends YarnLine {
  /// The command name (e.g., "set", "give_item", "jump").
  final String command;

  /// Arguments to the command.
  final List<String> arguments;

  const CommandLine({
    required this.command,
    this.arguments = const [],
  });

  @override
  String toString() => '<<$command ${arguments.join(' ')}>>';
}

/// A conditional block that shows content based on a condition.
///
/// Example:
/// ```yarn
/// <<if $hasKey>>
///     You have the key!
/// <<else>>
///     You need to find the key.
/// <<endif>>
/// ```
class ConditionalBlock extends YarnLine {
  /// The condition to evaluate.
  final String condition;

  /// Lines to execute if condition is true.
  final List<YarnLine> thenBranch;

  /// Lines to execute if condition is false.
  final List<YarnLine> elseBranch;

  const ConditionalBlock({
    required this.condition,
    required this.thenBranch,
    this.elseBranch = const [],
  });
}

/// A jump to another node.
///
/// Example: `<<jump other_node>>`
class JumpLine extends YarnLine {
  /// The target node to jump to.
  final String targetNode;

  const JumpLine({required this.targetNode});

  @override
  String toString() => '<<jump $targetNode>>';
}
