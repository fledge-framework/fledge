import 'dart:developer' as developer;

/// Signature of [yarnLog].
typedef YarnLogFunction = void Function(
  String message, {
  required String name,
  required int level,
});

/// Writes a fledge_yarn diagnostic. Defaults to `dart:developer`'s `log`;
/// tests swap it to capture the messages. Internal: not exported from
/// `package:fledge_yarn`, so only the package's own code and tests see it.
YarnLogFunction yarnLog = _developerLog;

void _developerLog(
  String message, {
  required String name,
  required int level,
}) => developer.log(message, name: name, level: level);
