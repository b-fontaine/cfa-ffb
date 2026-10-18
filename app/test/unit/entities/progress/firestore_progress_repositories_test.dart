import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/attempt_document.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/firestore_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Enregistre les écritures et les requêtes : ce que chaque rôle demande au
/// serveur, et dans quelle forme.
class _Spy extends InMemoryDocumentStore {
  final List<WriteOp> sent = [];

  /// Hors ligne : seuls les documents du cache (qui existent) se lisent ; la
  /// lecture d'un document **absent** échoue (`unavailable`).
  bool offline = false;

  @override
  Future<StoredDocument?> get(String path) async {
    final found = await super.get(path);
    if (offline && found == null) {
      throw const StoreFailure(StoreFailureCode.unavailable, 'hors ligne');
    }
    return found;
  }

  @override
  Future<void> commit(List<WriteOp> operations) {
    sent.addAll(operations);
    return super.commit(operations);
  }
}

ExerciseAttempt _attempt(
  String id, {
  String student = 's1',
  String session = 'x1',
  int potted = 4,
}) => ExerciseAttempt(
  id: AttemptId(id),
  studentId: StudentId(student),
  sessionId: SessionId(session),
  exercise: ExerciseRef(blockId: 'puissance', number: 1),
  date: DateTime(2026, 10, 3),
  potted: potted,
  total: 5,
);

BlockAcquisition _acquisition(String id, {String student = 's1'}) =>
    BlockAcquisition(
      id: AcquisitionId(id),
      studentId: StudentId(student),
      blockId: 'puissance',
      date: DateTime(2026, 9, 15),
      source: AcquisitionSource.placement,
    );

MaturityAssessment _assessment(String id, {String student = 's1'}) =>
    MaturityAssessment(
      id: AssessmentId(id),
      studentId: StudentId(student),
      date: DateTime(2026, 10, 5),
      concentration: 3,
      endurance: 2,
      frustration: 4,
      comment: 'Calme',
    );

AlertAcknowledgement _acknowledgement(
  String id, {
  String student = 's1',
  String lastAttempt = 'a1',
}) => AlertAcknowledgement(
  id: AcknowledgementId(id),
  studentId: StudentId(student),
  exercise: ExerciseRef(blockId: 'puissance', number: 1),
  lastAttemptId: AttemptId(lastAttempt),
  date: DateTime(2026, 10, 5),
);

void main() {
  late _Spy documents;
  late SessionScope scope;
  late ClubStore club;

  /// Le club `c1` : saison `se1` (ouverte) et `se0` (close), groupes `g1`
  /// (saison `se1`) et `g2` (saison `se1`), fiches `s1` (g1), `s2` (g2),
  /// `s3` (g1 et g2) ; séances `x1` (g1) et `x2` (g2).
  setUp(() {
    documents = _Spy()..serverNow = () => DateTime.utc(2026, 10, 12, 8);
    scope = SessionScope()..signIn(const UserId('u-dir'));
    club = ClubStore(documents, scope);
    documents
      ..seed('clubs/c1/seasons/se1', {
        'startDate': '2026-09-01T00:00:00.000',
        'closedOn': null,
      })
      ..seed('clubs/c1/seasons/se0', {
        'startDate': '2025-09-01T00:00:00.000',
        'closedOn': '2026-06-30T00:00:00.000',
      })
      ..seed('clubs/c1/groups/g1', {'seasonId': 'se1'})
      ..seed('clubs/c1/groups/g2', {'seasonId': 'se1'})
      ..seed('clubs/c1/groups/g0', {'seasonId': 'se0'})
      ..seed('clubs/c1/students/s1', {
        'groupIds': ['g1'],
      })
      ..seed('clubs/c1/students/s2', {
        'groupIds': ['g2'],
      })
      ..seed('clubs/c1/students/s3', {
        'groupIds': ['g0', 'g2', 'g1'],
      })
      ..seed('clubs/c1/students/s4', {'groupIds': <String>[]})
      ..seed('clubs/c1/records/x1', {'groupId': 'g1', 'seasonId': 'se1'})
      ..seed('clubs/c1/records/x2', {'groupId': 'g2', 'seasonId': 'se1'});
    scope.activate(const ClubId('c1'), Role.director);
  });

  void act(
    Role role, {
    List<String> groups = const [],
    List<String> students = const [],
  }) => scope.activate(
    const ClubId('c1'),
    role,
    groupIds: [for (final g in groups) GroupId(g)],
    studentIds: [for (final s in students) StudentId(s)],
  );

  group('FirestoreAttemptRepository', () {
    late FirestoreAttemptRepository repository;
    setUp(
      () => repository = FirestoreAttemptRepository(
        club,
        clock: _FixedClock(DateTime.utc(2026, 10, 12, 7, 59)),
      ),
    );

    test('writes exactly the fields the rules allow, with the group and '
        'season of the session and the server date', () async {
      await repository.add(_attempt('a1'));

      expect(documents.read('clubs/c1/attempts/a1'), {
        'groupId': 'g1',
        'seasonId': 'se1',
        'studentId': 's1',
        'sessionId': 'x1',
        'blockId': 'puissance',
        'exerciseNumber': 1,
        'date': '2026-10-03T00:00:00.000',
        'potted': 4,
        'total': 5,
        'createdAt': DateTime.utc(2026, 10, 12, 8),
        'recordedAt': DateTime.utc(2026, 10, 12, 7, 59),
      });
    });

    test(
      'stamps each new pass strictly after the previous one, even on the '
      'same clock reading: the local order survives the pending state',
      () async {
        await repository.add(_attempt('zz'));
        await repository.add(_attempt('aa'));

        DateTime stamp(String id) =>
            documents.read('clubs/c1/attempts/$id')!['recordedAt']! as DateTime;
        expect(stamp('aa').isAfter(stamp('zz')), isTrue);
      },
    );

    test('stores no rank: it is derived from the recording order', () async {
      await repository.add(_attempt('a1'));

      expect(
        documents.read('clubs/c1/attempts/a1'),
        isNot(contains('passIndex')),
      );
    });

    test('adds without reading first (offline, a read of an absent document '
        'would fail) and as a plain set, never a merge', () async {
      await repository.add(_attempt('a1'));

      final write = documents.sent.single as SetOp;
      expect(write.merge, isFalse);
      expect(write.path, 'clubs/c1/attempts/a1');
    });

    test('a pass of an unknown session is refused', () async {
      await expectLater(
        repository.add(_attempt('a1', session: 'unknown')),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.other,
          ),
        ),
      );
      expect(documents.read('clubs/c1/attempts/a1'), isNull);
    });

    test(
      'a correction writes the balls only, never the creation date',
      () async {
        await repository.add(_attempt('a1', potted: 1));
        documents.sent.clear();
        documents.serverNow = () => DateTime.utc(2027);

        await repository.correct(_attempt('a1', potted: 5));

        final update = documents.sent.single as UpdateOp;
        expect(update.fields, {'potted': 5, 'total': 5});
        final stored = documents.read('clubs/c1/attempts/a1')!;
        expect(stored['createdAt'], DateTime.utc(2026, 10, 12, 8));
        expect(stored['potted'], 5);
      },
    );

    test(
      'lists in the recording order: server date, then identifier',
      () async {
        documents
          ..seed('clubs/c1/attempts/zz', _stored('zz', DateTime.utc(2026, 10)))
          ..seed(
            'clubs/c1/attempts/aa',
            _stored('aa', DateTime.utc(2026, 10, 2)),
          )
          ..seed('clubs/c1/attempts/mm', _stored('mm', DateTime.utc(2026, 10)));

        final ids = (await repository.all()).map((a) => a.id.value);

        expect(ids, ['mm', 'zz', 'aa']);
      },
    );

    test('two passes recorded at the same instant keep a stable order on '
        'every device: the identifier decides', () async {
      final same = DateTime.utc(2026, 10, 1, 12);
      documents
        ..seed('clubs/c1/attempts/zz', _stored('zz', same))
        ..seed('clubs/c1/attempts/aa', _stored('aa', same));
      // Un second appareil : un autre dépôt sur les mêmes documents.
      final otherDevice = FirestoreAttemptRepository(
        ClubStore(documents, scope),
      );

      final here = (await repository.all()).map((a) => a.id.value);
      final there = (await otherDevice.all()).map((a) => a.id.value);

      expect(here, ['aa', 'zz']);
      expect(there, here);
      expect(passRanks(await repository.all()).values, [
        1,
        2,
      ], reason: 'the rank of a pass follows that order');
    });

    test('passes still pending (server date unknown) keep the order they were '
        'recorded in, whatever their identifiers', () async {
      documents
        ..seed(
          'clubs/c1/attempts/aa',
          _stored('aa', null, recordedAt: DateTime.utc(2026, 10, 12, 8, 0, 2)),
        )
        ..seed(
          'clubs/c1/attempts/zz',
          _stored('zz', null, recordedAt: DateTime.utc(2026, 10, 12, 8, 0, 1)),
        );

      final ids = (await repository.all()).map((a) => a.id.value);

      expect(ids, ['zz', 'aa']);
    });

    test('compare: same server date and same stamp, the identifier decides; '
        'a pending document is after a known one', () {
      final same = DateTime.utc(2026, 10, 1, 12);
      StoredDocument doc(String id, DateTime? created) =>
          StoredDocument('clubs/c1/attempts/$id', _stored(id, created));

      expect(
        AttemptDocument.compare(doc('zz', same), doc('aa', same)),
        greaterThan(0),
      );
      expect(
        ([
          doc('zz', same),
          doc('aa', same),
        ]..sort(AttemptDocument.compare)).map((d) => d.id),
        ['aa', 'zz'],
      );
      expect(
        AttemptDocument.compare(doc('aa', null), doc('zz', same)),
        greaterThan(0),
      );
      expect(
        AttemptDocument.compare(doc('zz', same), doc('aa', null)),
        lessThan(0),
      );
    });

    test('compare: a pass without device stamp comes before one with it on '
        'the same server date', () {
      final same = DateTime.utc(2026, 10, 1, 12);
      final bare = StoredDocument(
        'clubs/c1/attempts/zz',
        {..._stored('zz', same)}..remove('recordedAt'),
      );
      final stamped = StoredDocument(
        'clubs/c1/attempts/aa',
        _stored('aa', same, recordedAt: DateTime.utc(2026, 10, 1, 11)),
      );

      expect(AttemptDocument.compare(bare, stamped), lessThan(0));
      expect(AttemptDocument.compare(stamped, bare), greaterThan(0));
    });

    test('a pass whose server date is not known yet is the last', () async {
      documents
        ..seed('clubs/c1/attempts/pending', {..._stored('pending', null)})
        ..seed(
          'clubs/c1/attempts/aa',
          _stored('aa', DateTime.utc(2026, 10, 2)),
        );

      final ids = (await repository.all()).map((a) => a.id.value);

      expect(ids, ['aa', 'pending']);
    });

    test('a deletion removes one document and rewrites no other', () async {
      await repository.add(_attempt('a1'));
      await repository.add(_attempt('a2'));
      final before = documents.read('clubs/c1/attempts/a2');
      documents.sent.clear();

      await repository.delete(const AttemptId('a1'));

      expect(documents.sent.single, isA<DeleteOp>());
      expect(documents.read('clubs/c1/attempts/a1'), isNull);
      expect(documents.read('clubs/c1/attempts/a2'), before);
    });

    test('the codec names the malformed field, never a guessed value', () {
      final bad = StoredDocument('clubs/c1/attempts/bad', {
        ..._stored('bad', DateTime.utc(2026, 10)),
        'potted': 'many',
      });

      expect(
        () => AttemptDocument.decode(bad),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.detail,
            'detail',
            contains('potted'),
          ),
        ),
      );
    });

    group('reads, by role, only what the rules allow', () {
      setUp(() async {
        await repository.add(_attempt('a1'));
        await repository.add(_attempt('a2', student: 's2', session: 'x2'));
        await repository.add(_attempt('a3', student: 's3'));
        documents.queryLog.clear();
      });

      test(
        'a director lists the club and asks by student or session',
        () async {
          expect((await repository.all()).map((a) => a.id.value), [
            'a1',
            'a2',
            'a3',
          ]);
          expect(
            (await repository.forStudent(const StudentId('s1')))
                .map((a) => a.id.value),
            ['a1'],
          );
          expect(
            (await repository.forSession(const SessionId('x1')))
                .map((a) => a.id.value),
            ['a1', 'a3'],
          );
        },
      );

      test('a teacher asks one group at a time, proving the group in every '
          'query (a query on the student alone would be refused)', () async {
        act(Role.teacher, groups: ['g1']);

        final forStudent = await repository.forStudent(const StudentId('s1'));
        final forSession = await repository.forSession(const SessionId('x1'));
        final all = await repository.all();

        expect(forStudent.map((a) => a.id.value), ['a1']);
        expect(forSession.map((a) => a.id.value), ['a1', 'a3']);
        expect(all.map((a) => a.id.value), ['a1', 'a3']);
        for (final filter in documents.queryLog) {
          final fields = switch (filter) {
            AllEqual(:final clauses) => [for (final c in clauses) c.field],
            _ => [filter.field],
          };
          expect(fields, contains('groupId'));
        }
      });

      test('a teacher of another group reads nothing of this one', () async {
        act(Role.teacher, groups: ['g3']);

        expect(await repository.all(), isEmpty);
        expect(await repository.forStudent(const StudentId('s1')), isEmpty);
      });

      test('a parent or a student reads the linked student only, one query '
          'per student', () async {
        act(Role.guardian, groups: ['g1'], students: ['s1']);

        expect((await repository.all()).map((a) => a.id.value), ['a1']);
        expect(
          (await repository.forStudent(const StudentId('s1')))
              .map((a) => a.id.value),
          ['a1'],
        );
        expect(await repository.forStudent(const StudentId('s2')), isEmpty);
        expect(
          (await repository.forSession(const SessionId('x1')))
              .map((a) => a.id.value),
          ['a1'],
        );
        for (final filter in documents.queryLog) {
          final fields = switch (filter) {
            AllEqual(:final clauses) => [for (final c in clauses) c.field],
            _ => [filter.field],
          };
          expect(fields, contains('studentId'));
        }
      });
    });

    test(
      'erasing a student deletes their passes and keeps the others',
      () async {
        await repository.add(_attempt('a1'));
        await repository.add(_attempt('a2', student: 's2', session: 'x2'));

        await repository.eraseStudent(const StudentId('s1'));

        expect((await repository.all()).map((a) => a.id.value), ['a2']);
      },
    );
  });

  group('a malformed document does not hide the valid ones', () {
    // Les règles exigent des documents complets ; un document créé avant elles
    // ou par un autre client reste possible : il est écarté, la liste vit.
    test('attempts', () async {
      act(Role.director);
      documents
        ..seed('clubs/c1/attempts/ok', _stored('ok', DateTime.utc(2026, 10)))
        ..seed('clubs/c1/attempts/bad', {
          'groupId': 'g1',
          'seasonId': 'se1',
          'studentId': 's1',
          'createdAt': DateTime.utc(2026, 10, 2),
        });
      final repository = FirestoreAttemptRepository(club);

      expect((await repository.all()).map((a) => a.id.value), ['ok']);
      expect(
        (await repository.forStudent(const StudentId('s1')))
            .map((a) => a.id.value),
        ['ok'],
      );
    });

    test('attempts with a malformed sort field keep the rest', () async {
      act(Role.director);
      documents
        ..seed('clubs/c1/attempts/b2', _stored('b2', DateTime.utc(2026, 10, 3)))
        ..seed('clubs/c1/attempts/a1', _stored('a1', DateTime.utc(2026, 10)))
        // Champ de tri de mauvais type ou illisible : le tri ne doit pas lever.
        ..seed('clubs/c1/attempts/bad1', {
          ..._stored('bad1', DateTime.utc(2026, 10)),
          'createdAt': 42,
        })
        ..seed('clubs/c1/attempts/bad2', {
          ..._stored('bad2', DateTime.utc(2026, 10)),
          'recordedAt': 'pas une date',
        })
        ..seed('clubs/c1/attempts/bad3', {
          ..._stored('bad3', DateTime.utc(2026, 10)),
          'date': 'zz',
        });
      final repository = FirestoreAttemptRepository(club);

      expect((await repository.all()).map((a) => a.id.value), ['a1', 'b2']);
      expect(
        (await repository.forStudent(const StudentId('s1')))
            .map((a) => a.id.value),
        ['a1', 'b2'],
      );
      expect(
        (await repository.forSession(const SessionId('x1')))
            .map((a) => a.id.value),
        ['a1', 'b2'],
      );
    });

    test('markers, assessments and « Vu »', () async {
      act(Role.director);
      const bad = {'groupId': 'g1', 'seasonId': 'se1', 'studentId': 's1'};
      final acquisitions = FirestoreAcquisitionRepository(club);
      final assessments = FirestoreAssessmentRepository(club);
      final acknowledgements = FirestoreAcknowledgementRepository(club, scope);
      await acquisitions.add(_acquisition('q1'));
      await assessments.add(_assessment('b1'));
      await acknowledgements.add(_acknowledgement('k1'));
      documents
        ..seed('clubs/c1/acquisitions/bad', bad)
        ..seed('clubs/c1/assessments/bad', bad)
        ..seed('clubs/c1/acknowledgements/bad', bad);

      expect((await acquisitions.all()).map((a) => a.id.value), ['q1']);
      expect((await assessments.all()).map((a) => a.id.value), ['b1']);
      expect((await acknowledgements.all()).map((a) => a.id.value), ['k1']);
    });
  });

  group('offline (known limit, FB5): a creation reads its target first', () {
    // `StudentData.upsert` lit le document cible avant d'écrire (propriétaire
    // conservé, auteur du « Vu » conservé) : hors ligne, un document absent ne
    // se lit pas, la création échoue. ADR 0024, notes FB4c ; roadmap FB5.
    Matcher unavailable() => throwsA(
      isA<ServiceFailure>().having(
        (f) => f.code,
        'code',
        ServiceFailureCode.unavailable,
      ),
    );

    test(
      'a marker, an assessment and a « Vu » are refused, nothing written',
      () async {
        documents.offline = true;
        await expectLater(
          FirestoreAcquisitionRepository(club).add(_acquisition('q1')),
          unavailable(),
        );
        await expectLater(
          FirestoreAssessmentRepository(club).add(_assessment('b1')),
          unavailable(),
        );
        await expectLater(
          FirestoreAcknowledgementRepository(
            club,
            scope,
          ).add(_acknowledgement('k1')),
          unavailable(),
        );
        expect(documents.sent, isEmpty);
      },
    );

    test(
      'a pass is still added offline: no read of an absent document',
      () async {
        documents.offline = true;

        await FirestoreAttemptRepository(club).add(_attempt('a1'));

        expect(documents.read('clubs/c1/attempts/a1'), isNotNull);
      },
    );
  });

  group('FirestoreAcquisitionRepository', () {
    late FirestoreAcquisitionRepository repository;
    setUp(() => repository = FirestoreAcquisitionRepository(club));

    test('writes exactly the fields the rules allow, in the open season '
        'group of the student', () async {
      await repository.add(_acquisition('q1', student: 's3'));

      // s3 est dans g0 (saison close), g2 et g1 (saison ouverte) : le groupe de
      // la saison ouverte, puis l'identifiant (g1 avant g2).
      expect(documents.read('clubs/c1/acquisitions/q1'), {
        'groupId': 'g1',
        'seasonId': 'se1',
        'studentId': 's3',
        'blockId': 'puissance',
        'date': '2026-09-15T00:00:00.000',
        'source': 'placement',
      });
    });

    test('replacing a marker keeps its owner', () async {
      await repository.add(_acquisition('q1', student: 's3'));
      // La fiche change de groupes : le marqueur garde le sien.
      documents.seed('clubs/c1/students/s3', {
        'groupIds': ['g2'],
      });

      await repository.add(_acquisition('q1', student: 's3'));

      expect(documents.read('clubs/c1/acquisitions/q1')!['groupId'], 'g1');
    });

    test('a student without group cannot own a marker', () async {
      await expectLater(
        repository.add(_acquisition('q1', student: 's4')),
        throwsA(isA<ServiceFailure>()),
      );
    });

    test('a teacher writes in one of THEIR groups', () async {
      act(Role.teacher, groups: ['g2']);

      await repository.add(_acquisition('q1', student: 's3'));

      expect(documents.read('clubs/c1/acquisitions/q1')!['groupId'], 'g2');
    });

    test('a teacher outside every group of the student is refused', () async {
      act(Role.teacher, groups: ['g9']);

      await expectLater(
        repository.add(_acquisition('q1', student: 's3')),
        throwsA(isA<ServiceFailure>()),
      );
    });

    test('a parent reads the markers of the linked student only', () async {
      await repository.add(_acquisition('q1'));
      await repository.add(_acquisition('q2', student: 's2'));
      act(Role.guardian, groups: ['g1'], students: ['s1']);

      expect((await repository.all()).map((a) => a.id.value), ['q1']);
      expect((await repository.forStudent(const StudentId('s1'))).length, 1);
      expect(await repository.forStudent(const StudentId('s2')), isEmpty);
    });
  });

  group('FirestoreAssessmentRepository', () {
    late FirestoreAssessmentRepository repository;
    setUp(() => repository = FirestoreAssessmentRepository(club));

    test('writes exactly the fields the rules allow', () async {
      await repository.add(_assessment('b1'));

      expect(documents.read('clubs/c1/assessments/b1'), {
        'groupId': 'g1',
        'seasonId': 'se1',
        'studentId': 's1',
        'date': '2026-10-05T00:00:00.000',
        'concentration': 3,
        'endurance': 2,
        'frustration': 4,
        'comment': 'Calme',
      });
    });

    test('a parent or a student gets empty lists, no query is sent', () async {
      await repository.add(_assessment('b1'));
      documents.queryLog.clear();
      final reads = documents.reads;
      act(Role.guardian, groups: ['g1'], students: ['s1']);

      expect(await repository.all(), isEmpty);
      expect(await repository.forStudent(const StudentId('s1')), isEmpty);
      expect(documents.queryLog, isEmpty);
      expect(documents.reads, reads);
    });

    test('a teacher asks one group at a time', () async {
      await repository.add(_assessment('b1'));
      act(Role.teacher, groups: ['g1']);
      documents.queryLog.clear();

      expect((await repository.all()).length, 1);
      expect((await repository.forStudent(const StudentId('s1'))).length, 1);
      expect(documents.queryLog, hasLength(2));
    });
  });

  group('FirestoreAcknowledgementRepository', () {
    late FirestoreAcknowledgementRepository repository;
    setUp(() {
      scope.signIn(const UserId('u-teacher-a'));
      act(Role.director);
      repository = FirestoreAcknowledgementRepository(club, scope);
    });

    test(
      'records the account that gave the « Vu », and nothing else of it',
      () async {
        await repository.add(_acknowledgement('k1', lastAttempt: 'missing'));

        expect(documents.read('clubs/c1/acknowledgements/k1'), {
          'groupId': 'g1',
          'seasonId': 'se1',
          'studentId': 's1',
          'blockId': 'puissance',
          'exerciseNumber': 1,
          'lastAttemptId': 'missing',
          'date': '2026-10-05T00:00:00.000',
          'createdBy': 'u-teacher-a',
        });
      },
    );

    test(
      'belongs to the group of the acknowledged pass when it exists',
      () async {
        documents.seed('clubs/c1/attempts/a9', {
          'groupId': 'g2',
          'seasonId': 'se1',
          'studentId': 's3',
        });

        await repository.add(
          _acknowledgement('k1', student: 's3', lastAttempt: 'a9'),
        );

        expect(
          documents.read('clubs/c1/acknowledgements/k1')!['groupId'],
          'g2',
        );
      },
    );

    test('a pass of another student does not decide the owner', () async {
      documents.seed('clubs/c1/attempts/a9', {
        'groupId': 'g2',
        'seasonId': 'se1',
        'studentId': 's2',
      });

      await repository.add(_acknowledgement('k1', lastAttempt: 'a9'));

      expect(documents.read('clubs/c1/acknowledgements/k1')!['groupId'], 'g1');
    });

    test(
      'replacing a « Vu » keeps who gave it first, shared by the club',
      () async {
        await repository.add(_acknowledgement('k1', lastAttempt: 'p1'));
        scope.signIn(const UserId('u-dir'));
        act(Role.director);

        await repository.add(_acknowledgement('k1', lastAttempt: 'p2'));

        final stored = documents.read('clubs/c1/acknowledgements/k1')!;
        expect(stored['createdBy'], 'u-teacher-a');
        expect(stored['lastAttemptId'], 'p2');
        expect(
          (await repository.all()).single.lastAttemptId,
          const AttemptId('p2'),
        );
      },
    );

    test('without an account nothing is written', () async {
      scope.signOut();

      await expectLater(
        repository.add(_acknowledgement('k1')),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );
    });

    test('a parent or a student gets empty lists', () async {
      await repository.add(_acknowledgement('k1'));
      act(Role.student, groups: ['g1'], students: ['s1']);

      expect(await repository.all(), isEmpty);
      expect(await repository.forStudent(const StudentId('s1')), isEmpty);
    });

    test('erasing all deletes every acknowledgement of the club', () async {
      await repository.add(_acknowledgement('k1'));
      await repository.add(_acknowledgement('k2', student: 's2'));

      await repository.eraseAll();

      expect(await repository.all(), isEmpty);
    });
  });
}

class _FixedClock implements Clock {
  _FixedClock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}

Map<String, Object?> _stored(
  String id,
  DateTime? createdAt, {
  DateTime? recordedAt,
}) => {
  'groupId': 'g1',
  'seasonId': 'se1',
  'studentId': 's1',
  'sessionId': 'x1',
  'blockId': 'puissance',
  'exerciseNumber': 1,
  'date': '2026-10-03T00:00:00.000',
  'potted': 3,
  'total': 5,
  'createdAt': createdAt,
  'recordedAt': recordedAt ?? DateTime.utc(2026),
};
