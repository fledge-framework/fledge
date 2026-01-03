/// Change detection support for tracking component modifications.
///
/// This module provides the core types for change detection:
/// - [Tick] - Global tick counter that advances each frame
/// - [ComponentTicks] - Tracks when components were added/changed
/// - [Added] - Query filter for recently added components (in filter.dart)
/// - [Changed] - Query filter for recently modified components (in filter.dart)
library;

export 'tick.dart';
