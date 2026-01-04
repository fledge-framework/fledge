# Changelog

## [0.1.3] - 2026-01-04

## [Unreleased]

### Bug Fixes

- **fledge_render_2d:** Fix null safety error on private field



## [0.1.2] - 2026-01-03

## [0.1.2] - 2026-01-03

### Bug Fixes

- Update dependencies to latest stable versions
- **fledge:** Update dependencies, upgrade melos to v7

### Miscellaneous

- **license:** Remove whitespace from license files
- Update license text

### Ci

- **github:** Create changelogs for all packages on release



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_window
- Window modes: fullscreen, borderless, and windowed
- Runtime mode switching with toggleFullscreen, setWindowMode, cycleWindowMode
- WindowState resource for querying current window state
- DisplayInfo resource for monitor information
- WindowModeChanged event
- WindowResized event
- WindowFocusChanged event
- World extension methods for window control
