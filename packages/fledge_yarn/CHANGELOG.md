## 0.3.1

> Note: This release has breaking changes.

 - **FIX**(fledge_yarn): jump to a missing node no longer leaves the previous line up. ([33a6ac05](https://github.com/fledge-framework/fledge/commit/33a6ac054cab948839ec306e8a3363dd107e566d))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_yarn): pausing command callbacks. ([8c117ce1](https://github.com/fledge-framework/fledge/commit/8c117ce153f3908816d22c3240c98e75b5a3af2d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_yarn): create fledge_yarn for yarnspinner. ([9bbee221](https://github.com/fledge-framework/fledge/commit/9bbee2213966a290074b265ed60e57198d1047c0))
 - **DOCS**(fledge_yarn): tag grammar. ([6a4895fb](https://github.com/fledge-framework/fledge/commit/6a4895fbe48578d06d35c1afe446ba93f0411966))
 - **BREAKING** **FEAT**(fledge_yarn): event-driven dialogue layer. ([3f4be34d](https://github.com/fledge-framework/fledge/commit/3f4be34d8104c2cc2a56030dfe7012421304900b))

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**(fledge_yarn): jump to a missing node no longer leaves the previous line up. ([33a6ac05](https://github.com/fledge-framework/fledge/commit/33a6ac054cab948839ec306e8a3363dd107e566d))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_yarn): pausing command callbacks. ([8c117ce1](https://github.com/fledge-framework/fledge/commit/8c117ce153f3908816d22c3240c98e75b5a3af2d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_yarn): create fledge_yarn for yarnspinner. ([9bbee221](https://github.com/fledge-framework/fledge/commit/9bbee2213966a290074b265ed60e57198d1047c0))
 - **DOCS**(fledge_yarn): tag grammar. ([6a4895fb](https://github.com/fledge-framework/fledge/commit/6a4895fbe48578d06d35c1afe446ba93f0411966))
 - **BREAKING** **FEAT**(fledge_yarn): event-driven dialogue layer. ([093c026d](https://github.com/fledge-framework/fledge/commit/093c026df4120e9cd7f1a9da173db4baababcb85))

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Changed

- Consumer migration to `WallTime` and `Schedules.*` labels where applicable.


## [0.1.14] - 2026-04-14

## [0.1.13] - 2026-04-14



## [0.1.12] - 2026-04-14



## [0.1.11] - 2026-01-21



## [0.1.10] - 2026-01-06

## [0.1.9] - 2026-01-06



## [0.1.8] - 2026-01-06

## [0.1.8] - 2026-01-06

### Features

- **fledge_yarn:** Create fledge_yarn for yarnspinner

### Miscellaneous

- **lint:** Format all files



## 0.1.7

- Initial release
- Yarn Spinner dialogue parsing
- Variable storage with expression evaluation
- Custom command handler
- DialogueRunner for runtime execution
- YarnPlugin for ECS integration
- Support for conditionals, choices, and jumps
