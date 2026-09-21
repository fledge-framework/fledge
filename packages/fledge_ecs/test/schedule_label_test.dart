import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

void main() {
  group('Schedule', () {
    test('equality is name-based', () {
      expect(const Schedule('x'), equals(const Schedule('x')));
      expect(
          const Schedule('x').hashCode, equals(const Schedule('x').hashCode));
      expect(const Schedule('x'), isNot(equals(const Schedule('y'))));
    });

    test('toString includes name', () {
      expect(const Schedule('foo').toString(), contains('foo'));
    });
  });

  group('Schedules', () {
    test(
        'per-frame constants keep the CoreStage.name strings for '
        'backwards compatibility', () {
      expect(Schedules.first.name, equals(CoreStage.first.name));
      expect(Schedules.preUpdate.name, equals(CoreStage.preUpdate.name));
      expect(Schedules.update.name, equals(CoreStage.update.name));
      expect(Schedules.postUpdate.name, equals(CoreStage.postUpdate.name));
      expect(Schedules.last.name, equals(CoreStage.last.name));
    });

    test('reserved schedule names are stable identifiers', () {
      expect(Schedules.startup.name, equals('startup'));
      expect(Schedules.fixedFirst.name, equals('fixedFirst'));
      expect(Schedules.fixedPreUpdate.name, equals('fixedPreUpdate'));
      expect(Schedules.fixedUpdate.name, equals('fixedUpdate'));
      expect(Schedules.fixedPostUpdate.name, equals('fixedPostUpdate'));
      expect(Schedules.fixedLast.name, equals('fixedLast'));
      expect(Schedules.extract.name, equals('extract'));
      expect(Schedules.render.name, equals('render'));
    });

    test('all lists every Schedule constant', () {
      expect(
        Schedules.all,
        containsAll(<Schedule>[
          Schedules.startup,
          Schedules.first,
          Schedules.preUpdate,
          Schedules.update,
          Schedules.postUpdate,
          Schedules.last,
          Schedules.fixedFirst,
          Schedules.fixedPreUpdate,
          Schedules.fixedUpdate,
          Schedules.fixedPostUpdate,
          Schedules.fixedLast,
          Schedules.extract,
          Schedules.render,
        ]),
      );
    });
  });

  group('Scheduler.addSchedule', () {
    test('registering the same custom Schedule twice is idempotent', () {
      final scheduler = Scheduler();
      final before = scheduler.stageCount;
      scheduler.addSchedule(const Schedule('custom_foo'));
      scheduler.addSchedule(const Schedule('custom_foo'));
      expect(scheduler.stageCount, equals(before + 1));
    });

    test('addSchedule registers a new schedule when unknown', () {
      final scheduler = Scheduler();
      expect(scheduler.getStage('brand_new'), isNull);
      scheduler.addSchedule(const Schedule('brand_new'));
      expect(scheduler.getStage('brand_new'), isNotNull);
    });
  });
}
