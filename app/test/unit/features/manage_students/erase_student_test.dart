import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_key.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

/// Unité de travail qui échoue à la fin : rien ne doit rester effacé.
class _FailingAtTheEnd implements UnitOfWork {
  @override
  Future<T> run<T>(Future<T> Function() body) =>
      InMemoryUnitOfWork().run(() async {
        await body();
        throw StateError('disque plein');
      });
}

RunProgress _running(
  String sheet, {
  String? group,
  String? record,
  String? planned,
}) => RunProgress(
  key: RunProgressKey(
    sheetId: SheetId(sheet),
    sessionId: planned,
    groupId: group == null ? null : GroupId(group),
  ),
  updatedAt: DateTime.utc(2026, 10, 12),
  step: 2,
  recordId: record == null ? null : SessionId(record),
);

Future<List<String>> _runningSheets(DomainWorld world) async => [
  for (final progress in await world.runProgress.all())
    progress.key.sheetId.value,
]..sort();

void main() {
  late DomainWorld world;

  EraseStudent build([UnitOfWork? unitOfWork]) => EraseStudent(
    world.students,
    world.groups,
    world.sessions,
    world.attempts,
    world.assessments,
    world.acquisitions,
    world.acknowledgements,
    world.runProgress,
    world.plannedSessions,
    unitOfWork ?? InMemoryUnitOfWork(),
  );

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1', 's2']);
    await world.session(present: {'s1', 's2'});
    await world.attempts.add(attempt(ref('a', 1), potted: 3));
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, id: 'a2', student: 's2'),
    );
    await world.acquisitions.add(acquisition('a'));
    await world.acquisitions.add(acquisition('b', id: 'q2', student: 's2'));
    await world.acknowledgements.add(
      acknowledgement(ref('a', 1), lastAttempt: 'a1'),
    );
    await world.acknowledgements.add(
      acknowledgement(ref('a', 1), lastAttempt: 'a2', id: 'k2', student: 's2'),
    );
    await world.assessments.add(
      MaturityAssessment(
        id: const AssessmentId('b1'),
        studentId: const StudentId('s1'),
        date: day(5),
        concentration: 3,
        endurance: 3,
        frustration: 3,
      ),
    );
  });

  test('erases the student and everything that names them', () async {
    ok(await build()(const StudentId('s1')));

    expect(await world.students.byId(const StudentId('s1')), isNull);
    expect(await world.attempts.forStudent(const StudentId('s1')), isEmpty);
    expect(await world.assessments.forStudent(const StudentId('s1')), isEmpty);
    expect(await world.acquisitions.forStudent(const StudentId('s1')), isEmpty);
    expect(
      await world.acknowledgements.forStudent(const StudentId('s1')),
      isEmpty,
    );
    final session = (await world.sessions.byId(const SessionId('x1')))!;
    expect(session.present, {const StudentId('s2')});
    final group = (await world.groups.byId(const GroupId('g1')))!;
    expect(group.memberships.map((m) => m.studentId), [const StudentId('s2')]);
  });

  test('keeps the other students', () async {
    ok(await build()(const StudentId('s1')));

    expect(
      await world.acknowledgements.forStudent(const StudentId('s2')),
      hasLength(1),
    );

    expect(await world.students.byId(const StudentId('s2')), isNotNull);
    expect(
      await world.attempts.forStudent(const StudentId('s2')),
      hasLength(1),
    );
    expect(
      await world.acquisitions.forStudent(const StudentId('s2')),
      hasLength(1),
    );
  });

  test('refuses an unknown student without erasing anything', () async {
    final failure = err(await build()(const StudentId('ghost')));

    expect(
      failure,
      isA<NotFound>()
          .having((e) => e.kind, 'kind', 'student')
          .having((e) => e.id, 'id', 'ghost'),
    );
    expect(await world.students.all(), hasLength(2));
    expect(await world.attempts.all(), hasLength(2));
  });

  test('leaves everything in place when a write fails', () async {
    await expectLater(
      build(_FailingAtTheEnd())(const StudentId('s1')),
      throwsStateError,
    );

    expect(await world.students.byId(const StudentId('s1')), isNotNull);
    expect(
      await world.attempts.forStudent(const StudentId('s1')),
      hasLength(1),
    );
    expect(await world.assessments.all(), hasLength(1));
    expect(await world.acquisitions.all(), hasLength(2));
    expect(await world.acknowledgements.all(), hasLength(2));
    final group = (await world.groups.byId(const GroupId('g1')))!;
    expect(group.memberships, hasLength(2));
    final session = (await world.sessions.byId(const SessionId('x1')))!;
    expect(session.present, hasLength(2));
  });

  group('running guided sessions (ADR 0020)', () {
    setUp(() async {
      // Un groupe où s1 a été membre puis est parti (période close), et un
      // groupe où il n'a jamais été.
      await world.groups.save(
        Group(
              id: const GroupId('g2'),
              seasonId: const SeasonId('season'),
              name: 'Ancien groupe',
              audience: Audience.children,
            )
            .admit(
              studentId: const StudentId('s1'),
              studentAudience: Audience.children,
              from: day(1),
            )
            .release(studentId: const StudentId('s1'), to: day(2)),
      );
      await world.groups.save(
        Group(
          id: const GroupId('g3'),
          seasonId: const SeasonId('season'),
          name: 'Autre groupe',
          audience: Audience.children,
        ).admit(
          studentId: const StudentId('s2'),
          studentAudience: Audience.children,
          from: day(1),
        ),
      );
      await world.session(id: 'x2', present: {'s2'});
      await world.runProgress.save(_running('par-groupe', group: 'g1'));
      await world.runProgress.save(_running('ancien-groupe', group: 'g2'));
      await world.runProgress.save(_running('par-saisie', record: 'x1'));
      await world.runProgress.save(_running('autre-groupe', group: 'g3'));
      await world.runProgress.save(_running('autre-saisie', record: 'x2'));
      await world.runProgress.save(_running('sans-lien'));
      await world.plannedSessions.add(
        Session(
          id: 'p1',
          title: 'Cours',
          date: day(8),
          audience: Audience.children,
          groupId: const GroupId('g1'),
        ),
      );
      await world.plannedSessions.add(
        Session(
          id: 'p3',
          title: 'Autre cours',
          date: day(8),
          audience: Audience.children,
          groupId: const GroupId('g3'),
        ),
      );
      await world.runProgress.save(
        _running('planifiee-du-groupe', planned: 'p1'),
      );
      await world.runProgress.save(_running('planifiee-autre', planned: 'p3'));
    });

    test('erases the sessions of a group the student belongs to, of a group '
        'they left, of a planned session of their group (which carries no '
        'group of its own) and of a record they attended', () async {
      ok(await build()(const StudentId('s1')));

      expect(await _runningSheets(world), [
        'autre-groupe',
        'autre-saisie',
        'planifiee-autre',
        'sans-lien',
      ]);
    });

    test(
      'computes the links before the presences and memberships go',
      () async {
        // Si les liens étaient calculés après l'effacement des présences et des
        // appartenances, aucune de ces séances ne serait retrouvée.
        ok(await build()(const StudentId('s1')));

        expect(
          await world.runProgress.byKey(_running('par-saisie').key),
          isNull,
        );
        expect(
          await world.runProgress.byKey(_running('par-groupe').key),
          isNull,
        );
      },
    );

    test('leaves the running sessions in place when a write fails', () async {
      await expectLater(
        build(_FailingAtTheEnd())(const StudentId('s1')),
        throwsStateError,
      );

      expect(await _runningSheets(world), hasLength(8));
    });

    test('refuses an unknown student without erasing any session', () async {
      err(await build()(const StudentId('ghost')));

      expect(await _runningSheets(world), hasLength(8));
    });
  });

  group('session tags (ADR 0023)', () {
    test('goes with the running session of the student, tags included, but the '
        'tags of the record stay: they name no one', () async {
      await world.seedClub(studentNames: ['s1', 's2']);
      await world.session(present: {'s1', 's2'});
      await world.sessions.setTags(const SessionId('x1'), {SessionTag.tooLong});
      await world.runProgress.save(
        _running(
          'par-saisie',
          record: 'x1',
        ).copyWith(tags: {SessionTag.toRedo}),
      );

      final result = await build()(const StudentId('s1'));

      expect(result, isA<Ok<void>>());
      expect(await world.runProgress.all(), isEmpty);
      final record = (await world.sessions.byId(const SessionId('x1')))!;
      expect(record.tags, {SessionTag.tooLong});
      expect(record.present, {const StudentId('s2')});
    });
  });
}
