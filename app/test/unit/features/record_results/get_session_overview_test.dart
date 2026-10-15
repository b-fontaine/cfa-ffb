import 'package:billard_cfa/features/record_results/domain/get_session_overview.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late GetSessionOverview overview;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['zoe', 'abel', 'absent']);
    await world.session(present: {'zoe', 'abel'});
    overview = GetSessionOverview(
      world.sessions,
      world.groups,
      world.students,
      world.attempts,
      world.catalogueRepository,
      world.sheets,
      world.acquisitions,
      world.config,
    );
  });

  test('gives the group, the present students sorted by first name', () async {
    final result = ok(await overview(const SessionId('x1')));

    expect(result.session.id, const SessionId('x1'));
    expect(result.groupName, 'Groupe');
    expect(result.students.map((s) => s.firstName), ['abel', 'zoe']);
    expect(result.catalogue, world.catalogue);
    expect(result.maxPassesPerExercise, 2);
    expect(result.passesRequired, 5);
  });

  test('lists the passes of the session in order', () async {
    await world.attempts.add(
      attempt(ref('a', 1), potted: 4, student: 'zoe', id: 'p1'),
    );
    await world.attempts.add(
      attempt(ref('a', 1), potted: 2, student: 'zoe', id: 'p2', passIndex: 2),
    );
    await world.attempts.add(
      attempt(ref('b', 2), potted: 3, student: 'abel', id: 'p3'),
    );
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, student: 'abel', id: 'q', session: 'x2'),
    );

    final result = ok(await overview(const SessionId('x1')));

    expect(result.attempts.map((a) => a.id.value), ['p1', 'p2', 'p3']);
    expect(
      result
          .passesFor(const StudentId('zoe'), ref('a', 1))
          .map((a) => a.id.value),
      ['p1', 'p2'],
    );
    expect(result.passesFor(const StudentId('abel'), ref('a', 1)), isEmpty);
  });

  test('counts the passed passes of a student across sessions', () async {
    final rate = world.catalogue.exercise(ref('a', 1))!.rate;
    await world.attempts.add(
      attempt(
        ref('a', 1),
        potted: rate.attempts,
        student: 'zoe',
        id: 'old',
        session: 'x0',
      ),
    );
    await world.attempts.add(
      attempt(
        ref('a', 1),
        potted: 0,
        student: 'zoe',
        id: 'miss',
        session: 'x0',
        passIndex: 2,
      ),
    );
    await world.attempts.add(
      attempt(ref('a', 1), potted: rate.attempts, student: 'zoe', id: 'p1'),
    );
    await world.attempts.add(
      attempt(ref('a', 1), potted: rate.attempts, student: 'absent', id: 'z'),
    );

    final result = ok(await overview(const SessionId('x1')));

    expect(result.passedCount(const StudentId('zoe'), ref('a', 1)), 2);
    expect(result.passedCount(const StudentId('abel'), ref('a', 1)), 0);
  });

  test('counts a pass reached exactly at the rate, not one below it', () async {
    final rate = world.catalogue.exercise(ref('a', 1))!.rate;
    await world.attempts.add(
      attempt(
        ref('a', 1),
        potted: rate.successes - 1,
        student: 'zoe',
        id: 'b1',
      ),
    );
    await world.attempts.add(
      attempt(
        ref('a', 1),
        potted: rate.successes,
        student: 'zoe',
        id: 'b2',
        passIndex: 2,
      ),
    );

    final result = ok(await overview(const SessionId('x1')));

    expect(result.passedCount(const StudentId('zoe'), ref('a', 1)), 1);
    expect(result.passedCount(const StudentId('abel'), ref('a', 1)), 0);
    expect(result.passedCount(const StudentId('zoe'), ref('b', 2)), 0);
  });

  group('an exercise acquired at placement (ADR 0008)', () {
    const zoe = StudentId('zoe');
    const abel = StudentId('abel');

    Future<void> placeBlockA({int dayOfMonth = 1}) => world.acquisitions.add(
      acquisition('a', student: 'zoe', day: dayOfMonth),
    );

    test('counts as all the passes required, without any pass', () async {
      await placeBlockA();

      final result = ok(await overview(const SessionId('x1')));

      expect(result.passedCount(zoe, ref('a', 1)), 5);
      expect(result.passedCount(zoe, ref('a', 2)), 5);
      expect(result.passedCount(abel, ref('a', 1)), 0);
      expect(result.passedCount(zoe, ref('b', 1)), 0);
    });

    test('keeps counting as acquired for a pass dated before it', () async {
      final rate = world.catalogue.exercise(ref('a', 1))!.rate;
      await placeBlockA(dayOfMonth: 5);
      await world.attempts.add(
        attempt(ref('a', 1), potted: rate.attempts, student: 'zoe', id: 'old'),
      );

      final result = ok(await overview(const SessionId('x1')));

      expect(result.passedCount(zoe, ref('a', 1)), 5);
    });

    test('is taken over by a pass below the rate: nothing passed', () async {
      final rate = world.catalogue.exercise(ref('a', 1))!.rate;
      await placeBlockA();
      await world.attempts.add(
        attempt(
          ref('a', 1),
          potted: rate.successes - 1,
          total: rate.attempts,
          student: 'zoe',
          id: 'below',
        ),
      );

      final result = ok(await overview(const SessionId('x1')));

      expect(result.passedCount(zoe, ref('a', 1)), 0);
      expect(result.passedCount(zoe, ref('a', 2)), 5);
    });

    test('is taken over by a pass exactly at the rate: one passed', () async {
      final rate = world.catalogue.exercise(ref('a', 1))!.rate;
      await placeBlockA();
      await world.attempts.add(
        attempt(
          ref('a', 1),
          potted: rate.successes,
          total: rate.attempts,
          student: 'zoe',
          id: 'equal',
        ),
      );

      final result = ok(await overview(const SessionId('x1')));

      expect(result.passedCount(zoe, ref('a', 1)), 1);
    });

    test('is taken over by a pass above the rate: one passed', () async {
      final rate = world.catalogue.exercise(ref('a', 1))!.rate;
      await placeBlockA();
      await world.attempts.add(
        attempt(
          ref('a', 1),
          potted: rate.attempts,
          total: rate.attempts,
          student: 'zoe',
          id: 'above',
        ),
      );

      final result = ok(await overview(const SessionId('x1')));

      expect(result.passedCount(zoe, ref('a', 1)), 1);
    });
  });

  test('names the catalogue session it notes, when known', () async {
    await world.session(
      id: 'x2',
      dayOfMonth: 2,
      sheet: SheetId('demi-bille-2'),
    );
    await world.session(id: 'x3', dayOfMonth: 3, sheet: SheetId('inconnue-9'));

    expect(ok(await overview(const SessionId('x1'))).sheet, isNull);
    expect(ok(await overview(const SessionId('x2'))).sheet?.part, 2);
    expect(
      ok(await overview(const SessionId('x2'))).sheet?.title,
      'Quantité demi-bille',
    );
    expect(ok(await overview(const SessionId('x3'))).sheet, isNull);
  });

  test('refuses an unknown session', () async {
    final result = await overview(const SessionId('nope'));

    expect(err(result), isA<NotFound>());
  });

  test('names the exercises of the catalogue session it notes', () async {
    await world.session(
      id: 'x2',
      dayOfMonth: 2,
      sheet: SheetId('demi-bille-2'),
    );

    final noted = ok(await overview(const SessionId('x2')));

    expect(noted.exerciseName(ref('demi-bille', 3)), 'Exercice e3');
    expect(noted.exerciseName(ref('demi-bille', 4)), 'Exercice e4');
    expect(noted.exerciseName(ref('demi-bille', 1)), isNull);
    expect(
      ok(await overview(const SessionId('x1')))
          .exerciseName(ref('demi-bille', 3)),
      isNull,
    );
  });
}
