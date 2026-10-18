import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_harness.dart';
import 'student_group_contract.dart';

Student _student(String id, String name, {DateTime? since}) => Student.enroll(
  id: StudentId(id),
  firstName: name,
  audience: Audience.children,
  since: since ?? DateTime(2026, 9),
);

Season _season(String id, [String label = '2026-2027']) => Season(
  id: SeasonId(id),
  label: label,
  startDate: DateTime(2026, 9),
  endDate: DateTime(2027, 6, 30),
);

Group _group(String id, {String name = 'Jeunes', Audience? audience}) => Group(
  id: GroupId(id),
  seasonId: const SeasonId('season'),
  name: name,
  audience: audience ?? Audience.children,
);

SessionRecord _record(
  String id, {
  required DateTime date,
  String group = 'g1',
  Set<String> present = const {'s1'},
  String? main,
  String? recall,
  Set<SessionTag> tags = const {},
}) => SessionRecord(
  id: SessionId(id),
  groupId: GroupId(group),
  seasonId: const SeasonId('season'),
  date: date,
  audience: Audience.children,
  present: {for (final name in present) StudentId(name)},
  mainBlockId: main,
  recallBlockId: recall,
  tags: tags,
);

ExerciseAttempt _attempt(
  String id, {
  String student = 's1',
  String session = 'x1',
  int potted = 3,
  int passIndex = 1,
}) => ExerciseAttempt(
  id: AttemptId(id),
  studentId: StudentId(student),
  sessionId: SessionId(session),
  exercise: ExerciseRef(blockId: 'puissance', number: 2),
  date: DateTime(2026, 10, 3),
  passIndex: passIndex,
  potted: potted,
  total: 5,
);

MaturityAssessment _assessment(
  String id, {
  required DateTime date,
  String student = 's1',
  int concentration = 3,
  String? comment,
}) => MaturityAssessment(
  id: AssessmentId(id),
  studentId: StudentId(student),
  date: date,
  concentration: concentration,
  endurance: 2,
  frustration: 4,
  comment: comment,
);

/// Suite de contrat unique des repositories : exécutée contre chaque
/// implémentation (mémoire, drift) pour garantir un comportement identique
/// (ADR 0001).
void repositoryContract(
  String label,
  Future<RepositoryHarness> Function() open,
) {
  group('$label : contrat des repositories', () {
    late RepositoryHarness repos;

    setUp(() async => repos = await open());
    tearDown(() => repos.close());

    group('saisons', () {
      test('round-trips, replaces and lists in order', () async {
        await repos.seasons.save(_season('a'));
        await repos.seasons.save(_season('b', '2027-2028'));
        await repos.seasons.save(_season('a', '2026-2027 bis'));

        expect(
          await repos.seasons.byId(const SeasonId('a')),
          _season('a', '2026-2027 bis'),
        );
        expect((await repos.seasons.all()).map((s) => s.label), [
          '2026-2027 bis',
          '2027-2028',
        ]);
      });

      test(
        'returns null for an unknown season and deletes logically',
        () async {
          await repos.seasons.save(_season('a'));
          await repos.seasons.delete(const SeasonId('a'));

          expect(await repos.seasons.byId(const SeasonId('a')), isNull);
          expect(await repos.seasons.all(), isEmpty);
        },
      );
    });

    group('clôture des saisons', () {
      test(
        'stores the closing day and reopens when saved without it',
        () async {
          final closed = _season('a').copyWith(closedOn: DateTime(2027, 6, 30));

          await repos.seasons.save(closed);
          final read = await repos.seasons.byId(const SeasonId('a'));
          expect(read, closed);
          expect(read!.isClosed, isTrue);

          await repos.seasons.save(_season('a'));
          expect(await repos.seasons.byId(const SeasonId('a')), _season('a'));
          expect(
            (await repos.seasons.byId(const SeasonId('a')))!.closedOn,
            isNull,
          );
        },
      );

      test('a season with a reduced end date keeps both dates', () async {
        final early = _season('a').copyWith(
          endDate: DateTime(2026, 10, 12),
          closedOn: DateTime(2026, 10, 12),
        );

        await repos.seasons.save(early);

        expect(await repos.seasons.byId(const SeasonId('a')), early);
      });
    });

    group('séances données', () {
      test('round-trips presences and optional blocks', () async {
        final full = _record(
          'x1',
          date: DateTime(2026, 10, 3),
          present: {'s1', 's2'},
          main: 'puissance',
          recall: 'rebond',
        );
        final bare = _record('x2', date: DateTime(2026, 10, 10), present: {});

        await repos.sessionRecords.save(full);
        await repos.sessionRecords.save(bare);

        expect(await repos.sessionRecords.byId(const SessionId('x1')), full);
        expect(await repos.sessionRecords.byId(const SessionId('x2')), bare);
        expect(await repos.sessionRecords.byId(const SessionId('zz')), isNull);
      });

      test('round-trips the session tags, none by default', () async {
        final tagged = _record(
          'x1',
          date: DateTime(2026, 10, 3),
          tags: {SessionTag.tooLong, SessionTag.toRedo},
        );
        final plain = _record('x2', date: DateTime(2026, 10, 10));

        await repos.sessionRecords.save(tagged);
        await repos.sessionRecords.save(plain);

        final read = await repos.sessionRecords.byId(const SessionId('x1'));
        expect(read, tagged);
        expect(read!.tags, {SessionTag.tooLong, SessionTag.toRedo});
        expect(
          (await repos.sessionRecords.byId(const SessionId('x2')))!.tags,
          isEmpty,
        );
      });

      test('replaces the session tags when saved again', () async {
        await repos.sessionRecords.save(
          _record(
            'x1',
            date: DateTime(2026, 10, 3),
            tags: {SessionTag.tooLong},
          ),
        );
        await repos.sessionRecords.save(
          _record('x1', date: DateTime(2026, 10, 3)),
        );

        expect(
          (await repos.sessionRecords.byId(const SessionId('x1')))!.tags,
          isEmpty,
        );
      });

      test(
        'sets only the tags, leaving presences and the rest alone',
        () async {
          final stored = _record(
            'x1',
            date: DateTime(2026, 10, 3),
            present: {'s1', 's2'},
            main: 'puissance',
          );
          await repos.sessionRecords.save(stored);

          await repos.sessionRecords.setTags(const SessionId('x1'), {
            SessionTag.tooHard,
            SessionTag.gameAppreciated,
          });

          final read = await repos.sessionRecords.byId(const SessionId('x1'));
          expect(
            read,
            stored.copyWith(
              tags: {SessionTag.tooHard, SessionTag.gameAppreciated},
            ),
          );
          await repos.sessionRecords.setTags(const SessionId('x1'), const {});
          expect(
            (await repos.sessionRecords.byId(const SessionId('x1')))!.tags,
            isEmpty,
          );
        },
      );

      test(
        'setting the tags of an unknown or deleted session does nothing',
        () async {
          await repos.sessionRecords.setTags(const SessionId('zz'), {
            SessionTag.tooLong,
          });
          expect(
            await repos.sessionRecords.byId(const SessionId('zz')),
            isNull,
          );

          await repos.sessionRecords.save(
            _record('x1', date: DateTime(2026, 10, 3)),
          );
          await repos.sessionRecords.delete(const SessionId('x1'));
          await repos.sessionRecords.setTags(const SessionId('x1'), {
            SessionTag.tooLong,
          });
          expect(
            await repos.sessionRecords.byId(const SessionId('x1')),
            isNull,
          );
          expect(await repos.sessionRecords.all(), isEmpty);
        },
      );

      test(
        'keeps the tags when a student is erased from the presences',
        () async {
          await repos.sessionRecords.save(
            _record(
              'x1',
              date: DateTime(2026, 10, 3),
              present: {'s1', 's2'},
              tags: {SessionTag.tooLong},
            ),
          );

          await repos.sessionRecords.eraseStudent(const StudentId('s1'));

          final read = await repos.sessionRecords.byId(const SessionId('x1'));
          expect(read!.present, {const StudentId('s2')});
          expect(read.tags, {SessionTag.tooLong});
        },
      );

      test('replaces the presences when saved again', () async {
        await repos.sessionRecords.save(
          _record('x1', date: DateTime(2026, 10, 3), present: {'s1', 's2'}),
        );
        await repos.sessionRecords.save(
          _record('x1', date: DateTime(2026, 10, 3), present: {'s2', 's3'}),
        );

        final loaded = await repos.sessionRecords.byId(const SessionId('x1'));
        expect(loaded!.present, {const StudentId('s2'), const StudentId('s3')});
        expect(
          await repos.sessionRecords.forStudent(const StudentId('s1')),
          isEmpty,
        );
      });

      test('lists a group and a student from oldest to newest', () async {
        await repos.sessionRecords.save(
          _record('late', date: DateTime(2026, 10, 17), present: {'s1'}),
        );
        await repos.sessionRecords.save(
          _record('early', date: DateTime(2026, 10, 3), present: {'s1', 's2'}),
        );
        await repos.sessionRecords.save(
          _record(
            'other',
            date: DateTime(2026, 10, 10),
            group: 'g2',
            present: {'s2'},
          ),
        );

        expect(
          (await repos.sessionRecords.forGroup(const GroupId('g1')))
              .map((s) => s.id.value),
          ['early', 'late'],
        );
        expect(
          (await repos.sessionRecords.forStudent(const StudentId('s2')))
              .map((s) => s.id.value),
          ['early', 'other'],
        );
        expect((await repos.sessionRecords.all()).map((s) => s.id.value), [
          'late',
          'early',
          'other',
        ]);
      });

      test('finds the sessions a student attended', () async {
        await repos.sessionRecords.save(
          _record('x1', date: DateTime(2026, 10, 3)),
        );
        await repos.sessionRecords.save(
          _record('x2', date: DateTime(2026, 10, 10), present: {'s1', 's2'}),
        );
        await repos.sessionRecords.save(
          _record('x3', date: DateTime(2026, 10, 17), present: {'s2'}),
        );

        expect(
          await repos.sessionRecords.idsEverPresent(const StudentId('s1')),
          {const SessionId('x1'), const SessionId('x2')},
        );
        expect(
          await repos.sessionRecords.idsEverPresent(const StudentId('absent')),
          isEmpty,
        );
      });

      test('hides a deleted session everywhere', () async {
        await repos.sessionRecords.save(
          _record('x1', date: DateTime(2026, 10, 3)),
        );
        await repos.sessionRecords.delete(const SessionId('x1'));

        expect(await repos.sessionRecords.byId(const SessionId('x1')), isNull);
        expect(
          await repos.sessionRecords.forGroup(const GroupId('g1')),
          isEmpty,
        );
        expect(
          await repos.sessionRecords.forStudent(const StudentId('s1')),
          isEmpty,
        );
        expect(await repos.sessionRecords.all(), isEmpty);
      });
    });

    group('passages', () {
      test('round-trips and filters by student and session', () async {
        final first = _attempt('a1');
        final second = _attempt('a2', session: 'x2', passIndex: 2);
        final other = _attempt('a3', student: 's2');

        await repos.attempts.add(first);
        await repos.attempts.add(second);
        await repos.attempts.add(other);

        expect(await repos.attempts.forStudent(const StudentId('s1')), [
          first,
          second,
        ]);
        expect(await repos.attempts.forSession(const SessionId('x1')), [
          first,
          other,
        ]);
        expect(await repos.attempts.all(), [first, second, other]);
        expect(await repos.attempts.forStudent(const StudentId('zz')), isEmpty);
      });

      test('is idempotent: adding the same id replaces the attempt', () async {
        await repos.attempts.add(_attempt('a1', potted: 1));
        await repos.attempts.add(_attempt('a2'));
        await repos.attempts.add(_attempt('a1', potted: 4));

        final all = await repos.attempts.all();
        expect(all.map((a) => a.id.value), ['a1', 'a2']);
        expect(all.first.potted, 4);
      });

      test('hides a deleted attempt and ignores unknown deletions', () async {
        await repos.attempts.add(_attempt('a1'));
        await repos.attempts.add(_attempt('a2'));

        await repos.attempts.delete(const AttemptId('a1'));
        await repos.attempts.delete(const AttemptId('unknown'));

        expect((await repos.attempts.all()).map((a) => a.id.value), ['a2']);
        expect(
          await repos.attempts.forSession(const SessionId('x1')),
          hasLength(1),
        );
      });
    });

    group('bilans de maturité', () {
      test('lists a student from oldest to newest', () async {
        final newer = _assessment(
          'b1',
          date: DateTime(2026, 12),
          concentration: 4,
        );
        final older = _assessment('b2', date: DateTime(2026, 10));
        final other = _assessment(
          'b3',
          student: 's2',
          date: DateTime(2026, 11),
        );

        await repos.assessments.add(newer);
        await repos.assessments.add(older);
        await repos.assessments.add(other);

        expect(await repos.assessments.forStudent(const StudentId('s1')), [
          older,
          newer,
        ]);
        expect(await repos.assessments.all(), [newer, older, other]);
      });

      test('keeps the comment and replaces it by id', () async {
        await repos.assessments.add(
          _assessment('b1', date: DateTime(2026, 10), comment: 'Calme'),
        );
        expect((await repos.assessments.all()).single.comment, 'Calme');

        await repos.assessments.add(
          _assessment('b1', date: DateTime(2026, 10)),
        );

        expect((await repos.assessments.all()).single.comment, isNull);
      });

      test('is idempotent and deletes logically', () async {
        await repos.assessments.add(
          _assessment('b1', date: DateTime(2026, 10)),
        );
        await repos.assessments.add(
          _assessment('b1', date: DateTime(2026, 10), concentration: 1),
        );
        await repos.assessments.add(
          _assessment('b2', date: DateTime(2026, 11)),
        );
        await repos.assessments.delete(const AssessmentId('b2'));

        final all = await repos.assessments.all();
        expect(all, hasLength(1));
        expect(all.single.concentration, 1);
      });
    });

    group('séances planifiées', () {
      test(
        'lists the planned sessions of some groups, and only those',
        () async {
          Session planned(String id, String? group) => Session(
            id: id,
            title: id,
            date: DateTime(2026, 10, 12),
            audience: Audience.children,
            groupId: group == null ? null : GroupId(group),
          );
          await repos.sessions.add(planned('p1', 'g1'));
          await repos.sessions.add(planned('p2', 'g2'));
          await repos.sessions.add(planned('p3', 'g3'));
          await repos.sessions.add(planned('p4', null));

          expect(
            await repos.sessions.idsOfGroups({
              const GroupId('g1'),
              const GroupId('g3'),
            }),
            {'p1', 'p3'},
          );
          expect(await repos.sessions.idsOfGroups({}), isEmpty);
        },
      );

      test('round-trips, replaces by id and deletes logically', () async {
        final first = Session(
          id: 'p1',
          title: 'Rebond',
          date: DateTime(2026, 10, 12),
          audience: Audience.children,
        );
        final second = Session(
          id: 'p2',
          title: 'Rejet',
          date: DateTime(2026, 10, 19),
          audience: Audience.adults,
          groupId: const GroupId('g1'),
        );
        final renamed = Session(
          id: 'p1',
          title: 'Rebond 2',
          date: DateTime(2026, 10, 13),
          audience: Audience.children,
          groupId: const GroupId('g2'),
        );

        expect(await repos.sessions.getAll(), isEmpty);
        await repos.sessions.add(first);
        await repos.sessions.add(second);
        await repos.sessions.add(renamed);
        expect(await repos.sessions.getAll(), [renamed, second]);

        await repos.sessions.delete('p1');
        await repos.sessions.delete('unknown');
        expect(await repos.sessions.getAll(), [second]);
      });

      test('keeps the catalogue session, replaced or cleared by add', () async {
        final linked = Session(
          id: 'p1',
          title: 'Demi-bille',
          date: DateTime(2026, 10, 12),
          audience: Audience.adults,
          sheetId: SheetId('demi-bille-2'),
        );
        final unknown = linked.copyWith(sheetId: SheetId('inconnue-9'));
        final free = linked.copyWith(sheetId: null);

        await repos.sessions.add(linked);
        expect((await repos.sessions.getAll()).single.sheetId, linked.sheetId);

        await repos.sessions.add(unknown);
        expect(await repos.sessions.getAll(), [unknown]);

        await repos.sessions.add(free);
        expect(await repos.sessions.getAll(), [free]);
      });

      test('keeps the group, replaced or cleared by add', () async {
        final planned = Session(
          id: 'p1',
          title: 'Cours',
          date: DateTime(2026, 10, 12),
          audience: Audience.children,
          groupId: const GroupId('g1'),
        );

        await repos.sessions.add(planned);
        expect(await repos.sessions.getAll(), [planned]);

        await repos.sessions.add(planned.copyWith(groupId: null));
        expect((await repos.sessions.getAll()).single.groupId, isNull);
      });

      test('exposes an unmodifiable snapshot', () async {
        final sessions = await repos.sessions.getAll();

        expect(
          () => sessions.add(
            Session(
              id: '1',
              title: 'a',
              date: DateTime(2026, 10, 12),
              audience: Audience.children,
            ),
          ),
          throwsUnsupportedError,
        );
      });
    });

    group('effacement d’un élève (droit à l’effacement)', () {
      Future<void> seed() async {
        await repos.students.save(_student('s1', 'Léa'));
        await repos.students.save(_student('s2', 'Théo'));
        await repos.groups.save(
          _group('g1')
              .admit(
                studentId: const StudentId('s1'),
                studentAudience: Audience.children,
                from: DateTime(2026, 9),
              )
              .admit(
                studentId: const StudentId('s2'),
                studentAudience: Audience.children,
                from: DateTime(2026, 9),
              ),
        );
        await repos.sessionRecords.save(
          _record('x1', date: DateTime(2026, 10, 3), present: {'s1', 's2'}),
        );
        await repos.attempts.add(_attempt('a1'));
        await repos.attempts.add(_attempt('a2', passIndex: 2));
        await repos.attempts.add(_attempt('a3', student: 's2'));
        await repos.assessments.add(
          _assessment('b1', date: DateTime(2026, 10, 5)),
        );
        await repos.assessments.add(
          _assessment('b2', date: DateTime(2026, 10, 6), student: 's2'),
        );
      }

      Future<void> erase(String id) async {
        final student = StudentId(id);
        await repos.attempts.eraseStudent(student);
        await repos.assessments.eraseStudent(student);
        await repos.sessionRecords.eraseStudent(student);
        await repos.groups.eraseStudent(student);
        await repos.students.erase(student);
      }

      test('removes the student and everything that names them', () async {
        await seed();

        await erase('s1');

        expect(await repos.students.byId(const StudentId('s1')), isNull);
        expect((await repos.students.all()).map((s) => s.id.value), ['s2']);
        expect(await repos.attempts.forStudent(const StudentId('s1')), isEmpty);
        expect((await repos.attempts.all()).map((a) => a.id.value), ['a3']);
        expect(
          await repos.assessments.forStudent(const StudentId('s1')),
          isEmpty,
        );
        expect(await repos.assessments.all(), hasLength(1));
        expect(
          await repos.sessionRecords.forStudent(const StudentId('s1')),
          isEmpty,
        );
        final session = await repos.sessionRecords.byId(const SessionId('x1'));
        expect(session!.present, {const StudentId('s2')});
        final group = await repos.groups.byId(const GroupId('g1'));
        expect(group!.memberships.map((m) => m.studentId.value), ['s2']);
      });

      test('keeps the other students untouched', () async {
        await seed();

        await erase('s1');

        expect(
          await repos.attempts.forStudent(const StudentId('s2')),
          hasLength(1),
        );
        expect(
          await repos.assessments.forStudent(const StudentId('s2')),
          hasLength(1),
        );
        expect(
          await repos.sessionRecords.forStudent(const StudentId('s2')),
          hasLength(1),
        );
      });

      test('also removes what had been deleted logically', () async {
        await seed();
        await repos.attempts.delete(const AttemptId('a2'));
        await repos.assessments.delete(const AssessmentId('b1'));
        await repos.students.delete(const StudentId('s1'));

        await erase('s1');
        // Une nouvelle sauvegarde ne ressuscite que ce qu'elle écrit.
        await repos.students.save(_student('s1', 'Autre'));

        expect(await repos.attempts.forStudent(const StudentId('s1')), isEmpty);
        expect(
          await repos.assessments.forStudent(const StudentId('s1')),
          isEmpty,
        );
        expect(
          (await repos.students.byId(const StudentId('s1')))!.audienceHistory,
          hasLength(1),
        );
      });

      test('ignores a student that does not exist', () async {
        await seed();

        await erase('unknown');

        expect(await repos.students.all(), hasLength(2));
        expect(await repos.attempts.all(), hasLength(3));
      });
    });

    group('unité de travail', () {
      test('returns the value of the body', () async {
        final value = await repos.unitOfWork.run(() async {
          await repos.students.save(_student('s1', 'Léa'));
          return 42;
        });

        expect(value, 42);
        expect(await repos.students.all(), hasLength(1));
      });

      test('propagates the failure of the body', () async {
        await expectLater(
          repos.unitOfWork.run<void>(() async => throw StateError('boom')),
          throwsStateError,
        );
      });

      test('cancels the writes already made when the body fails', () async {
        await expectLater(
          repos.unitOfWork.run<void>(() async {
            await repos.students.save(_student('s1', 'Léa'));
            await repos.groups.save(_group('g1'));
            throw StateError('boom');
          }),
          throwsStateError,
        );

        expect(await repos.students.all(), isEmpty);
        expect(await repos.groups.all(), isEmpty);
      });

      test('restores overwritten and removed items on failure', () async {
        await repos.students.save(_student('s1', 'Léa'));
        await repos.students.save(_student('s2', 'Hugo'));

        await expectLater(
          repos.unitOfWork.run<void>(() async {
            await repos.students.save(_student('s1', 'Renamed'));
            await repos.students.delete(const StudentId('s2'));
            await repos.students.save(_student('s3', 'Mia'));
            throw StateError('boom');
          }),
          throwsStateError,
        );

        final names = [
          for (final student in await repos.students.all()) student.firstName,
        ];
        expect(names, unorderedEquals(['Léa', 'Hugo']));
      });

      test('keeps the writes of a body that succeeds', () async {
        await repos.unitOfWork.run<void>(() async {
          await repos.students.save(_student('s1', 'Léa'));
          await repos.students.save(_student('s2', 'Hugo'));
        });

        expect(await repos.students.all(), hasLength(2));
      });

      test(
        'cancels the writes of a nested unit when the outer fails',
        () async {
          await expectLater(
            repos.unitOfWork.run<void>(() async {
              await repos.unitOfWork.run<void>(() async {
                await repos.students.save(_student('s1', 'Léa'));
              });
              throw StateError('boom');
            }),
            throwsStateError,
          );

          expect(await repos.students.all(), isEmpty);
        },
      );
    });
  });

  studentGroupContract(label, () async {
    final repos = await open();
    return (students: repos.students, groups: repos.groups, close: repos.close);
  });
}
