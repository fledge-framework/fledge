// Checks the code in the docs.
//
//   cd docs && dart run tool/check_snippets.dart [--keep]
//
// 1. Every ```dart block (and every tab of a ```dart-tabs block) in
//    assets/docs/**.md is written to build/doc_snippets/ and analyzed with
//    `dart analyze`. Errors and warnings fail the check; infos do not.
//    - Each snippet gets a prelude importing dart:async, dart:math (as
//      `math`), dart:typed_data, dart:ui and every fledge package barrel,
//      unless it has its own imports, in which case it is used as written.
//    - A page can declare code its snippets share (component classes and
//      the like) in a hidden block, which the site does not render:
//        <!-- snippet-setup
//        class Position { double x = 0, y = 0; }
//        -->
//      It is added to every prelude-using snippet on that page.
//    - A snippet with statements at the top level (no `main`) is analyzed
//      inside a function body.
//    - ```dart fragment blocks are skipped: use them for partial code
//      (`...`, a lone method). Every other block must analyze cleanly.
// 2. Every `fledge_*: ^X.Y.Z` constraint in the docs and the package
//    READMEs must match the current workspace version.
//
// --keep leaves build/doc_snippets/ in place for inspection.
// --only=ecs,app/codegen checks only pages whose path (under assets/docs)
// starts with one of the prefixes, in its own build directory.

import 'dart:convert';
import 'dart:io';

const _ignores =
    '// ignore_for_file: unused_import, unused_local_variable, '
    'unused_element, unused_field, dead_code, unused_catch_clause, '
    'unused_shown_name, avoid_print, unnecessary_import, '
    'unreachable_from_main, depend_on_referenced_packages';

const _prelude = '''
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_audio/fledge_audio.dart';
import 'package:fledge_calendar/fledge_calendar.dart';
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_particles/fledge_particles.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_save/fledge_save.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:fledge_tween/fledge_tween.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:fledge_window/fledge_window.dart';
import 'package:fledge_yarn/fledge_yarn.dart';
''';

final _docsDir = Directory('assets/docs');
Directory _outDir = Directory('build/doc_snippets');

/// Page path prefixes to check (`--only=ecs,scheduling`); empty for all.
List<String> _only = const [];

class Snippet {
  final String page; // e.g. ecs/queries.md
  final int line; // 1-based line of the opening fence
  final String? tab;
  final String code;
  final String setup;
  Snippet(this.page, this.line, this.tab, this.code, this.setup);

  String get label => '$page:$line${tab == null ? '' : ' [$tab]'}';

  bool get hasImports =>
      RegExp(r'^\s*import\s', multiLine: true).hasMatch(code);

  String render({required bool wrap}) {
    final buffer = StringBuffer()
      ..writeln(_ignores)
      ..writeln('// Snippet from $label');
    if (hasImports) {
      buffer.writeln(code);
      return buffer.toString();
    }
    buffer
      ..writeln(_prelude)
      ..writeln(setup);
    if (wrap) {
      buffer
        ..writeln('Future<void> \$snippet() async {')
        ..writeln(code)
        ..writeln('}');
    } else {
      buffer.writeln(code);
    }
    return buffer.toString();
  }
}

Future<void> main(List<String> args) async {
  if (!_docsDir.existsSync()) {
    stderr.writeln('Run from the docs/ directory.');
    exit(2);
  }
  final keep = args.contains('--keep');
  for (final arg in args) {
    if (arg.startsWith('--only=')) {
      _only = arg.substring('--only='.length).split(',');
      // A separate directory per selection, so checks can run side by side.
      _outDir = Directory('build/doc_snippets_${_only.join('_')}');
    }
  }
  var failed = false;

  failed |= !_checkVersions();
  if (_only.isNotEmpty) {
    stdout.writeln('Checking pages under: ${_only.join(', ')}');
  }

  final snippets = _collect();
  stdout.writeln('Analyzing ${snippets.length} snippets...');
  if (_outDir.existsSync()) _outDir.deleteSync(recursive: true);
  _outDir.createSync(recursive: true);

  // Pass 1: every snippet as a compilation unit.
  final files = <String, Snippet>{};
  for (final (i, snippet) in snippets.indexed) {
    final name = '${snippet.page.replaceAll(RegExp(r'[/.-]'), '_')}_$i.dart';
    File('${_outDir.path}/$name')
        .writeAsStringSync(snippet.render(wrap: false));
    files[name] = snippet;
  }
  var issues = await _analyze();

  // Pass 2: snippets with syntax errors (top-level statements) go inside a
  // function body.
  final rewrapped = <String>{
    for (final issue in issues)
      if (issue.isSyntax && !files[issue.file]!.hasImports) issue.file,
  };
  if (rewrapped.isNotEmpty) {
    for (final name in rewrapped) {
      File('${_outDir.path}/$name')
          .writeAsStringSync(files[name]!.render(wrap: true));
    }
    final second = await _analyze();
    issues = [
      for (final issue in issues)
        if (!rewrapped.contains(issue.file)) issue,
      for (final issue in second)
        if (rewrapped.contains(issue.file)) issue,
    ];
  }

  final serious = issues.where((i) => i.severity != 'INFO').toList();
  final byFile = <String, List<_Issue>>{};
  for (final issue in serious) {
    (byFile[issue.file] ??= []).add(issue);
  }
  for (final MapEntry(key: name, value: list) in byFile.entries) {
    final snippet = files[name]!;
    stdout.writeln('\n${snippet.label}  (build/doc_snippets/$name)');
    for (final issue in list) {
      stdout.writeln(
        '  ${issue.severity.toLowerCase()}: ${issue.message} [${issue.code}]',
      );
    }
  }
  if (serious.isNotEmpty) {
    failed = true;
    stdout.writeln(
      '\n${byFile.length} of ${snippets.length} snippets have errors or '
      'warnings. Fix them, or mark partial code as ```dart fragment.',
    );
  } else {
    stdout.writeln('All ${snippets.length} snippets analyze cleanly.');
  }

  if (!keep && !failed) _outDir.deleteSync(recursive: true);
  exit(failed ? 1 : 0);
}

List<Snippet> _collect() {
  final snippets = <Snippet>[];
  final pages =
      _docsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final fence = RegExp(r'^```(\S*)(?:\s+(\S+))?\s*$');
  for (final file in pages) {
    final page = file.path
        .replaceAll(r'\', '/')
        .substring('${_docsDir.path}/'.length);
    if (_only.isNotEmpty && !_only.any(page.startsWith)) continue;
    final text = file.readAsStringSync();
    final setup = RegExp(r'<!--\s*snippet-setup\s*\n([\s\S]*?)-->')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .join('\n');
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final open = fence.firstMatch(lines[i]);
      if (open == null || open.group(1)!.isEmpty) continue;
      final lang = open.group(1)!;
      final modifier = open.group(2);
      final start = i;
      final body = <String>[];
      for (i++; i < lines.length && !lines[i].startsWith('```'); i++) {
        body.add(lines[i]);
      }
      if (modifier == 'fragment') continue;
      if (lang == 'dart') {
        snippets.add(Snippet(page, start + 1, null, body.join('\n'), setup));
      } else if (lang == 'dart-tabs') {
        String? tab;
        var tabLines = <String>[];
        void flush() {
          if (tab != null) {
            snippets.add(
              Snippet(page, start + 1, tab, tabLines.join('\n'), setup),
            );
          }
        }

        for (final line in body) {
          final m = RegExp(r'^//\s*@tab\s+(.+)$').firstMatch(line.trim());
          if (m != null) {
            flush();
            tab = m.group(1)!.trim();
            tabLines = [];
          } else {
            tabLines.add(line);
          }
        }
        flush();
      }
    }
  }
  return snippets;
}

class _Issue {
  final String file;
  final String severity;
  final String type;
  final String code;
  final String message;
  _Issue(this.file, this.severity, this.type, this.code, this.message);
  bool get isSyntax => type == 'SYNTACTIC_ERROR';
}

/// Analyzes every file in build/doc_snippets. The analyzer occasionally
/// crashes on malformed code; when it does, the files are analyzed in
/// smaller groups (by page, then one at a time) so one bad snippet is
/// reported as an error instead of hiding the rest.
Future<List<_Issue>> _analyze() async {
  final all = _outDir.listSync().whereType<File>().map((f) => f.path).toList()
    ..sort();
  final whole = await _analyzePaths([_outDir.path]);
  if (whole != null) return whole;

  final byPage = <String, List<String>>{};
  for (final path in all) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final page = name.substring(0, name.lastIndexOf('_'));
    (byPage[page] ??= []).add(path);
  }
  final issues = <_Issue>[];
  for (final paths in byPage.values) {
    final batch = await _analyzePaths(paths);
    if (batch != null) {
      issues.addAll(batch);
      continue;
    }
    for (final path in paths) {
      final single = await _analyzePaths([path]);
      final name = path.split(RegExp(r'[/\\]')).last;
      issues.addAll(
        single ??
            [
              _Issue(
                name,
                'ERROR',
                'ANALYZER_CRASH',
                'analyzer_crash',
                'the analyzer crashed on this snippet; it is probably '
                    'malformed (statements before declarations?)',
              ),
            ],
      );
    }
  }
  return issues;
}

/// Runs `dart analyze` on [paths]; null if the analyzer crashed.
Future<List<_Issue>?> _analyzePaths(List<String> paths) async {
  final result = await Process.run('dart', [
    'analyze',
    '--format=json',
    ...paths,
  ], runInShell: Platform.isWindows);
  final out = (result.stdout as String).trim();
  final start = out.indexOf('{"version"');
  if (start == -1) {
    if (result.exitCode == 0 && !out.contains('crashed')) return const [];
    return null;
  }
  final json = jsonDecode(out.substring(start)) as Map<String, dynamic>;
  return [
    for (final d in (json['diagnostics'] as List).cast<Map<String, dynamic>>())
      _Issue(
        (d['location']['file'] as String).split(RegExp(r'[/\\]')).last,
        d['severity'] as String,
        d['type'] as String,
        d['code'] as String,
        d['problemMessage'] as String,
      ),
  ];
}

/// Checks `fledge_*: ^X.Y.Z` pins in the docs and READMEs.
bool _checkVersions() {
  final pubspec = File('../packages/fledge_ecs/pubspec.yaml')
      .readAsStringSync();
  final version = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec)!.group(1)!;
  final expected = '^$version';
  final pin = RegExp(r'\b(fledge_\w+):\s*(\^?\d+\.\d+\.\d+\S*)');
  final files = [
    ..._docsDir.listSync(recursive: true).whereType<File>().where((f) {
      if (!f.path.endsWith('.md')) return false;
      final page = f.path
          .replaceAll(r'\', '/')
          .substring('${_docsDir.path}/'.length);
      return _only.isEmpty || _only.any(page.startsWith);
    }),
    File('../README.md'),
    ...Directory('../packages')
        .listSync()
        .whereType<Directory>()
        .map((d) => File('${d.path}/README.md'))
        .where((f) => f.existsSync()),
  ];
  var ok = true;
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (final (i, line) in lines.indexed) {
      for (final m in pin.allMatches(line)) {
        if (m.group(2) != expected) {
          ok = false;
          stdout.writeln(
            '${file.path}:${i + 1}: ${m.group(1)}: ${m.group(2)} '
            '(expected $expected)',
          );
        }
      }
    }
  }
  if (!ok) {
    stdout.writeln(
      'Version pins must match the workspace version ($expected); '
      'scripts/release.dart rewrites them on release.\n',
    );
  }
  return ok;
}
