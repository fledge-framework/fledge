// Cuts a coordinated Fledge release. Cross-platform (Windows, macOS, Linux).
//
//   dart run scripts/release.dart 0.4.0
//   dart run scripts/release.dart 0.4.0 --dry-run
//
// `melos run release` also works, reading the version from the VERSION
// environment variable (bash: `VERSION=0.4.0 melos run release`,
// PowerShell: `$env:VERSION='0.4.0'; melos run release`). Set
// RELEASE_DRY_RUN=1 for a dry run through melos.
//
// Bumps every packages/fledge_* package (and in-workspace constraints) to
// the version, writes per-package and workspace CHANGELOG entries, and
// creates the `chore(release): vX.Y.Z` commit that ci.yml's `tag-release`
// job matches. Does not push — review, then `git push origin main`.
//
// Melos has no "set the whole workspace to X.Y.Z" flag, so this passes one
// `-V <pkg>:<ver>` per package to a single `melos version` call. Its
// `--message` only interpolates `{new_package_versions}`, so the commit is
// created here with the version in the subject.
import 'dart:io';

final _semver = RegExp(r'^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$');

Future<void> main(List<String> args) async {
  final dryRun =
      args.contains('--dry-run') ||
      Platform.environment['RELEASE_DRY_RUN'] == '1';
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final version = positional.isNotEmpty
      ? positional.first
      : (Platform.environment['VERSION'] ?? '');

  if (!_semver.hasMatch(version)) {
    _fail(
      version.isEmpty
          ? 'No version given. Usage: dart run scripts/release.dart 0.4.0'
          : '"$version" is not a semantic version (e.g. 0.4.0).',
    );
  }

  final root = File(Platform.script.toFilePath()).parent.parent;
  Directory.current = root;

  // The release commit stages everything (`git add -A`), so anything
  // already modified would be swept into it.
  final status = await _capture('git', ['status', '--porcelain']);
  if (status.trim().isNotEmpty) {
    const message = 'Working tree is not clean. Commit or stash first:';
    if (!dryRun) _fail('$message\n$status');
    stderr.writeln('Warning (dry run continues): $message\n$status');
  }
  final branch = (await _capture('git', [
    'rev-parse',
    '--abbrev-ref',
    'HEAD',
  ])).trim();
  if (branch != 'main') {
    stderr.writeln(
      'Warning: on branch "$branch". CI only tags releases pushed to main.',
    );
  }

  final names = <String>[];
  for (final dir in Directory('packages').listSync().whereType<Directory>()) {
    final dirName = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (!dirName.startsWith('fledge_') || !pubspec.existsSync()) continue;
    final match = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    if (match != null) names.add(match.group(1)!);
  }
  names.sort();
  if (names.isEmpty) _fail('No packages/fledge_* packages found.');

  final melosArgs = [
    'version',
    for (final name in names) ...['-V', '$name:$version'],
    '--yes',
    '--no-git-commit-version',
  ];
  final commitMessage = 'chore(release): v$version';

  stdout.writeln('Releasing ${names.length} packages at $version.');
  if (dryRun) {
    stdout
      ..writeln('[dry run] melos ${melosArgs.join(' ')}')
      ..writeln('[dry run] git add -A')
      ..writeln('[dry run] git commit -m "$commitMessage"');
    return;
  }

  await _run('melos', melosArgs);
  await _run('git', ['add', '-A']);
  await _run('git', ['commit', '-m', commitMessage]);
  stdout.writeln(
    'Created "$commitMessage". Review it, then `git push origin main`.',
  );
}

Future<void> _run(String executable, List<String> args) async {
  // runInShell resolves .bat/.cmd shims (melos.bat) on Windows.
  final process = await Process.start(
    executable,
    args,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) _fail('`$executable ${args.first}` failed (exit $code).');
}

Future<String> _capture(String executable, List<String> args) async {
  final result = await Process.run(
    executable,
    args,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    _fail('`$executable ${args.join(' ')}` failed:\n${result.stderr}');
  }
  return result.stdout as String;
}

Never _fail(String message) {
  stderr.writeln('release: $message');
  exit(1);
}
