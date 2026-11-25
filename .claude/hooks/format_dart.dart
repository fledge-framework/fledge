// Claude Code PostToolUse hook: runs `dart format` on an edited .dart file.
//
// Reads the hook payload (JSON) from stdin. Written in Dart rather than shell
// so it works identically on Linux, macOS, and Windows without jq.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final payload = jsonDecode(await stdin.transform(utf8.decoder).join());
  final path = (payload['tool_response']?['filePath'] ??
      payload['tool_input']?['file_path']) as String?;
  if (path == null || !path.endsWith('.dart') || !File(path).existsSync()) {
    return;
  }
  // The running VM's own executable — avoids PATH / dart.bat issues on Windows.
  final result =
      await Process.run(Platform.resolvedExecutable, ['format', path]);
  if (result.exitCode != 0) stderr.write(result.stderr);
}
