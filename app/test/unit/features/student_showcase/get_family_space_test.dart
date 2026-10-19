import 'dart:convert';
import 'dart:io';

import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/data/repository_group_names.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/membership/data/store_own_link_source.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/student_showcase/domain/family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/get_student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/domain/watch_family_space.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/device_document_store.dart';
import '../../../support/domain_world.dart';
import '../../../support/firestore_world.dart';
import '../../../support/fixed_clock.dart';

/// L'espace d'un parent ou d'un élève sur les **vrais dépôts Firestore** du
/// rôle (stock en mémoire) : ce qu'il montre, et surtout ce qu'il ne lit ni
/// n'affiche jamais.
class _Sessions extends Mock implements SessionRepository;

void main() {
  late FirestoreWorld world;
  late DeviceDocumentStore device;
  late SessionScope scope;
  late GetFamilySpace get;
  late GetFamilySpace Function(DateTime now, {SessionRepository? sessions})
  getAt;
  late WatchFamilySpace watch;
  late StoreOwnLinkSource link;

  Session session(String id, int day, String group, {int month = 10}) =>
      Session(
        id: id,
        title: 'Séance $id',
        date: DateTime(2026, month, day),
        audience: Audience.children,
        groupId: GroupId(group),
      );

  setUp(() async {
    world = FirestoreWorld()..act('c1', Role.director);
    scope = world.scope;
    final seed = world.club;
    await FirestoreSeasonRepository(seed).save(
      Season(
        id: const SeasonId('season'),
        label: '2026-2027',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2027, 6, 30),
      ),
    );
    final students = FirestoreStudentRepository(seed);
    for (final (id, name) in [('s1', 'Léa'), ('s2', 'Théo'), ('s3', 'Marc')]) {
      await students.save(
        Student.enroll(
          id: StudentId(id),
          firstName: name,
          audience: Audience.children,
          since: DateTime(2026, 9),
        ),
      );
    }
    final groups = FirestoreGroupRepository(seed);
    for (final (id, members) in [
      ('g1', ['s1', 's2']),
      ('g2', ['s3']),
    ]) {
      var group = Group(
        id: GroupId(id),
        seasonId: const SeasonId('season'),
        name: 'Groupe $id',
        audience: Audience.children,
      );
      for (final member in members) {
        group = group.admit(
          studentId: StudentId(member),
          studentAudience: Audience.children,
          from: DateTime(2026, 9),
        );
      }
      await groups.save(group);
    }
    final sessions = FirestoreSessionRepository(seed);
    for (final planned in [
      // Les identifiants vont à l'inverse des dates : le tri ne peut pas venir
      // de l'ordre du stock.
      session('passee', 5, 'g1'),
      session('veille', 11, 'g1'),
      session('z-aujourdhui', 12, 'g1'),
      session('lendemain', 13, 'g1'),
      session('a-prochaine', 14, 'g1'),
      session('autre-groupe', 13, 'g2'),
    ]) {
      await sessions.add(planned);
    }
    final records = FirestoreSessionRecordRepository(seed);
    for (final (id, group, present) in [
      ('x1', 'g1', 's1'),
      ('x2', 'g2', 's3'),
    ]) {
      await records.save(
        SessionRecord(
          id: SessionId(id),
          groupId: GroupId(group),
          seasonId: const SeasonId('season'),
          date: DateTime(2026, 10, 3),
          audience: Audience.children,
          present: {StudentId(present)},
        ),
      );
    }
    await FirestoreAttemptRepository(seed).add(
      ExerciseAttempt(
        id: const AttemptId('a1'),
        studentId: const StudentId('s1'),
        sessionId: const SessionId('x1'),
        exercise: ExerciseRef(blockId: 'a', number: 1),
        date: DateTime(2026, 10, 3),
        potted: 3,
        total: 5,
      ),
    );
    await FirestoreAttemptRepository(seed).add(
      ExerciseAttempt(
        id: const AttemptId('a3'),
        studentId: const StudentId('s3'),
        sessionId: const SessionId('x2'),
        exercise: ExerciseRef(blockId: 'a', number: 1),
        date: DateTime(2026, 10, 3),
        potted: 3,
        total: 5,
      ),
    );

    // L'appareil de la famille : ses lectures sont journalisées.
    device = DeviceDocumentStore(world.documents);
    final club = ClubStore(device, scope);
    final local = DomainWorld();
    final students1 = FirestoreStudentRepository(club);
    final attempts = FirestoreAttemptRepository(club);
    final acquisitions = FirestoreAcquisitionRepository(club);
    final sessions1 = FirestoreSessionRepository(club);
    final names = RepositoryGroupNames(FirestoreGroupRepository(club));
    link = StoreOwnLinkSource(club, scope);
    watch = WatchFamilySpace(
      students1,
      attempts,
      acquisitions,
      sessions1,
      names,
      link,
      scope,
    );
    getAt = (now, {sessions}) => GetFamilySpace(
      students1,
      GetStudentShowcase(
        students1,
        FirestoreAttemptRepository(club),
        FirestoreAcquisitionRepository(club),
        local.catalogueRepository,
        local.config,
      ),
      sessions ?? FirestoreSessionRepository(club),
      RepositoryGroupNames(FirestoreGroupRepository(club)),
      scope,
      scope,
      FixedClock(now),
    );
    get = getAt(DateTime(2026, 10, 12, 9, 30));
  });

  void asFamily(
    Role role, {
    required List<String> students,
    List<String> groups = const ['g1'],
  }) => scope.activate(
    const ClubId('c1'),
    role,
    groupIds: [for (final id in groups) GroupId(id)],
    studentIds: [for (final id in students) StudentId(id)],
  );

  Future<FamilySpace> open() => get().then<FamilySpace>(ok);

  test(
    'a parent sees each linked child, in link order, with the path',
    () async {
      asFamily(Role.guardian, students: ['s2', 's1']);

      final space = await open();

      expect([for (final c in space.children) c.firstName], ['Théo', 'Léa']);
      expect(
        space.children.last.showcase.toStart,
        isFalse,
        reason: 'Léa a un passage',
      );
      expect(space.children.first.showcase.toStart, isTrue);
    },
  );

  test(
    'the next sessions: groups of the account, from today (yesterday out, '
    'tomorrow in), in date order whatever the order of the identifiers',
    () async {
      asFamily(Role.guardian, students: ['s1']);

      final space = await open();

      expect(
        [for (final s in space.upcoming) s.id],
        ['z-aujourdhui', 'lendemain', 'a-prochaine'],
      );
      expect(space.upcoming.first.groupName, 'Groupe g1');
    },
  );

  test(
    'the order is the use case own: a repository may give any order',
    () async {
      final sessions = _Sessions();
      when(sessions.getAll).thenAnswer(
        (_) async => [
          session('tard', 20, 'g1'),
          session('tot', 13, 'g1'),
          session('milieu', 16, 'g1'),
        ],
      );
      asFamily(Role.guardian, students: ['s1']);

      final space = await getAt(
        DateTime(2026, 10, 12),
        sessions: sessions,
      ).call().then(ok);

      expect([for (final s in space.upcoming) s.id], ['tot', 'milieu', 'tard']);
    },
  );

  test('late on the day itself, today is still shown', () async {
    asFamily(Role.guardian, students: ['s1']);

    final space = await getAt(DateTime(2026, 10, 12, 23, 59)).call().then(ok);

    expect(
      [for (final s in space.upcoming) s.id],
      ['z-aujourdhui', 'lendemain', 'a-prochaine'],
    );
  });

  group('at most five sessions are shown, the earliest ones', () {
    /// [count] séances du groupe `gb` aux jours 14, 15, ... (identifiants à
    /// l'inverse des dates) ; ce que l'espace en montre.
    Future<List<String>> shown(int count) async {
      world.act('c1', Role.director);
      await FirestoreGroupRepository(world.club).save(
        Group(
          id: const GroupId('gb'),
          seasonId: const SeasonId('season'),
          name: 'Groupe gb',
          audience: Audience.children,
        ),
      );
      for (var n = 0; n < count; n++) {
        await FirestoreSessionRepository(world.club)
            .add(session('k${9 - n}', 14 + n, 'gb'));
      }
      asFamily(Role.guardian, students: ['s1'], groups: ['gb']);
      return [for (final s in (await open()).upcoming) s.id];
    }

    test('four sessions give four', () async {
      expect(await shown(4), ['k9', 'k8', 'k7', 'k6']);
    });

    test('five sessions give five', () async {
      expect(await shown(5), ['k9', 'k8', 'k7', 'k6', 'k5']);
    });

    test('six sessions give five, the latest one left out', () async {
      expect(await shown(6), ['k9', 'k8', 'k7', 'k6', 'k5']);
    });
  });

  test('a student sees only their own fiche', () async {
    asFamily(Role.student, students: ['s1']);

    expect([for (final c in (await open()).children) c.firstName], ['Léa']);
  });

  test('a linked fiche that does not exist is skipped', () async {
    asFamily(Role.guardian, students: ['s1', 'inconnue']);

    expect([for (final c in (await open()).children) c.firstName], ['Léa']);
  });

  test('without sessions the list is empty', () async {
    asFamily(Role.guardian, students: ['s1'], groups: ['g-vide']);

    expect((await open()).upcoming, isEmpty);
  });

  test('never asks for another child, a list, a record or a write', () async {
    asFamily(Role.guardian, students: ['s1']);

    await open();

    final requests = device.requests;
    expect(requests, isNotEmpty);
    expect(
      requests.where((r) => r.contains('s2') || r.contains('s3')),
      isEmpty,
    );
    expect(requests.where((r) => r.startsWith('write ')), isEmpty);
    expect(requests.where((r) => r.startsWith('list ')), isEmpty);
    for (final hidden in [
      'records',
      'assessments',
      'acknowledgements',
      'memberships',
    ]) {
      expect(
        requests.where((r) => r.contains(hidden)),
        isEmpty,
        reason: hidden,
      );
    }
    expect(requests, contains('get clubs/c1/students/s1'));
  });

  group('the changes of the family space', () {
    /// Écrit pour [student] comme le ferait l'animateur, sur un AUTRE appareil
    /// du même club (portée à part : celle de la famille reste ouverte).
    Future<void> coachAddsAnAttempt(String student) async {
      final coach = SessionScope()
        ..signIn(const UserId('u-coach'))
        ..activate(const ClubId('c1'), Role.director);
      await FirestoreAttemptRepository(ClubStore(world.documents, coach)).add(
        ExerciseAttempt(
          id: AttemptId('new-$student'),
          studentId: StudentId(student),
          sessionId: const SessionId('x1'),
          exercise: ExerciseRef(blockId: 'a', number: 2),
          date: DateTime(2026, 10, 12),
          potted: 5,
          total: 5,
        ),
      );
    }

    for (final student in ['s1', 's2']) {
      test('follow a pass of $student, whichever of two children', () async {
        asFamily(Role.guardian, students: ['s1', 's2']);
        var events = 0;
        final subscription = watch().listen((_) => events++);
        await pumpEventQueue();
        final before = events;

        await coachAddsAnAttempt(student);
        await pumpEventQueue();
        await subscription.cancel();

        expect(events, greaterThan(before));
      });
    }
  });

  group('only the still linked children', () {
    test('are read when the account lists fewer than its session', () async {
      asFamily(Role.guardian, students: ['s1', 's2']);

      final space = await get(linked: {const StudentId('s1')})
          .then<FamilySpace>(ok);

      expect([for (final c in space.children) c.firstName], ['Léa']);
      expect(device.requests.where((r) => r.contains('s2')), isEmpty);
    });

    test(
      'are all the children of the session when not told otherwise',
      () async {
        asFamily(Role.guardian, students: ['s1', 's2']);

        expect(
          [for (final c in (await open()).children) c.firstName],
          ['Léa', 'Théo'],
        );
      },
    );
  });

  test('a teacher has no family space', () async {
    scope.activate(const ClubId('c1'), Role.teacher);

    expect(
      err(await get()),
      isA<InvariantViolation>().having(
        (e) => e.code,
        'code',
        InvariantCode.actionNotAllowed,
      ),
    );
  });

  test(
    'a refusal of the server is a denied failure, not an unreachable one',
    () async {
      asFamily(Role.guardian, students: ['s1']);
      world.documents.revoke('clubs/c1/students');

      expect(
        err(await get()),
        isA<ServiceFailure>().having(
          (e) => e.code,
          'code',
          ServiceFailureCode.denied,
        ),
      );
    },
  );

  test('an unreachable server is an unavailable failure', () async {
    asFamily(Role.guardian, students: ['s1']);
    device.goOffline();

    expect(
      err(await get()),
      isA<ServiceFailure>().having(
        (e) => e.code,
        'code',
        ServiceFailureCode.unavailable,
      ),
    );
  });

  test('asks for nothing but the reads of family_reads.json, which the rules '
      'test plays against the real rules', () async {
    final listed =
        (jsonDecode(
              File('../scripts/rules_test/family_reads.json')
                  .readAsStringSync(),
            ) as Map<String, Object?>)['famille']!
            as List<Object?>;
    final expected = {
      for (final template in listed)
        (template! as String)
            .replaceAll('{club}', 'c1')
            .replaceAll('{student}', 's1')
            .replaceAll('{group}', 'g1')
            .replaceAll('{uid}', 'u-dir'),
    };
    asFamily(Role.guardian, students: ['s1']);

    await open();
    await link.read();
    final changes = watch().listen((_) {});
    await pumpEventQueue();
    await changes.cancel();

    final actual = device.requests.toSet();
    expect(
      actual.difference(expected),
      isEmpty,
      reason: 'demandes non listées',
    );
    // Les réglages du club sont lus par `ReloadRules`, hors de cet espace.
    expect(expected.difference(actual), {
      'get clubs/c1/settings/main',
    }, reason: "entrées de la liste que l'application ne demande plus");
  });
}
