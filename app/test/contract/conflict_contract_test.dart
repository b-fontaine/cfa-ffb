import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'conflict_contract.dart';

/// Un appareil : sa session (un compte directeur du club `c1`), son
/// `ClubStore` et ses dépôts Firestore, devant le [server] partagé.
Device _device(DocumentStore server, String user) {
  final scope = SessionScope()
    ..signIn(UserId(user))
    ..activate(const ClubId('c1'), Role.director);
  final club = ClubStore(server, scope);
  return (
    students: FirestoreStudentRepository(club),
    groups: FirestoreGroupRepository(club),
    seasons: FirestoreSeasonRepository(club),
    sessions: FirestoreSessionRepository(club),
    records: FirestoreSessionRecordRepository(club),
    attempts: FirestoreAttemptRepository(club),
    acquisitions: FirestoreAcquisitionRepository(club),
    acknowledgements: FirestoreAcknowledgementRepository(club, scope),
    settings: FirestoreSettingsRepository(club),
  );
}

void main() {
  // Le serveur est un faux Firestore partagé : deux `FirestoreDocumentStore`
  // (donc deux traductions réelles de valeurs et de requêtes) devant lui.
  conflictContract('Firestore (faux en mémoire, deux appareils)', () async {
    final firestore = FakeFirebaseFirestore();
    DocumentStore client() => FirestoreDocumentStore(
      access: FirestoreSdkAccess(firestore: () => firestore),
    );
    return (
      a: _device(client(), 'u-a'),
      b: _device(client(), 'u-b'),
      close: () async {},
    );
  }, isolatedTransactions: false);

  // Le double du stock (atomique, transactions isolées) : même contrat.
  conflictContract('stock en mémoire (deux appareils)', () async {
    final server = InMemoryDocumentStore();
    return (
      a: _device(server, 'u-a'),
      b: _device(server, 'u-b'),
      close: () async {},
    );
  });
}
