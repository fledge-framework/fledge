## 0.2.3

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): remediate documented limitations. ([203a78a6](https://github.com/fledge-framework/fledge/commit/203a78a6093897de435f9cf4528e3afcfab6073f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))

# Changelog

## [0.2.2] - 2026-09-21



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

