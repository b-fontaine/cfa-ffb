import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/firestore_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/firestore_world.dart';
import '../../../support/stream_log.dart';

/// Les `watch…` des dépôts Firestore **par rôle** : chaque rôle ne suit que ce
/// que les règles lui laissent lire (la même requête que sa lecture `Future`,
/// jamais la collection entière pour un enseignant ou un parent), et ne reçoit
/// que les documents de son périmètre. Les règles elles-mêmes sont jouées
/// contre l'émulateur (`scripts/rules_test/watch.test.mjs`).
void main() {
  late FirestoreWorld world;
  late FirestoreStudentRepository students;
  late FirestoreGroupRepository groups;
  late FirestoreSessionRepository sessions;
  late FirestoreSessionRecordRepository records;
  late FirestoreAttemptRepository attempts;
  late FirestoreAcquisitionRepository acquisitions;
  late FirestoreAcknowledgementRepository acknowledgements;
  late FirestoreAssessmentRepository assessments;
  final logs = <StreamLog<Object?>>[];

  StreamLog<T> listen<T>(Stream<T> stream) {
    final log = StreamLog<T>(stream);
    logs.add(log as StreamLog<Object?>);
    return log;
  }

  setUp(() async {
    world = FirestoreWorld()..act('c1', Role.director);
    final club = world.club;
    students = FirestoreStudentRepository(club);
    groups = FirestoreGroupRepository(club);
    sessions = FirestoreSessionRepository(club);
    records = FirestoreSessionRecordRepository(club);
    attempts = FirestoreAttemptRepository(club);
    acquisitions = FirestoreAcquisitionRepository(club);
    acknowledgements = FirestoreAcknowledgementRepository(club, world.scope);
    assessments = FirestoreAssessmentRepository(club);

    await FirestoreSeasonRepository(club).save(
      Season(
        id: const SeasonId('season'),
        label: '2026-2027',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2027, 6, 30),
      ),
    );
    for (final (id, name) in [('s1', 'Léa'), ('s2', 'Théo'), ('s3', 'Marc')]) {
      await students.create(
        Student.enroll(
          id: StudentId(id),
          firstName: name,
          audience: Audience.children,
          since: DateTime(2026, 9),
        ),
      );
    }
    for (final (group, members) in [
      ('g1', ['s1', 's2']),
      ('g2', ['s3']),
    ]) {
      var value = Group(
        id: GroupId(group),
        seasonId: const SeasonId('season'),
        name: 'Groupe $group',
        audience: Audience.children,
      );
      for (final student in members) {
        value = value.admit(
          studentId: StudentId(student),
          studentAudience: Audience.children,
          from: DateTime(2026, 9),
        );
      }
      await groups.save(value);
    }
    for (final (id, group, present) in [
      ('x1', 'g1', {'s1', 's2'}),
      ('x2', 'g2', {'s3'}),
    ]) {
      await records.save(
        SessionRecord(
          id: SessionId(id),
          groupId: GroupId(group),
          seasonId: const SeasonId('season'),
          date: DateTime(2026, 10, 3),
          audience: Audience.children,
          present: {for (final name in present) StudentId(name)},
        ),
      );
      await sessions.add(
        Session(
          id: 'p-$id',
          title: id,
          date: DateTime(2026, 10, 12),
          audience: Audience.children,
          groupId: GroupId(group),
        ),
      );
    }
    for (final (id, student, session) in [
      ('a1', 's1', 'x1'),
      ('a2', 's3', 'x2'),
    ]) {
      await attempts.add(
        ExerciseAttempt(
          id: AttemptId(id),
          studentId: StudentId(student),
          sessionId: SessionId(session),
          exercise: ExerciseRef(blockId: 'puissance', number: 1),
          date: DateTime(2026, 10, 3),
          potted: 3,
          total: 5,
        ),
      );
    }
    for (final (id, student) in [('q1', 's1'), ('q2', 's3')]) {
      await acquisitions.add(
        BlockAcquisition(
          id: AcquisitionId(id),
          studentId: StudentId(student),
          blockId: 'posture',
          date: DateTime(2026, 10, 5),
          source: AcquisitionSource.placement,
        ),
      );
      await assessments.add(
        MaturityAssessment(
          id: AssessmentId('b-$id'),
          studentId: StudentId(student),
          date: DateTime(2026, 10, 5),
          concentration: 3,
          endurance: 2,
          frustration: 4,
        ),
      );
      await acknowledgements.add(
        AlertAcknowledgement(
          id: AcknowledgementId('k-$id'),
          studentId: StudentId(student),
          exercise: ExerciseRef(blockId: 'puissance', number: 1),
          lastAttemptId: const AttemptId('p3'),
          date: DateTime(2026, 10, 5),
        ),
      );
    }
    world.documents.watchLog.clear();
  });

  tearDown(() async {
    for (final log in logs) {
      await log.cancel();
    }
    logs.clear();
    expect(world.documents.activeWatchers, 0);
  });

  List<String> ids<T>(List<T> items, String Function(T) id) =>
      [for (final item in items) id(item)]..sort();

  group('a director', () {
    test('follows whole collections', () async {
      world.act('c1', Role.director);

      listen(students.watchAll());
      listen(groups.watchAll());
      listen(sessions.watchAll());
      listen(acknowledgements.watchAll());
      await pumpEventQueue();

      expect(world.documents.watchLog, [
        'collection clubs/c1/students',
        'collection clubs/c1/groups',
        'collection clubs/c1/memberships',
        'collection clubs/c1/sessions',
        'collection clubs/c1/acknowledgements',
      ]);
    });

    test('follows a student through the student queries', () async {
      listen(attempts.watchForStudent(const StudentId('s1')));
      listen(acquisitions.watchForStudent(const StudentId('s1')));
      listen(records.watchForStudent(const StudentId('s1')));
      await pumpEventQueue();

      expect(world.documents.watchLog, [
        'query clubs/c1/attempts studentId=s1',
        'query clubs/c1/acquisitions studentId=s1',
        'query clubs/c1/records presentStudentIds any s1',
      ]);
    });
  });

  group('a teacher of g1', () {
    setUp(() => world.act('c1', Role.teacher, groups: ['g1']));

    test('follows the students of her groups, never the collection', () async {
      final log = listen(students.watchAll());
      await log.settle();

      expect(world.documents.watchLog, [
        'query clubs/c1/students groupIds any g1',
      ]);
      expect(ids(log.last, (s) => s.id.value), ['s1', 's2']);
    });

    test('cuts a 31 groups list in queries of 30', () async {
      world.act(
        'c1',
        Role.teacher,
        groups: [for (var i = 0; i < 31; i++) 'g$i'],
      );

      listen(students.watchAll());
      await pumpEventQueue();

      expect(world.documents.watchLog, hasLength(2));
    });

    test(
      'receives a student who joins her group, written by a director elsewhere',
      () async {
        final log = listen(students.watchAll());
        await log.settle();

        // Un autre appareil : le directeur du même club, sur le même serveur.
        final directorScope = SessionScope()
          ..signIn(const UserId('u-dir'))
          ..activate(const ClubId('c1'), Role.director);
        final elsewhere = ClubStore(world.documents, directorScope);
        final directorGroups = FirestoreGroupRepository(elsewhere);
        await directorGroups.save(
          (await directorGroups.byId(const GroupId('g1')))!.admit(
            studentId: const StudentId('s3'),
            studentAudience: Audience.children,
            from: DateTime(2026, 10),
          ),
        );
        await log.settle();

        expect(ids(log.last, (s) => s.id.value), ['s1', 's2', 's3']);
      },
    );

    test('follows the group document and its memberships', () async {
      final log = listen(groups.watchAll());
      await log.settle();

      expect(world.documents.watchLog, [
        'document clubs/c1/groups/g1',
        'query clubs/c1/memberships groupId=g1',
      ]);
      expect(ids(log.last, (g) => g.id.value), ['g1']);
      expect(log.last.single.memberships, hasLength(2));
    });

    test('follows the sessions of her groups one query each', () async {
      final log = listen(sessions.watchAll());
      await log.settle();

      expect(world.documents.watchLog, ['query clubs/c1/sessions groupId=g1']);
      expect(ids(log.last, (s) => s.id), ['p-x1']);
    });

    test('follows the sittings of a group and of a student', () async {
      final group = listen(records.watchForGroup(const GroupId('g1')));
      final student = listen(records.watchForStudent(const StudentId('s2')));
      await group.settle();

      expect(world.documents.watchLog, [
        'query clubs/c1/records groupId=g1',
        'query clubs/c1/records groupId=g1',
      ]);
      expect(ids(group.last, (r) => r.id.value), ['x1']);
      expect(ids(student.last, (r) => r.id.value), ['x1']);
    });

    test('follows the data of a student inside her groups', () async {
      listen(attempts.watchForStudent(const StudentId('s1')));
      listen(attempts.watchForSession(const SessionId('x1')));
      listen(acquisitions.watchForStudent(const StudentId('s1')));
      listen(assessments.watchForStudent(const StudentId('s1')));
      listen(acknowledgements.watchForStudent(const StudentId('s1')));
      listen(acknowledgements.watchAll());
      await pumpEventQueue();

      expect(world.documents.watchLog, [
        'query clubs/c1/attempts groupId=g1,studentId=s1',
        'query clubs/c1/attempts groupId=g1,sessionId=x1',
        'query clubs/c1/acquisitions groupId=g1,studentId=s1',
        'query clubs/c1/assessments groupId=g1,studentId=s1',
        'query clubs/c1/acknowledgements groupId=g1,studentId=s1',
        'query clubs/c1/acknowledgements groupId=g1',
      ]);
    });

    test('never receives the data of another group', () async {
      final log = listen(attempts.watchForStudent(const StudentId('s3')));
      await log.settle();

      expect(log.last, isEmpty);
    });
  });

  group('a guardian of s1', () {
    setUp(() => world.act('c1', Role.guardian, students: ['s1']));

    test('follows her linked students one document each', () async {
      final log = listen(students.watchAll());
      await log.settle();

      expect(world.documents.watchLog, ['document clubs/c1/students/s1']);
      expect(ids(log.last, (s) => s.id.value), ['s1']);
    });

    test('follows the group without its memberships', () async {
      world.act('c1', Role.guardian, students: ['s1'], groups: ['g1']);

      final log = listen(groups.watchAll());
      await log.settle();

      expect(world.documents.watchLog, ['document clubs/c1/groups/g1']);
      expect(log.last.single.memberships, isEmpty);
    });

    test(
      'follows the acquired blocks and the attempts of the linked student only',
      () async {
        final blocks = listen(
          acquisitions.watchForStudent(const StudentId('s1')),
        );
        final own = listen(attempts.watchForStudent(const StudentId('s1')));
        final other = listen(attempts.watchForStudent(const StudentId('s3')));
        await blocks.settle();

        expect(world.documents.watchLog, [
          'query clubs/c1/acquisitions studentId=s1',
          'query clubs/c1/attempts studentId=s1',
        ]);
        expect(ids(blocks.last, (a) => a.id.value), ['q1']);
        expect(ids(own.last, (a) => a.id.value), ['a1']);
        expect(other.last, isEmpty);
      },
    );

    test('follows nothing the rules hide from her', () async {
      final sittings = listen(records.watchForGroup(const GroupId('g1')));
      final sittingsOfStudent = listen(
        records.watchForStudent(const StudentId('s1')),
      );
      final marks = listen(assessments.watchForStudent(const StudentId('s1')));
      final seen = listen(
        acknowledgements.watchForStudent(const StudentId('s1')),
      );
      await sittings.settle();

      expect(world.documents.watchLog, isEmpty);
      expect(sittings.last, isEmpty);
      expect(sittingsOfStudent.last, isEmpty);
      expect(marks.last, isEmpty);
      expect(seen.last, isEmpty);
    });
  });

  group('failures', () {
    test('a refusal is a ServiceFailure and closes only that flux', () async {
      final refused = listen(sessions.watchAll());
      final other = listen(groups.watchAll());
      await refused.settle();

      world.documents.revoke('clubs/c1/sessions');
      await refused.settle();
      await groups.save(
        (await groups.byId(const GroupId('g2')))!.rename('Renommé'),
      );
      await refused.settle();

      expect(
        refused.errors.single,
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.denied,
        ),
      );
      expect(refused.done, isTrue);
      expect(other.errors, isEmpty);
      expect(other.done, isFalse);
      expect(other.last.firstWhere((g) => g.id.value == 'g2').name, 'Renommé');
    });

    test('a network failure at the opening arrives on the flux', () async {
      world.documents.failing = StoreFailureCode.unavailable;

      final log = listen(students.watchById(const StudentId('s1')));
      await log.settle();

      expect(
        log.errors.single,
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.unavailable,
        ),
      );
      expect(log.done, isTrue);
    });

    test(
      'without an active club the flux fails with denied, never a guessed path',
      () async {
        world.scope.deactivateClub();

        final log = listen(students.watchAll());
        await log.settle();

        expect(
          log.errors.single,
          isA<ServiceFailure>().having(
            (f) => f.detail,
            'detail',
            'no-active-club',
          ),
        );
        expect(world.documents.watchLog, isEmpty);
      },
    );

    test('a flux closes when the member changes club', () async {
      final log = listen(students.watchAll());
      await log.settle();

      world.act('c2', Role.director);
      world.documents.seed('clubs/c1/students/s9', {'firstName': 'Intrus'});
      await log.settle();

      expect(log.errors.single, isA<ServiceFailure>());
      expect(log.done, isTrue);
      expect([
        for (final batch in log.values)
          for (final s in batch) s.id.value,
      ], isNot(contains('s9')));
    });
  });
}
