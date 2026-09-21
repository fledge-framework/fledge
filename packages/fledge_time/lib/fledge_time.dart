/// This package has been merged into `fledge_calendar`.
///
/// This file re-exports the moved symbols so downstream code that
/// imports `package:fledge_time/fledge_time.dart` continues to compile
/// for one release. Migrate to
/// `package:fledge_calendar/fledge_calendar.dart` — the resource has
/// also been renamed from `GameTime` to `Calendar` and the plugin from
/// `GameTimePlugin` to `CalendarPlugin` (deprecated typedefs keep the
/// old names alive for one release).
@Deprecated(
  'fledge_time was merged into fledge_calendar. Import '
  'package:fledge_calendar/fledge_calendar.dart directly and use '
  'Calendar / CalendarPlugin instead of GameTime / GameTimePlugin.',
)
library;

export 'package:fledge_calendar/fledge_calendar.dart';
