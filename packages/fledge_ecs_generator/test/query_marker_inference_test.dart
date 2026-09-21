// Verifies the generator's Query / QueryMut read/write inference by reading
// the generated `.g.dart` for a set of fixtures.
//
// # Where the fixtures live
//
// The fixture `@system` functions live in
// `examples/basic_ecs/lib/query_marker_fixtures.dart`, and their generated
// output at `examples/basic_ecs/lib/query_marker_fixtures.g.dart`.
//
// The fixture cannot live in this package because `fledge_ecs_generator`
// intentionally does not depend on `fledge_ecs` (see package CLAUDE.md), which
// means it cannot reference the real `Query1`/`QueryMut1` types. `basic_ecs`
// is already wired into the workspace's build_runner pipeline and does depend
// on `fledge_ecs`, so we piggy-back on its regeneration.
//
// # Prerequisite
//
// The generated `.g.dart` must be up to date. In CI this is guaranteed by
// `melos run build_runner` running before `melos run test`. Locally, run
// `melos run build_runner` (or `cd examples/basic_ecs &&
// dart run build_runner build --delete-conflicting-outputs`) before running
// these tests.
//
// # Why not build_test?
//
// The `build_test` package can't run under `flutter test` in this workspace
// (Flutter's test isolate does not expose `Isolate.packageConfigSync`, which
// `build_runner`'s resolver + SDK-summary paths reach for), and `dart test`
// is blocked by the workspace-level `test_api` override needed for
// `flutter_test` compatibility. Reading a real regenerated fixture is the
// robust workaround.

import 'dart:io';

import 'package:test/test.dart';

/// Resolves the absolute path of the fixture's generated output by walking up
/// from the current test's CWD until we find the workspace root.
File _fixtureFile() {
  var dir = Directory.current;
  while (true) {
    final candidate = File(
      '${dir.path}/examples/basic_ecs/lib/query_marker_fixtures.g.dart',
    );
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not locate examples/basic_ecs/lib/query_marker_fixtures.g.dart '
        'walking up from ${Directory.current.path}. Run '
        '`melos run build_runner` to regenerate it.',
      );
    }
    dir = parent;
  }
}

/// Extract the body of the top-level class named [className] from [content],
/// starting at `class $className` and ending at the matching `}`.
///
/// A simple brace counter is enough here because the generator's output only
/// uses balanced braces and never string-embeds a `{` or `}`.
String _classBody(String content, String className) {
  final start = content.indexOf('class $className ');
  if (start == -1) {
    throw StateError(
      'Fixture is missing generated class $className. Regenerate with '
      '`melos run build_runner`.\n\nFull contents:\n$content',
    );
  }
  final braceStart = content.indexOf('{', start);
  var depth = 0;
  for (var i = braceStart; i < content.length; i++) {
    final ch = content[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return content.substring(start, i + 1);
    }
  }
  throw StateError('Unbalanced braces for class $className');
}

void main() {
  final content = _fixtureFile().readAsStringSync();

  group('SystemGenerator query intent inference', () {
    test('Query1<A> generates reads: {A} and no writes', () {
      final body = _classBody(content, 'ReadOnePositionsWrapper');
      expect(body, contains('reads: {ComponentId.of<Position>()}'));
      expect(body, isNot(contains('writes:')));
      expect(body, contains('final q = world.query1<Position>();'));
    });

    test('Query2<A, B> generates reads: {A, B} and no writes', () {
      final body = _classBody(content, 'ReadPositionsAndVelocitiesWrapper');
      expect(
        body,
        contains(
          'reads: {ComponentId.of<Position>(), ComponentId.of<Velocity>()}',
        ),
      );
      expect(body, isNot(contains('writes:')));
      expect(body, contains('final q = world.query2<Position, Velocity>();'));
    });

    test('QueryMut2<A, B> generates writes: {A, B} and no reads', () {
      final body = _classBody(content, 'WritePositionsAndVelocitiesWrapper');
      expect(
        body,
        contains(
          'writes: {ComponentId.of<Position>(), ComponentId.of<Velocity>()}',
        ),
      );
      expect(body, isNot(contains('reads:')));
      expect(
        body,
        contains('final q = world.queryMut2<Position, Velocity>();'),
      );
    });

    test('Query1<A> + QueryMut1<B> produces reads: {A} and writes: {B}', () {
      final body = _classBody(content, 'ReadPositionsWriteVelocitiesWrapper');
      expect(body, contains('reads: {ComponentId.of<Position>()}'));
      expect(body, contains('writes: {ComponentId.of<Velocity>()}'));
      expect(body, contains('final r = world.query1<Position>();'));
      expect(body, contains('final w = world.queryMut1<Velocity>();'));
    });
  });
}
