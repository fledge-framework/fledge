import 'dart:io';

import 'package:fledge_save/fledge_save.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('prefs_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  PreferencesFile prefs() =>
      PreferencesFile(gameDirectory: 'Game', baseDirectory: dir.path);

  test('nothing stored reads as null', () async {
    expect(await prefs().read(), isNull);
  });

  test('a write reads back, and replaces the last one', () async {
    expect(
      await prefs().write({
        'music': 0.6,
        'keys': ['e'],
      }),
      isTrue,
    );
    expect(await prefs().read(), {
      'music': 0.6,
      'keys': ['e'],
    });
    await prefs().write({'music': 0.2});
    expect(await prefs().read(), {'music': 0.2});
    expect(File('${dir.path}/Game/settings.json.tmp').existsSync(), isFalse);
  });

  test('a broken file reads as null', () async {
    File('${dir.path}/Game/settings.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{not json');
    expect(await prefs().read(), isNull);
  });
}
