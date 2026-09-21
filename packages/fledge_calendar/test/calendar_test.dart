import 'package:fledge_calendar/fledge_calendar.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

/// Drives a [Calendar] through [CalendarSystem] one frame at a time and
/// collects the events each frame produced.
class _Harness {
  final World world = World();
  final Calendar calendar;
  final WallTime time = WallTime();

  _Harness(this.calendar) {
    world
      ..insertResource(time)
      ..insertResource(calendar)
      ..registerEvent<HourChangedEvent>()
      ..registerEvent<DayChangedEvent>()
      ..registerEvent<SeasonChangedEvent>()
      ..registerEvent<YearChangedEvent>()
      ..registerEvent<CurfewTriggeredEvent>();
  }

  /// Run one frame with [delta] real seconds; returns that frame's events.
  Future<List<Object>> frame([double delta = 0]) async {
    time.delta = delta;
    await const CalendarSystem().run(world);
    world.updateEvents();
    return [
      ...world.eventReader<HourChangedEvent>().read(),
      ...world.eventReader<DayChangedEvent>().read(),
      ...world.eventReader<SeasonChangedEvent>().read(),
      ...world.eventReader<YearChangedEvent>().read(),
      ...world.eventReader<CurfewTriggeredEvent>().read(),
    ];
  }
}

/// One real second per game minute, so 60.0 seconds = one game hour.
const _hour = 60.0;

CalendarConfig _config({int? curfew}) =>
    CalendarConfig(realSecondsPerGameMinute: 1.0, defaultCurfewHour: curfew);

void main() {
  group('skipToNextMorning', () {
    test('22:00 on day 5 skips to 06:00 on day 6', () {
      final calendar = Calendar(config: _config(), day: 5, hour: 22);
      calendar.skipToNextMorning();
      expect(calendar.day, 6);
      expect(calendar.hour, 6);
      expect(calendar.minute, 0);
      expect(calendar.dayChangedThisFrame, isTrue);
      expect(calendar.hourChangedThisFrame, isTrue);
    });

    test(
      'passing out at 2 AM curfew wakes on the day the clock rolled into',
      () async {
        final h = _Harness(
          Calendar(config: _config(curfew: 26), day: 5, hour: 20),
        );

        var dayEvents = 0;
        var curfewEvents = 0;
        // 20:00 -> 02:00, one game hour per frame.
        for (var i = 0; i < 6; i++) {
          final events = await h.frame(_hour);
          dayEvents += events.whereType<DayChangedEvent>().length;
          curfewEvents += events.whereType<CurfewTriggeredEvent>().length;
        }
        expect(h.calendar.hour, 2);
        expect(h.calendar.day, 6);
        expect(curfewEvents, 1);
        expect(dayEvents, 1);

        h.calendar.skipToNextMorning();
        expect(h.calendar.day, 6, reason: 'no extra day after midnight');
        expect(h.calendar.hour, 6);

        final next = await h.frame();
        expect(next.whereType<DayChangedEvent>(), isEmpty);
        expect(next.whereType<HourChangedEvent>().single.oldHour, 2);
        expect(next.whereType<HourChangedEvent>().single.newHour, 6);
      },
    );

    test('at exactly dayStartHour it advances a full day', () {
      final calendar = Calendar(config: _config(), day: 3, hour: 6);
      calendar.skipToNextMorning();
      expect(calendar.day, 4);
      expect(calendar.hour, 6);
      expect(calendar.hourChangedThisFrame, isFalse);
      expect(calendar.dayChangedThisFrame, isTrue);
    });
  });

  group('curfew', () {
    test('curfew before midnight does not re-trigger after midnight', () async {
      final h = _Harness(
        Calendar(config: _config(curfew: 22), day: 1, hour: 21),
      );

      final triggers = <CurfewTriggeredEvent>[];
      // 21:00 -> 05:00 next day.
      for (var i = 0; i < 8; i++) {
        triggers.addAll(
          (await h.frame(_hour)).whereType<CurfewTriggeredEvent>(),
        );
      }
      expect(h.calendar.hour, 5);
      expect(triggers, hasLength(1));
      expect(triggers.single.hour, 22);

      // It re-arms at dayStartHour and fires again at 22:00 the next evening.
      for (var i = 0; i < 17; i++) {
        triggers.addAll(
          (await h.frame(_hour)).whereType<CurfewTriggeredEvent>(),
        );
      }
      expect(h.calendar.hour, 22);
      expect(triggers, hasLength(2));
    });

    test('isPastCurfew stays true after midnight for a 22:00 curfew', () {
      final calendar = Calendar(config: _config(curfew: 22), hour: 23);
      calendar.update(_hour);
      expect(calendar.hour, 0);
      expect(calendar.isPastCurfew, isTrue);
      expect(calendar.curfewTriggeredThisFrame, isFalse);
    });

    test(
      'skipToHour past curfew emits a pending CurfewTriggeredEvent',
      () async {
        final h = _Harness(
          Calendar(config: _config(curfew: 22), day: 1, hour: 12),
        );
        h.calendar.skipToHour(23);

        final events = await h.frame();
        expect(events.whereType<CurfewTriggeredEvent>().single.hour, 23);
        expect(await h.frame(), isEmpty);
      },
    );

    test(
      'skipToHour across midnight within the same night does not re-trigger',
      () async {
        final h = _Harness(
          Calendar(config: _config(curfew: 22), day: 1, hour: 23),
        );
        await h.frame(); // settle
        h.calendar.skipToHour(1);
        expect(h.calendar.day, 2);
        final events = await h.frame();
        expect(events.whereType<CurfewTriggeredEvent>(), isEmpty);
      },
    );
  });

  group('events for out-of-system changes', () {
    test(
      'skip yields exactly one Day + Hour event next frame, none after',
      () async {
        final h = _Harness(Calendar(config: _config(), day: 5, hour: 22));
        await h.frame();

        // As if called from Schedules.update, after CalendarSystem ran.
        h.calendar.skipToNextMorning();

        final events = await h.frame();
        final day = events.whereType<DayChangedEvent>().single;
        final hour = events.whereType<HourChangedEvent>().single;
        expect(events, hasLength(2));
        expect((day.oldDay, day.newDay, day.dayOfWeek), (5, 6, 5));
        expect((hour.oldHour, hour.newHour), (22, 6));

        expect(await h.frame(), isEmpty);
      },
    );

    test('flags are cleared by beginFrame but pending changes are not', () {
      final calendar = Calendar(config: _config(), day: 5, hour: 22);
      calendar.skipToNextMorning();
      calendar.beginFrame();
      expect(calendar.dayChangedThisFrame, isFalse);

      final pending = calendar.takePendingChanges();
      expect(pending, isNotNull);
      expect(pending!.oldDay, 5);
      expect(pending.oldHour, 22);
      expect(calendar.takePendingChanges(), isNull);
    });

    test('two skips before the next frame coalesce', () async {
      final h = _Harness(Calendar(config: _config(), day: 5, hour: 22));
      await h.frame();

      h.calendar.skipToNextMorning(); // day 6, 06:00
      h.calendar.skipToNextMorning(); // day 7, 06:00

      final events = await h.frame();
      final day = events.whereType<DayChangedEvent>().single;
      final hour = events.whereType<HourChangedEvent>().single;
      expect((day.oldDay, day.newDay), (5, 7));
      expect((hour.oldHour, hour.newHour), (22, 6));
      expect(await h.frame(), isEmpty);
    });

    test('setTime records pending changes', () async {
      final h = _Harness(Calendar(config: _config(), day: 1, hour: 8));
      await h.frame();

      h.calendar.setTime(newDay: 3, newHour: 14);

      final events = await h.frame();
      final day = events.whereType<DayChangedEvent>().single;
      final hour = events.whereType<HourChangedEvent>().single;
      expect((day.oldDay, day.newDay), (1, 3));
      expect((hour.oldHour, hour.newHour), (8, 14));
    });

    test(
      'pending and in-frame changes are emitted as separate events',
      () async {
        final h = _Harness(Calendar(config: _config(), day: 5, hour: 22));
        h.calendar.skipToNextMorning(); // 22:00 -> 06:00 day 6

        final hours = (await h.frame(
          _hour,
        )).whereType<HourChangedEvent>().toList();
        expect(hours.map((e) => (e.oldHour, e.newHour)), [(22, 6), (6, 7)]);
      },
    );

    test('loadFromJson clears pending changes', () async {
      final h = _Harness(Calendar(config: _config(), day: 5, hour: 22));
      h.calendar.skipToNextMorning();
      h.calendar.loadFromJson({'day': 9, 'hour': 10, 'minute': 0});

      expect(h.calendar.takePendingChanges(), isNull);
      expect(await h.frame(), isEmpty);
    });

    test(
      'season boundary crossed by a skip emits SeasonChangedEvent',
      () async {
        // Default 28-day seasons: day 28 is the last day of season 0.
        final h = _Harness(Calendar(config: _config(), day: 28, hour: 22));
        await h.frame();

        h.calendar.skipToNextMorning();

        final events = await h.frame();
        final season = events.whereType<SeasonChangedEvent>().single;
        expect((season.oldSeason, season.newSeason), (0, 1));
        expect(events.whereType<YearChangedEvent>(), isEmpty);
        expect(await h.frame(), isEmpty);
      },
    );

    test('year boundary crossed by a skip emits YearChangedEvent', () async {
      // 4 x 28 = 112 days per year.
      final h = _Harness(Calendar(config: _config(), day: 112, hour: 22));
      await h.frame();

      h.calendar.skipToNextMorning();

      final events = await h.frame();
      final season = events.whereType<SeasonChangedEvent>().single;
      final year = events.whereType<YearChangedEvent>().single;
      expect((season.oldSeason, season.newSeason), (3, 0));
      expect((year.oldYear, year.newYear), (1, 2));
    });
  });

  group('in-system rollover (unchanged)', () {
    test('midnight emits Day + Hour events in the same frame', () async {
      final h = _Harness(Calendar(config: _config(), day: 1, hour: 23));

      final events = await h.frame(_hour);
      final day = events.whereType<DayChangedEvent>().single;
      final hour = events.whereType<HourChangedEvent>().single;
      expect((day.oldDay, day.newDay, day.dayOfWeek), (1, 2, 1));
      expect((hour.oldHour, hour.newHour), (23, 0));
      expect(events, hasLength(2));

      expect(await h.frame(), isEmpty);
    });

    test('season rollover at midnight emits SeasonChangedEvent', () async {
      final h = _Harness(Calendar(config: _config(), day: 28, hour: 23));
      final events = await h.frame(_hour);
      final season = events.whereType<SeasonChangedEvent>().single;
      expect((season.oldSeason, season.newSeason), (0, 1));
    });
  });
}
