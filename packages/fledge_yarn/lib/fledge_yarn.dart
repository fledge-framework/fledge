/// Yarn Spinner dialogue system for Fledge games.
///
/// This library provides a complete dialogue system based on the Yarn Spinner
/// format. It supports:
///
/// - **Yarn file parsing**: Load `.yarn` files with nodes, lines, and choices
/// - **Variables**: Store and retrieve dialogue variables
/// - **Commands**: Execute game commands from dialogue (e.g., `<<give_item sword>>`)
/// - **Conditionals**: Branch dialogue based on conditions
/// - **ECS Integration**: Plugin and resources for Fledge games
///
/// ## Quick Start
///
/// ```dart
/// import 'package:fledge_yarn/fledge_yarn.dart';
///
/// // Parse a Yarn file
/// final project = YarnProject();
/// project.parse(yarnContent);
///
/// // Run dialogue
/// final runner = DialogueRunner(project: project, variableStorage: storage);
/// runner.startNode('sara_greeting');
///
/// while (runner.canContinue) {
///   final line = runner.currentLine;
///   print('${line.character}: ${line.text}');
///   runner.advance();
/// }
/// ```
///
/// ## Yarn Syntax
///
/// ```yarn
/// title: my_node
/// ---
/// Character: Hello, world!
/// Character: How are you?
/// -> I'm good!
///     Character: Great to hear!
/// -> Not so great...
///     Character: I'm sorry to hear that.
/// ===
/// ```
library fledge_yarn;

// Core data structures
export 'src/yarn_project.dart';
export 'src/yarn_node.dart';
export 'src/yarn_line.dart';

// Parser
export 'src/yarn_parser.dart';

// Runtime
export 'src/dialogue_runner.dart';
export 'src/variable_storage.dart';
export 'src/command_handler.dart';

// Plugin
export 'src/plugin.dart';
