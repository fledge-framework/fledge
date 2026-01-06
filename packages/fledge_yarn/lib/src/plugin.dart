import 'package:fledge_ecs/fledge_ecs.dart';

import 'command_handler.dart';
import 'dialogue_runner.dart';
import 'variable_storage.dart';
import 'yarn_line.dart';
import 'yarn_project.dart';

/// Fledge plugin that provides Yarn dialogue resources.
///
/// Registers [YarnProject], [VariableStorage], and [CommandHandler] as
/// world resources.
///
/// Example:
/// ```dart
/// final app = App()
///   ..addPlugin(YarnPlugin());
///
/// // Access resources
/// final project = app.world.getResource<YarnProject>()!;
/// final storage = app.world.getResource<VariableStorage>()!;
/// ```
class YarnPlugin implements Plugin {
  /// Initial Yarn content to parse.
  final String? initialContent;

  /// Initial variables to set.
  final Map<String, dynamic>? initialVariables;

  /// Create the Yarn plugin.
  ///
  /// Optionally provide [initialContent] to parse on startup and
  /// [initialVariables] to pre-populate variable storage.
  YarnPlugin({
    this.initialContent,
    this.initialVariables,
  });

  @override
  void build(App app) {
    final project = YarnProject();
    final storage = VariableStorage();
    final commands = CommandHandler();

    // Parse initial content
    if (initialContent != null) {
      project.parse(initialContent!);
    }

    // Set initial variables
    if (initialVariables != null) {
      storage.loadFromJson(initialVariables!);
    }

    app.insertResource(project);
    app.insertResource(storage);
    app.insertResource(commands);
  }

  @override
  void cleanup() {}
}

/// Resource wrapper for [DialogueRunner] that integrates with the ECS world.
///
/// Use this to run dialogue and track state. Create instances as needed
/// for different dialogue sessions.
///
/// Example:
/// ```dart
/// final project = world.getResource<YarnProject>()!;
/// final storage = world.getResource<VariableStorage>()!;
/// final commands = world.getResource<CommandHandler>()!;
///
/// final runner = DialogueRunner(
///   project: project,
///   variableStorage: storage,
///   commandHandler: commands,
/// );
///
/// runner.startNode('greeting');
/// ```
///
/// For more complex scenarios, consider creating a custom resource that
/// wraps [DialogueRunner] with game-specific logic.
extension YarnWorldExtensions on World {
  /// Create a new dialogue runner using world resources.
  ///
  /// The world must have [YarnProject] and [VariableStorage] resources
  /// registered (via [YarnPlugin]).
  DialogueRunner? createDialogueRunner({
    void Function(DialogueLine line)? onLine,
    void Function(List<Choice> choices)? onChoices,
    void Function(String command, List<String> args)? onCommand,
    void Function()? onDialogueEnd,
    void Function(String nodeTitle)? onNodeStart,
  }) {
    final project = getResource<YarnProject>();
    final storage = getResource<VariableStorage>();
    final commands = getResource<CommandHandler>();

    if (project == null || storage == null) return null;

    return DialogueRunner(
      project: project,
      variableStorage: storage,
      commandHandler: commands,
      onLine: onLine,
      onChoices: onChoices,
      onCommand: onCommand,
      onDialogueEnd: onDialogueEnd,
      onNodeStart: onNodeStart,
    );
  }
}
