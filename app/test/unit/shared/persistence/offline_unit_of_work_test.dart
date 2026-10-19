import 'dart:async';

import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/drift_support.dart';
import '../../../support/firestore_world.dart';

/// Un Firestore **hors ligne** : le SDK applique le lot à son cache local dès
/// l'appel, mais n'acquitte `commit` qu'à la réponse du serveur, qui ne vient
/// jamais ici.
class _OfflineStore extends InMemoryDocumentStore {
  final Completer<void> _never = Completer<void>();
  int sent = 0;

  @override
  Future<void> commit(List<WriteOp> operations) {
    sent++;
    unawaited(super.commit(operations));
    return _never.future;
  }
}

Student _student(String id) => Student.enroll(
  id: StudentId(id),
  firstName: 'Léa',
  audience: Audience.children,
  since: DateTime(2026, 9),
);

void main() {
  late _OfflineStore documents;
  late ClubStore club;
  late SendTracker tracker;

  setUp(() {
    documents = _OfflineStore();
    final world = FirestoreWorld()..act('c1', Role.director);
    club = ClubStore(documents, world.scope);
    tracker = SendTracker(InMemoryPendingWritesProbe());
  });

  test('a Firestore commit that never ends does not hold the local '
      'transaction open: the unit ends and local writes go on', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final clock = TickingClock();
    final drift = DriftStudentRepository(db, clock);
    final firestore = FirestoreStudentRepository(club);
    final unit = CompositeUnitOfWork(
      outer: DriftUnitOfWork(db),
      inner: FirestoreUnitOfWork(club, tracker: tracker),
    );

    await unit
        .run(() async {
          await drift.save(_student('local'));
          await firestore.save(_student('remote'));
        })
        .timeout(const Duration(seconds: 2));

    // Le lot est appliqué localement (le SDK l'applique au cache dès l'appel).
    expect(documents.read('clubs/c1/students/remote'), isNotNull);
    expect(await drift.byId(const StudentId('local')), isNotNull);
    // Aucune écriture locale n'est bloquée par une transaction restée ouverte.
    await drift.save(_student('another')).timeout(const Duration(seconds: 2));
    await unit
        .run(() => drift.save(_student('third')))
        .timeout(const Duration(seconds: 2));
    expect(await drift.all(), hasLength(3));
  });

  test('the sending is followed apart: pending until the server answers, '
      'announced by the port', () async {
    final unit = FirestoreUnitOfWork(club, tracker: tracker);
    final changes = <int>[];
    final subscription = tracker.pendingChanges.listen(changes.add);
    addTearDown(subscription.cancel);
    expect(tracker.pending, 0);

    await unit
        .run(() => FirestoreStudentRepository(club).save(_student('s1')))
        .timeout(const Duration(seconds: 2));
    await pumpEventQueue();

    expect(documents.sent, 1);
    expect(tracker.pending, 1);
    expect(changes, [1]);
  });

  test('an empty unit sends nothing and is not pending', () async {
    final unit = FirestoreUnitOfWork(club, tracker: tracker);

    await unit.run(() async {}).timeout(const Duration(seconds: 2));

    expect(documents.sent, 0);
    expect(tracker.pending, 0);
  });

  test('more than 500 writes still fail before anything is sent', () async {
    final unit = FirestoreUnitOfWork(club, tracker: tracker);

    await expectLater(
      unit.run<void>(
        () => club.commit([
          for (var i = 0; i < 501; i++)
            SetOp('clubs/c1/students/s$i', {'firstName': 'Léa'}),
        ]),
      ),
      throwsA(isNotNull),
    );

    expect(documents.sent, 0);
    expect(tracker.pending, 0);
  });
}
