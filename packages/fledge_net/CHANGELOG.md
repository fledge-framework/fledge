# Changelog

## [0.2.1] - 2026-09-20

### Added

- `example/example.dart` demonstrating the package's core API (pana requirement).

### Changed

- SDK floor bumped to Dart `>=3.11.0` (was 3.6). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Changed

- **BREAKING**: `Transform2DNetworkState` (12-byte wire) replaces `TransformNetworkState` (3D quaternion form).
- Protocol version bumped from 1 to 2; clients with mismatched protocol are cleanly rejected.
- Prediction guide now points at `Schedules.fixedUpdate`.

### Preserved

- Crypto, congestion control, and interest management are unchanged.


## [0.1.14] - 2026-04-14

## [0.1.13] - 2026-04-14

## [0.1.13] - 2026-04-14

### Features

- **fledge_net:** Remediate documented limitations

### Miscellaneous

- Add missing files for fledge_net



## [0.1.12] - 2026-04-14

