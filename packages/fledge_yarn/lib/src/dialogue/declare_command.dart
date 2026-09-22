import 'dart:developer' as developer;

import '../variable_storage.dart';

/// The Yarn command name of [declareCommand].
const String declareCommandName = 'declare';

/// `<<declare $name = default>>` (optionally `... as Type`): seeds
/// `$name` with its default **only if it has no value yet**, so running a
/// declaration node again (or after a load) never resets progress.
///
/// fledge_yarn's runner passes `declare` to the command handler as
/// arguments (`['$name', '=', 'false']`); the default is evaluated like a
/// `<<set>>` right-hand side. Malformed declarations are logged and ignored.
/// Always reports the command as handled.
bool declareCommand(VariableStorage storage, List<String> arguments) {
  var expression = arguments.join(' ').trim();
  // Yarn's optional type annotation: `<<declare $x = 0 as Number>>`.
  expression = expression.replaceFirst(RegExp(r'\s+as\s+\w+$'), '');
  final match = RegExp(r'^\$?(\w+)\s*=\s*(.+)$').firstMatch(expression);
  if (match == null) {
    developer.log(
      '<<declare ${arguments.join(' ')}>>: expected "\$name = value"',
      name: 'dialogue',
      level: 900,
    );
    return true;
  }
  final name = match.group(1)!;
  if (!storage.hasVariable(name)) {
    storage.executeSet('\$$name = ${match.group(2)}');
  }
  return true;
}
