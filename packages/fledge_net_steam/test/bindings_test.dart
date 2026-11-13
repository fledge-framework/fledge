import 'dart:ffi';
import 'dart:io';

import 'package:fledge_net_steam/src/bindings.dart';
import 'package:test/test.dart';

/// Checks every function this package binds exists in the real Steamworks
/// library, without initialising Steam. Runs when `STEAMWORKS_SDK` points
/// at an extracted Steamworks SDK (the folder holding `sdk/`); skipped
/// otherwise (CI has no SDK).
void main() {
  final sdk = Platform.environment['STEAMWORKS_SDK'];
  final library = sdk == null ? null : _libraryIn(sdk);

  test(
    'every bound Steamworks function exists in the SDK library',
    () {
      final bindings = SteamBindings(DynamicLibrary.open(library!));
      expect(bindings.initFlat, isNotNull);
      expect(bindings.messagesSend, isNotNull);
    },
    skip: library == null
        ? 'Set STEAMWORKS_SDK to an extracted Steamworks SDK to run'
        : null,
  );
}

String? _libraryIn(String sdk) {
  final bin = '$sdk/sdk/redistributable_bin';
  final path = switch (Platform.operatingSystem) {
    'windows' => '$bin/win64/steam_api64.dll',
    'macos' => '$bin/osx/libsteam_api.dylib',
    _ => '$bin/linux64/libsteam_api.so',
  };
  return File(path).existsSync() ? path : null;
}
