import 'yarn_line.dart';
import 'yarn_node.dart';

/// Parses Yarn Spinner format text into [YarnNode] objects.
///
/// Supports the core Yarn syntax:
/// - Nodes with headers (`title:`, `tags:`, custom headers)
/// - Dialogue lines (`Character: text` or just `text`)
/// - Choices (`-> choice text`)
/// - Commands (`<<command args>>`)
/// - Conditionals (`<<if>>`, `<<elseif>>`, `<<else>>`, `<<endif>>`)
/// - Jumps (`<<jump node>>`)
/// - Line tags (`#tag`)
/// - Comments (`//`)
class YarnParser {
  static final _nodeHeaderPattern = RegExp(r'^(\w+):\s*(.*)$');
  static final _dialoguePattern = RegExp(r'^(\w+):\s+(.+)$');
  static final _choicePattern = RegExp(r'^(\s*)->\s+(.+)$');
  static final _commandPattern = RegExp(r'<<\s*(\w+)(?:\s+(.+?))?\s*>>');
  static final _tagPattern = RegExp(r'#(\w+)');
  static final _lineIdPattern = RegExp(r'#line:(\w+)');

  /// Parse Yarn content into a list of nodes.
  List<YarnNode> parse(String content) {
    final nodes = <YarnNode>[];
    // Normalize line endings (handle Windows \r\n and old Mac \r)
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = content.split('\n');

    var i = 0;
    while (i < lines.length) {
      // Skip empty lines and comments outside nodes
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('//')) {
        i++;
        continue;
      }

      // Look for node start (title header)
      if (line.startsWith('title:')) {
        final result = _parseNode(lines, i);
        nodes.add(result.node);
        i = result.nextIndex;
      } else {
        i++;
      }
    }

    return nodes;
  }

  _ParseResult _parseNode(List<String> lines, int startIndex) {
    final headers = <String, String>{};
    var tags = <String>[];
    var i = startIndex;

    // Parse headers until we hit ---
    while (i < lines.length) {
      final line = lines[i].trim();

      if (line == '---') {
        i++;
        break;
      }

      if (line.isEmpty || line.startsWith('//')) {
        i++;
        continue;
      }

      final match = _nodeHeaderPattern.firstMatch(line);
      if (match != null) {
        final key = match.group(1)!;
        final value = match.group(2)!;

        if (key == 'tags') {
          tags =
              value.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
        } else {
          headers[key] = value;
        }
      }
      i++;
    }

    // Parse body until we hit ===
    final bodyLines = <YarnLine>[];
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed == '===') {
        i++;
        break;
      }

      if (trimmed.isEmpty || trimmed.startsWith('//')) {
        i++;
        continue;
      }

      final result = _parseLine(lines, i);
      if (result.line != null) {
        bodyLines.add(result.line!);
      }
      i = result.nextIndex;
    }

    final title = headers.remove('title') ?? 'untitled';

    return _ParseResult(
      node: YarnNode(
        title: title,
        tags: tags,
        headers: headers,
        lines: bodyLines,
      ),
      nextIndex: i,
    );
  }

  _LineParseResult _parseLine(List<String> lines, int index) {
    final line = lines[index];
    final trimmed = line.trim();

    // Check for choice
    final choiceMatch = _choicePattern.firstMatch(line);
    if (choiceMatch != null) {
      return _parseChoiceSet(lines, index);
    }

    // Check for command
    if (trimmed.startsWith('<<')) {
      return _parseCommand(lines, index);
    }

    // Regular dialogue line
    return _LineParseResult(
      line: _parseDialogueLine(trimmed),
      nextIndex: index + 1,
    );
  }

  DialogueLine _parseDialogueLine(String line) {
    // Extract tags
    final tags = <String>[];
    String? lineId;

    final lineIdMatch = _lineIdPattern.firstMatch(line);
    if (lineIdMatch != null) {
      lineId = lineIdMatch.group(1);
      line = line.replaceFirst(lineIdMatch.group(0)!, '').trim();
    }

    for (final match in _tagPattern.allMatches(line)) {
      tags.add(match.group(1)!);
    }
    line = line.replaceAll(_tagPattern, '').trim();

    // Check for character prefix
    final dialogueMatch = _dialoguePattern.firstMatch(line);
    if (dialogueMatch != null) {
      return DialogueLine(
        character: dialogueMatch.group(1),
        text: dialogueMatch.group(2)!.trim(),
        tags: tags,
        lineId: lineId,
      );
    }

    // No character, just text
    return DialogueLine(
      text: line,
      tags: tags,
      lineId: lineId,
    );
  }

  _LineParseResult _parseChoiceSet(List<String> lines, int startIndex) {
    final choices = <Choice>[];
    var i = startIndex;

    // Get the indentation level of the first choice
    final firstLine = lines[i];
    final baseIndent = _getIndent(firstLine);

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed == '===' || trimmed.isEmpty && i > startIndex) {
        // Check if next non-empty line is still a choice at same level
        var nextNonEmpty = i + 1;
        while (
            nextNonEmpty < lines.length && lines[nextNonEmpty].trim().isEmpty) {
          nextNonEmpty++;
        }
        if (nextNonEmpty >= lines.length ||
            !lines[nextNonEmpty].trim().startsWith('->') ||
            _getIndent(lines[nextNonEmpty]) != baseIndent) {
          break;
        }
        i++;
        continue;
      }

      final choiceMatch = _choicePattern.firstMatch(line);
      if (choiceMatch != null && _getIndent(line) == baseIndent) {
        final choiceText = choiceMatch.group(2)!;

        // Extract condition if present
        String? condition;
        var text = choiceText;
        final condMatch = RegExp(r'<<if\s+(.+?)>>').firstMatch(choiceText);
        if (condMatch != null) {
          condition = condMatch.group(1);
          text = text.replaceFirst(condMatch.group(0)!, '').trim();
        }

        // Extract tags
        final tags = <String>[];
        for (final match in _tagPattern.allMatches(text)) {
          tags.add(match.group(1)!);
        }
        text = text.replaceAll(_tagPattern, '').trim();

        // Parse choice body (indented lines after the choice)
        i++;
        final body = <YarnLine>[];
        final choiceIndent = baseIndent + 4; // Expect 4-space indent for body

        while (i < lines.length) {
          final bodyLine = lines[i];
          final bodyTrimmed = bodyLine.trim();

          if (bodyTrimmed == '===') break;
          if (bodyTrimmed.isEmpty) {
            i++;
            continue;
          }

          final bodyIndent = _getIndent(bodyLine);
          if (bodyIndent < choiceIndent) break;

          // Parse the body line
          final result = _parseLine(lines, i);
          if (result.line != null) {
            body.add(result.line!);
          }
          i = result.nextIndex;
        }

        choices.add(Choice(
          text: text,
          condition: condition,
          body: body,
          tags: tags,
        ));
      } else {
        break;
      }
    }

    return _LineParseResult(
      line: ChoiceSet(choices: choices),
      nextIndex: i,
    );
  }

  _LineParseResult _parseCommand(List<String> lines, int index) {
    final line = lines[index].trim();
    final match = _commandPattern.firstMatch(line);

    if (match == null) {
      return _LineParseResult(line: null, nextIndex: index + 1);
    }

    final command = match.group(1)!.toLowerCase();
    final argsStr = match.group(2) ?? '';
    final args = argsStr.isEmpty ? <String>[] : _parseArguments(argsStr);

    // Handle special commands
    switch (command) {
      case 'jump':
        return _LineParseResult(
          line: JumpLine(targetNode: args.isNotEmpty ? args[0] : ''),
          nextIndex: index + 1,
        );

      case 'if':
        return _parseConditional(lines, index);

      case 'set':
      case 'declare':
      case 'wait':
      case 'stop':
      default:
        return _LineParseResult(
          line: CommandLine(command: command, arguments: args),
          nextIndex: index + 1,
        );
    }
  }

  _LineParseResult _parseConditional(List<String> lines, int startIndex) {
    final line = lines[startIndex].trim();
    final condMatch = RegExp(r'<<if\s+(.+?)>>').firstMatch(line);
    if (condMatch == null) {
      return _LineParseResult(line: null, nextIndex: startIndex + 1);
    }

    final condition = condMatch.group(1)!;
    final thenBranch = <YarnLine>[];
    var i = startIndex + 1;

    // Parse the "then" branch until we hit elseif, else, or endif
    while (i < lines.length) {
      final currentLine = lines[i].trim();

      if (currentLine == '===') break;
      if (currentLine.startsWith('<<endif>>')) {
        i++;
        return _LineParseResult(
          line: ConditionalBlock(
            condition: condition,
            thenBranch: thenBranch,
            elseBranch: const [],
          ),
          nextIndex: i,
        );
      }
      if (currentLine.startsWith('<<elseif') ||
          currentLine.startsWith('<<else>>')) {
        break;
      }

      if (currentLine.isEmpty || currentLine.startsWith('//')) {
        i++;
        continue;
      }

      final result = _parseLine(lines, i);
      if (result.line != null) {
        thenBranch.add(result.line!);
      }
      i = result.nextIndex;
    }

    // Now handle elseif/else
    final elseBranch = <YarnLine>[];
    if (i < lines.length) {
      final currentLine = lines[i].trim();

      if (currentLine.startsWith('<<elseif')) {
        // Parse elseif as a nested conditional
        final elseifMatch =
            RegExp(r'<<elseif\s+(.+?)>>').firstMatch(currentLine);
        if (elseifMatch != null) {
          // Create a synthetic <<if>> line and parse recursively
          final elseifCondition = elseifMatch.group(1)!;
          final syntheticIfLine = '<<if $elseifCondition>>';
          final syntheticLines = [syntheticIfLine, ...lines.sublist(i + 1)];
          final nestedResult = _parseConditional(syntheticLines, 0);
          if (nestedResult.line != null) {
            elseBranch.add(nestedResult.line!);
          }
          // Adjust index: we consumed (nestedResult.nextIndex - 1) lines from original
          i = i + nestedResult.nextIndex;
        }
      } else if (currentLine.startsWith('<<else>>')) {
        i++;
        // Parse else branch until endif
        while (i < lines.length) {
          final elseLine = lines[i].trim();

          if (elseLine == '===') break;
          if (elseLine.startsWith('<<endif>>')) {
            i++;
            break;
          }

          if (elseLine.isEmpty || elseLine.startsWith('//')) {
            i++;
            continue;
          }

          final result = _parseLine(lines, i);
          if (result.line != null) {
            elseBranch.add(result.line!);
          }
          i = result.nextIndex;
        }
      }
    }

    return _LineParseResult(
      line: ConditionalBlock(
        condition: condition,
        thenBranch: thenBranch,
        elseBranch: elseBranch,
      ),
      nextIndex: i,
    );
  }

  int _getIndent(String line) {
    var indent = 0;
    for (final char in line.codeUnits) {
      if (char == 32) {
        // space
        indent++;
      } else if (char == 9) {
        // tab
        indent += 4;
      } else {
        break;
      }
    }
    return indent;
  }

  List<String> _parseArguments(String argsStr) {
    final args = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var quoteChar = '';

    for (var i = 0; i < argsStr.length; i++) {
      final char = argsStr[i];

      if (!inQuotes && (char == '"' || char == "'")) {
        inQuotes = true;
        quoteChar = char;
      } else if (inQuotes && char == quoteChar) {
        inQuotes = false;
        quoteChar = '';
      } else if (!inQuotes && char == ' ') {
        if (buffer.isNotEmpty) {
          args.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      args.add(buffer.toString());
    }

    return args;
  }
}

class _ParseResult {
  final YarnNode node;
  final int nextIndex;

  _ParseResult({required this.node, required this.nextIndex});
}

class _LineParseResult {
  final YarnLine? line;
  final int nextIndex;

  _LineParseResult({required this.line, required this.nextIndex});
}
