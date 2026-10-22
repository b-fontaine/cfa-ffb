import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
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
import 'package:flutter_test/flutter_test.dart';

import '../support/stream_log.dart';
import 'repository_harness.dart';

/// Le contrat des **flux** des dépôts (`watch…`, FB5b, ADR 0024 décision 28) :
/// l'état courant d'abord, puis un état à chaque changement fait par n'importe
/// quel appareil, sans doublon d'écoute ; une annulation libère l'écoute.
/// Joué sur la mémoire, drift et Firestore (faux) avec le même harnais que
/// `repositoryContract`. Le temps réel entre deux clients et sous les vraies
/// règles est prouvé contre l'émulateur (`scripts/rules_test/watch.test.mjs`).
void repositoryWatchContract(
  String label,
  Future<RepositoryHarness> Function() open,
) {
  group('$label : contrat des flux des repositories', () {
    late RepositoryHarness repos;
    final logs = <StreamLog<Object?>>[];

    setUp(() async {
      repos = await open();
      // Une saison, deux fiches dans `g1`, un groupe `g2` et deux séances
      // données : ce que Firestore exige avant toute donnée dénormalisée.
      await repos.seasons.save(
        Season(
          id: const SeasonId('season'),
          label: '2026-2027',
          startDate: DateTime(2026, 9),
          endDate: DateTime(2027, 6, 30),
        ),
      );
      for (final (id, name) in [('s1', 'Léa'), ('s2', 'Théo')]) {
        await repos.students.create(
          Student.enroll(
            id: StudentId(id),
            firstName: name,
            audience: Audience.children,
            since: DateTime(2026, 9),
          ),
        );
      }
      var g1 = _group('g1');
      for (final student in ['s1', 's2']) {
        g1 = g1.admit(
          studentId: StudentId(student),
          studentAudience: Audience.children,
          from: DateTime(2026, 9),
        );
      }
      await repos.groups.save(g1);
      await repos.groups.save(_group('g2'));
      for (final (id, group) in [('x1', 'g1'), ('x2', 'g2')]) {
        await repos.sessionRecords.save(
          _record(id, group, present: id == 'x1' ? {'s1', 's2'} : {'s1'}),
        );
      }
    });

    tearDown(() async {
      for (final log in logs) {
        await log.cancel();
      }
      logs.clear();
      await repos.close();
    });

    StreamLog<T> listen<T>(Stream<T> stream) {
      final log = StreamLog<T>(stream);
      logs.add(log as StreamLog<Object?>);
      return log;
    }

    List<String> ids<T>(Iterable<T> items, String Function(T) id) => [
      for (final item in items) id(item),
    ];

    group('élèves', () {
      test('watchAll starts with the club and follows every change', () async {
        final log = listen(repos.students.watchAll());
        await log.settle();
        expect(ids(log.last, (s) => s.id.value), ['s1', 's2']);

        await repos.students.create(
          Student.enroll(
            id: const StudentId('s3'),
            firstName: 'Zoé',
            audience: Audience.children,
            since: DateTime(2026, 9),
          ),
        );
        await log.settle();
        expect(ids(log.last, (s) => s.id.value).toSet(), {'s1', 's2', 's3'});

        await repos.students.delete(const StudentId('s2'));
        await log.settle();
        expect(ids(log.last, (s) => s.id.value).toSet(), {'s1', 's3'});
      });

      test('watchById follows one student and says when it is gone', () async {
        final log = listen(repos.students.watchById(const StudentId('s1')));
        await log.settle();
        expect(log.last!.firstName, 'Léa');

        await repos.students.create(
          Student.enroll(
            id: const StudentId('s1'),
            firstName: 'Léa B.',
            audience: Audience.children,
            since: DateTime(2026, 9),
          ),
        );
        await log.settle();
        expect(log.last!.firstName, 'Léa B.');

        await repos.students.delete(const StudentId('s1'));
        await log.settle();
        expect(log.last, isNull);
      });

      test('watchById ignores the other students', () async {
        final log = listen(repos.students.watchById(const StudentId('s1')));
        await log.settle();
        final before = log.last;

        await repos.students.delete(const StudentId('s2'));
        await log.settle();

        expect(log.last, before);
      });
    });

    group('groupes', () {
      test('watchAll follows group changes, members included', () async {
        final log = listen(repos.groups.watchAll());
        await log.settle();
        expect(ids(log.last, (g) => g.id.value).toSet(), {'g1', 'g2'});

        await repos.groups.save(_group('g3'));
        await log.settle();
        expect(ids(log.last, (g) => g.id.value).toSet(), {'g1', 'g2', 'g3'});

        await repos.groups.delete(const GroupId('g2'));
        await log.settle();
        expect(ids(log.last, (g) => g.id.value).toSet(), {'g1', 'g3'});
      });

      test('watchById follows the roster of one group', () async {
        final log = listen(repos.groups.watchById(const GroupId('g2')));
        await log.settle();
        expect(log.last!.memberships, isEmpty);

        await repos.groups.save(
          _group('g2').admit(
            studentId: const StudentId('s1'),
            studentAudience: Audience.children,
            from: DateTime(2026, 10),
          ),
        );
        await log.settle();

        expect(log.last!.memberships, hasLength(1));
      });
    });

    group('séances planifiées', () {
      test('watchAll follows additions and deletions', () async {
        final log = listen(repos.sessions.watchAll());
        await log.settle();
        expect(log.last, isEmpty);

        await repos.sessions.add(_planned('p1'));
        await log.settle();
        expect(ids(log.last, (s) => s.id), ['p1']);

        await repos.sessions.delete('p1');
        await log.settle();
        expect(log.last, isEmpty);
      });
    });

    group('séances données', () {
      test('watchForGroup follows the records of that group only', () async {
        final log = listen(
          repos.sessionRecords.watchForGroup(const GroupId('g1')),
        );
        await log.settle();
        expect(ids(log.last, (r) => r.id.value), ['x1']);

        await repos.sessionRecords.save(_record('x3', 'g1'));
        await repos.sessionRecords.save(_record('x4', 'g2'));
        await log.settle();

        expect(ids(log.last, (r) => r.id.value).toSet(), {'x1', 'x3'});
      });

      test(
        'watchForStudent follows the sittings the student attends',
        () async {
          final log = listen(
            repos.sessionRecords.watchForStudent(const StudentId('s2')),
          );
          await log.settle();
          expect(ids(log.last, (r) => r.id.value), ['x1']);

          await repos.sessionRecords.save(_record('x5', 'g1', present: {'s1'}));
          await repos.sessionRecords.save(
            _record('x6', 'g1', present: {'s1', 's2'}),
          );
          await log.settle();

          expect(ids(log.last, (r) => r.id.value).toSet(), {'x1', 'x6'});
        },
      );
    });

    group('passages', () {
      test('watchForStudent follows the attempts of that student', () async {
        final log = listen(
          repos.attempts.watchForStudent(const StudentId('s1')),
        );
        await log.settle();
        expect(log.last, isEmpty);

        await repos.attempts.add(_attempt('a1', 's1'));
        await repos.attempts.add(_attempt('a2', 's2'));
        await log.settle();
        expect(ids(log.last, (a) => a.id.value), ['a1']);

        await repos.attempts.delete(const AttemptId('a1'));
        await log.settle();
        expect(log.last, isEmpty);
      });

      test('watchForSession follows the attempts of that sitting', () async {
        final log = listen(
          repos.attempts.watchForSession(const SessionId('x1')),
        );
        await log.settle();

        await repos.attempts.add(_attempt('a1', 's1'));
        await repos.attempts.add(_attempt('a2', 's1', session: 'x2'));
        await log.settle();

        expect(ids(log.last, (a) => a.id.value), ['a1']);
      });

      test('a correction reaches the watcher', () async {
        await repos.attempts.add(_attempt('a1', 's1'));
        final log = listen(
          repos.attempts.watchForStudent(const StudentId('s1')),
        );
        await log.settle();

        await repos.attempts.correct(_attempt('a1', 's1', potted: 5));
        await log.settle();

        expect(log.last.single.potted, 5);
      });
    });

    group('tout le club', () {
      test('attempts.watchAll follows every attempt', () async {
        final log = listen(repos.attempts.watchAll());
        await log.settle();
        expect(log.last, isEmpty);

        await repos.attempts.add(_attempt('a1', 's1'));
        await repos.attempts.add(_attempt('a2', 's2'));
        await log.settle();

        expect(ids(log.last, (a) => a.id.value).toSet(), {'a1', 'a2'});
      });

      test('acquisitions.watchAll follows every acquired block', () async {
        final log = listen(repos.acquisitions.watchAll());
        await log.settle();

        await repos.acquisitions.add(_acquisition('q1', 's1'));
        await repos.acquisitions.add(_acquisition('q2', 's2'));
        await log.settle();

        expect(ids(log.last, (a) => a.id.value).toSet(), {'q1', 'q2'});
      });

      test('sessionRecords.watchAll follows every sitting', () async {
        final log = listen(repos.sessionRecords.watchAll());
        await log.settle();
        expect(ids(log.last, (r) => r.id.value).toSet(), {'x1', 'x2'});

        await repos.sessionRecords.delete(const SessionId('x2'));
        await log.settle();

        expect(ids(log.last, (r) => r.id.value), ['x1']);
      });
    });

    group('blocs acquis', () {
      test(
        'watchForStudent follows the acquisitions of that student',
        () async {
          final log = listen(
            repos.acquisitions.watchForStudent(const StudentId('s1')),
          );
          await log.settle();
          expect(log.last, isEmpty);

          await repos.acquisitions.add(_acquisition('q1', 's1'));
          await repos.acquisitions.add(_acquisition('q2', 's2'));
          await log.settle();
          expect(ids(log.last, (a) => a.id.value), ['q1']);

          await repos.acquisitions.delete(const AcquisitionId('q1'));
          await log.settle();
          expect(log.last, isEmpty);
        },
      );
    });

    group('acquittements', () {
      test(
        'watchForStudent follows the acknowledgements of that student',
        () async {
          final log = listen(
            repos.acknowledgements.watchForStudent(const StudentId('s1')),
          );
          await log.settle();
          expect(log.last, isEmpty);

          await repos.acknowledgements.add(_acknowledgement('k1', 's1'));
          await repos.acknowledgements.add(_acknowledgement('k2', 's2'));
          await log.settle();

          expect(ids(log.last, (a) => a.id.value), ['k1']);
        },
      );

      test('watchAll follows every acknowledgement of the club', () async {
        final log = listen(repos.acknowledgements.watchAll());
        await log.settle();

        await repos.acknowledgements.add(_acknowledgement('k1', 's1'));
        await repos.acknowledgements.add(_acknowledgement('k2', 's2'));
        await log.settle();
        expect(ids(log.last, (a) => a.id.value).toSet(), {'k1', 'k2'});

        await repos.acknowledgements.delete(const AcknowledgementId('k1'));
        await log.settle();
        expect(ids(log.last, (a) => a.id.value), ['k2']);
      });
    });

    group('bilans de maturité', () {
      test('watchForStudent follows the assessments of that student', () async {
        final log = listen(
          repos.assessments.watchForStudent(const StudentId('s1')),
        );
        await log.settle();
        expect(log.last, isEmpty);

        await repos.assessments.add(_assessment('b1', 's1'));
        await repos.assessments.add(_assessment('b2', 's2'));
        await log.settle();

        expect(ids(log.last, (a) => a.id.value), ['b1']);
      });
    });

    group('écoute', () {
      test('two watchers of the same data each get every change', () async {
        final first = listen(repos.students.watchAll());
        final second = listen(repos.students.watchAll());
        await first.settle();

        await repos.students.delete(const StudentId('s2'));
        await first.settle();

        expect(ids(first.last, (s) => s.id.value), ['s1']);
        expect(ids(second.last, (s) => s.id.value), ['s1']);
      });

      test('a cancelled watcher receives nothing more', () async {
        final log = listen(repos.students.watchAll());
        await log.settle();
        await log.cancel();
        final received = log.values.length;

        await repos.students.delete(const StudentId('s2'));
        await log.settle();

        expect(log.values, hasLength(received));
      });
    });
  });
}

Group _group(String id) => Group(
  id: GroupId(id),
  seasonId: const SeasonId('season'),
  name: 'Groupe $id',
  audience: Audience.children,
);

SessionRecord _record(
  String id,
  String group, {
  Set<String> present = const {'s1', 's2'},
}) => SessionRecord(
  id: SessionId(id),
  groupId: GroupId(group),
  seasonId: const SeasonId('season'),
  date: DateTime(2026, 10, 3),
  audience: Audience.children,
  present: {for (final name in present) StudentId(name)},
);

Session _planned(String id) => Session(
  id: id,
  title: id,
  date: DateTime(2026, 10, 12),
  audience: Audience.children,
  groupId: const GroupId('g1'),
);

ExerciseAttempt _attempt(
  String id,
  String student, {
  String session = 'x1',
  int potted = 3,
}) => ExerciseAttempt(
  id: AttemptId(id),
  studentId: StudentId(student),
  sessionId: SessionId(session),
  exercise: ExerciseRef(blockId: 'puissance', number: 2),
  date: DateTime(2026, 10, 3),
  potted: potted,
  total: 5,
);

BlockAcquisition _acquisition(String id, String student) => BlockAcquisition(
  id: AcquisitionId(id),
  studentId: StudentId(student),
  blockId: 'posture',
  date: DateTime(2026, 10, 5),
  source: AcquisitionSource.placement,
);

AlertAcknowledgement _acknowledgement(String id, String student) =>
    AlertAcknowledgement(
      id: AcknowledgementId(id),
      studentId: StudentId(student),
      exercise: ExerciseRef(blockId: 'puissance', number: 1),
      lastAttemptId: const AttemptId('p3'),
      date: DateTime(2026, 10, 5),
    );

MaturityAssessment _assessment(String id, String student) => MaturityAssessment(
  id: AssessmentId(id),
  studentId: StudentId(student),
  date: DateTime(2026, 10, 5),
  concentration: 3,
  endurance: 2,
  frustration: 4,
);
