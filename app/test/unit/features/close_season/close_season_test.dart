import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

const _season = SeasonId('season');

CloseSeason _closeSeason(DomainWorld world, {AttemptRepository? attempts}) =>
    CloseSeason(
      world.seasons,
      world.groups,
      world.students,
      world.sessions,
      attempts ?? world.attempts,
      world.plannedSessions,
      world.seasonArchives,
      world.studentEraser(attempts: attempts),
      world.ids,
      InMemoryUnitOfWork(),
    );

Set<StudentId> _ids(Iterable<String> names) => {
  for (final name in names) StudentId(name),
};

void main() {
  late DomainWorld world;
  late CloseSeason close;

  Future<Result<ClosureResult>> closeOn(
    int dayOfMonth, {
    Iterable<String> erase = const [],
    bool prepareNext = true,
    bool dropPlanned = true,
    DateTime? on,
  }) => close(
    seasonId: _season,
    closedOn: on ?? day(dayOfMonth),
    erase: _ids(erase),
    prepareNext: prepareNext,
    dropPlanned: dropPlanned,
  );

  Future<Set<String>> studentIds() async => {
    for (final s in await world.students.all()) s.id.value,
  };

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['a', 'b', 'c']);
    close = _closeSeason(world);
  });

  group('closing the season', () {
    test(
      'stores the closing day and keeps the end date when it is earlier',
      () async {
        ok(await closeOn(0, on: DateTime(2026, 11, 5)));

        final season = (await world.seasons.byId(_season))!;
        expect(season.closedOn, DateTime(2026, 11, 5));
        expect(season.endDate, day(31));
      },
    );

    test(
      'an early closure brings the end date back to the closing day',
      () async {
        ok(await closeOn(12));

        final season = (await world.seasons.byId(_season))!;
        expect(season.closedOn, day(12));
        expect(season.endDate, day(12));
        expect(season.isOpenOn(day(10)), isFalse);
      },
    );

    test('refuses an unknown season', () async {
      final result = await close(
        seasonId: const SeasonId('ghost'),
        closedOn: day(12),
        erase: const {},
      );

      expect(err(result), isA<NotFound>());
    });

    test('refuses a season that is already closed', () async {
      ok(await closeOn(12));

      expect(codeOf(await closeOn(13)), InvariantCode.seasonAlreadyClosed);
    });

    test('accepts a closing day right after the start', () async {
      ok(await closeOn(2));

      expect((await world.seasons.byId(_season))!.closedOn, day(2));
    });

    test('refuses a closing day that is not after the start', () async {
      expect(codeOf(await closeOn(1)), InvariantCode.invalidPeriod);
      expect((await world.seasons.byId(_season))!.isClosed, isFalse);
    });

    test('refuses to erase a student placed in another open season', () async {
      await world.students.save(
        (await world.students.byId(const StudentId('a')))!
            .copyWith(id: const StudentId('stranger')),
      );
      await world.groups.save(
        Group(
          id: const GroupId('elsewhere'),
          seasonId: const SeasonId('later'),
          name: 'Ailleurs',
          audience: Audience.children,
        ).admit(
          studentId: const StudentId('stranger'),
          studentAudience: Audience.children,
          from: day(1),
        ),
      );

      final result = await closeOn(12, erase: ['stranger']);

      expect(err(result), isA<NotFound>());
      expect((await world.seasons.byId(_season))!.isClosed, isFalse);
      expect(await studentIds(), contains('stranger'));
    });
  });

  group('students no group places any more', () {
    test('can be erased: a student who never had a group', () async {
      await world.students.save(
        (await world.students.byId(const StudentId('a')))!
            .copyWith(id: const StudentId('loose')),
      );

      final result = ok(await closeOn(12, erase: ['loose']));

      expect(result.erased, 1);
      expect(await studentIds(), isNot(contains('loose')));
    });

    test('can be erased: a student kept by a closure without next '
        'season', () async {
      ok(await closeOn(12, prepareNext: false));
      await world.seasons.save(
        Season(
          id: const SeasonId('later'),
          label: '2027-2028',
          startDate: DateTime(2027, 9),
          endDate: DateTime(2028, 8, 31),
        ),
      );
      final later = _closeSeason(world);

      final result = ok(
        await later(
          seasonId: const SeasonId('later'),
          closedOn: DateTime(2027, 9, 2),
          erase: _ids(['a']),
        ),
      );

      expect(result.erased, 1);
      expect(await studentIds(), {'b', 'c'});
    });
  });

  group('the archive', () {
    Future<void> seedActivity() async {
      await world.session(dayOfMonth: 3, present: {'a', 'b', 'c'});
      await world.session(id: 'x2', dayOfMonth: 4, present: {'a', 'b'});
      for (final student in ['a', 'b', 'c']) {
        await world.attempts.add(
          attempt(ref('a', 1), potted: 2, student: student, id: 'p-$student'),
        );
      }
    }

    test('is computed before the students are erased', () async {
      await seedActivity();

      ok(await closeOn(12, erase: ['a']));

      final archive = (await world.seasonArchives.bySeason(_season))!;
      final children = archive.audienceOf(Audience.children)!;
      expect(children.sessionCount, 2);
      expect(children.presenceCount, 5, reason: 'a was present twice');
      expect(children.studentCount, 3);
      expect(children.attemptCount, 3);
      expect(archive.exercises.single.studentCount, 3);
      expect(archive.exercises.single.total, 15);
    });

    test('is stored for a season without any session as nothing', () async {
      ok(await closeOn(12));

      expect(await world.seasonArchives.bySeason(_season), isNull);
    });

    test('names no student, group or date', () async {
      await seedActivity();

      ok(await closeOn(12, erase: ['a']));

      final text = (await world.seasonArchives.all()).join();
      for (final forbidden in ['a', 'b', 'c'].map((n) => 'StudentId($n)')) {
        expect(text, isNot(contains(forbidden)));
      }
      expect(text, isNot(contains('g1')));
      expect(text, isNot(contains('2026-10')));
    });
  });

  group('erasure', () {
    setUp(() async {
      await world.session(dayOfMonth: 3, present: {'a', 'b'});
      for (final student in ['a', 'b']) {
        await world.attempts.add(
          attempt(ref('a', 1), potted: 2, student: student, id: 'p-$student'),
        );
        await world.assessments.add(
          MaturityAssessment(
            id: AssessmentId('m-$student'),
            studentId: StudentId(student),
            date: day(2),
            concentration: 3,
            endurance: 3,
            frustration: 3,
          ),
        );
        await world.acquisitions.add(
          acquisition('b', student: student, id: 'q-$student'),
        );
        await world.acknowledgements.add(
          acknowledgement(
            ref('a', 1),
            lastAttempt: 'p-$student',
            student: student,
            id: 'k-$student',
          ),
        );
      }
    });

    test('erases everything about the chosen students, nothing else', () async {
      ok(await closeOn(12, erase: ['a']));

      expect(await studentIds(), {'b', 'c'});
      expect((await world.attempts.all()).map((p) => p.studentId.value), ['b']);
      expect((await world.assessments.all()).map((m) => m.studentId.value), [
        'b',
      ]);
      expect((await world.acquisitions.all()).map((q) => q.studentId.value), [
        'b',
      ]);
      expect(
        (await world.acknowledgements.all()).map((k) => k.studentId.value),
        ['b'],
      );
      final session = (await world.sessions.byId(const SessionId('x1')))!;
      expect(session.present, {const StudentId('b')});
      final group = (await world.groups.byId(const GroupId('g1')))!;
      expect(
        group.memberships.map((m) => m.studentId.value),
        isNot(contains('a')),
      );
    });

    test('keeps the sessions and the groups themselves', () async {
      ok(await closeOn(12, erase: ['a', 'b', 'c']));

      expect(await world.sessions.all(), hasLength(1));
      expect(await world.groups.all(), isNotEmpty);
      expect(await studentIds(), isEmpty);
    });

    test('counts erased and kept students', () async {
      final result = ok(await closeOn(12, erase: ['a']));

      expect(result.erased, 1);
      expect(result.kept, 2);
    });

    test('does not count as kept a student who left the group', () async {
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.groups.save(
        group.release(studentId: const StudentId('c'), to: day(10)),
      );

      final result = ok(await closeOn(12, erase: ['a']));

      expect(result.kept, 1);
    });

    test('is all or nothing, archive included', () async {
      await world.session(id: 'x2', dayOfMonth: 4, present: {'a', 'b'});
      final failing = _closeSeason(
        world,
        attempts: _FailingAttempts(world.attempts),
      );

      await expectLater(
        failing(seasonId: _season, closedOn: day(12), erase: _ids(['a'])),
        throwsStateError,
      );

      expect((await world.seasons.byId(_season))!.isClosed, isFalse);
      expect(await world.seasonArchives.all(), isEmpty);
      expect(await studentIds(), {'a', 'b', 'c'});
      expect(await world.attempts.all(), hasLength(2));
      expect(
        (await world.sessions.byId(const SessionId('x1')))!.present,
        hasLength(2),
      );
    });
  });

  group('preparing the next season', () {
    test(
      'creates it, its homonymous groups and replaces the kept students',
      () async {
        final result = ok(await closeOn(31, erase: ['c']));

        expect(result.groupsPrepared, 1);
        final seasons = await world.seasons.all();
        expect(seasons, hasLength(2));
        final next = seasons.firstWhere((s) => s.id != _season);
        expect(next.startDate, DateTime(2026, 11));
        expect(next.isClosed, isFalse);
        final groups = await world.groups.all();
        final fresh = groups.firstWhere((g) => g.seasonId == next.id);
        expect(fresh.name, 'Groupe');
        expect(fresh.audience, Audience.children);
        expect(fresh.membersOn(next.startDate), _ids(['a', 'b']).toList());
        final old = groups.firstWhere((g) => g.seasonId == _season);
        expect(old.isMemberOn(const StudentId('a'), day(31)), isTrue);
        expect(old.isMemberOn(const StudentId('a'), next.startDate), isFalse);
      },
    );

    test('a late closure places the kept students from the first day of the '
        'next season, not the day after the closure', () async {
      ok(await closeOn(0, on: DateTime(2026, 11, 20), erase: ['c']));

      final groups = await world.groups.all();
      final next = groups.firstWhere((g) => g.seasonId != _season);
      final old = groups.firstWhere((g) => g.seasonId == _season);
      expect(next.isMemberOn(const StudentId('a'), DateTime(2026, 11)), isTrue);
      expect(next.membersOn(DateTime(2026, 11, 20)), _ids(['a', 'b']).toList());
      expect(old.isMemberOn(const StudentId('a'), day(31)), isTrue);
      expect(old.isMemberOn(const StudentId('a'), DateTime(2026, 11)), isFalse);
    });

    test('keeps the whole path of a kept student', () async {
      await world.session(dayOfMonth: 3, present: {'a'});
      await world.attempts.add(attempt(ref('a', 1), potted: 2, student: 'a'));

      ok(await closeOn(31, erase: ['c']));

      expect(
        await world.attempts.forStudent(const StudentId('a')),
        hasLength(1),
      );
    });

    test(
      'reuses a next season and a group of the same name that exist',
      () async {
        await world.seasons.save(
          Season(
            id: const SeasonId('later'),
            label: '2026-2027 suite',
            startDate: DateTime(2026, 11),
            endDate: DateTime(2027, 6, 30),
          ),
        );
        await world.groups.save(
          Group(
            id: const GroupId('g-later'),
            seasonId: const SeasonId('later'),
            name: ' groupe ',
            audience: Audience.children,
          ),
        );

        ok(await closeOn(31));

        expect(await world.seasons.all(), hasLength(2));
        final later = (await world.groups.byId(const GroupId('g-later')))!;
        expect(
          later.membersOn(DateTime(2026, 11)),
          _ids(['a', 'b', 'c']).toList(),
        );
        expect(await world.groups.all(), hasLength(2));
      },
    );

    test('suffixes the name of a group until it is free', () async {
      await world.seasons.save(
        Season(
          id: const SeasonId('later'),
          label: '2026-2027 suite',
          startDate: DateTime(2026, 11),
          endDate: DateTime(2027, 6, 30),
        ),
      );
      for (final (id, name) in [('t1', 'groupe'), ('t2', 'Groupe (2)')]) {
        await world.groups.save(
          Group(
            id: GroupId(id),
            seasonId: const SeasonId('later'),
            name: name,
            audience: Audience.adults,
          ),
        );
      }

      ok(await closeOn(31));

      final fresh = (await world.groups.all()).where(
        (g) =>
            g.seasonId == const SeasonId('later') &&
            g.audience.name == 'children',
      );
      expect(fresh.map((g) => g.name), ['Groupe (3)']);
    });

    test('does nothing when the option is off', () async {
      final result = ok(await closeOn(31, prepareNext: false));

      expect(result.groupsPrepared, 0);
      expect(await world.seasons.all(), hasLength(1));
      final old = (await world.groups.byId(const GroupId('g1')))!;
      expect(old.memberships.every((m) => m.to == null), isTrue);
    });

    test('skips a student who already left the group', () async {
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.groups.save(
        group.release(studentId: const StudentId('c'), to: day(10)),
      );

      ok(await closeOn(31));

      final next = (await world.groups.all()).firstWhere(
        (g) => g.seasonId != _season,
      );
      expect(next.membersOn(DateTime(2026, 11)), _ids(['a', 'b']).toList());
    });
  });

  group('planned sessions', () {
    Future<void> plan(String id, int dayOfMonth, {String? group = 'g1'}) =>
        world.plannedSessions.add(
          Session(
            id: id,
            title: id,
            date: day(dayOfMonth),
            audience: Audience.children,
            groupId: group == null ? null : GroupId(group),
          ),
        );

    test('drops those of the season after the closing day', () async {
      await plan('past', 5);
      await plan('same-day', 12);
      await plan('future', 20);
      await plan('loose-future', 25, group: null);

      final result = ok(await closeOn(12));

      expect((await world.plannedSessions.getAll()).map((s) => s.id), [
        'past',
        'same-day',
      ]);
      expect(result.plannedDropped, 2);
    });

    test('keeps those of another season', () async {
      await world.groups.save(
        Group(
          id: const GroupId('other'),
          seasonId: const SeasonId('elsewhere'),
          name: 'Ailleurs',
          audience: Audience.children,
        ),
      );
      await plan('elsewhere', 20, group: 'other');

      ok(await closeOn(12));

      expect(await world.plannedSessions.getAll(), hasLength(1));
    });

    test('keeps them all when the option is off', () async {
      await plan('future', 20);

      final result = ok(await closeOn(12, dropPlanned: false));

      expect(await world.plannedSessions.getAll(), hasLength(1));
      expect(result.plannedDropped, 0);
    });
  });
}

/// Passages dont l'effacement d'un élève échoue : l'échec survient après
/// l'archive, la clôture et d'autres écritures.
class _FailingAttempts implements AttemptRepository {
  _FailingAttempts(this._inner);

  final AttemptRepository _inner;

  @override
  Future<void> eraseStudent(StudentId studentId) async {
    throw StateError('effacement impossible');
  }

  @override
  Future<void> add(ExerciseAttempt attempt) => _inner.add(attempt);

  @override
  Future<List<ExerciseAttempt>> all() => _inner.all();

  @override
  Future<void> delete(AttemptId id) => _inner.delete(id);

  @override
  Future<List<ExerciseAttempt>> forSession(SessionId sessionId) =>
      _inner.forSession(sessionId);

  @override
  Future<List<ExerciseAttempt>> forStudent(StudentId studentId) =>
      _inner.forStudent(studentId);
}
