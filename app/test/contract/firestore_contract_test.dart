import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'settings_contract.dart';
import 'student_group_contract.dart';

/// Un club `c1` dirigé par un directeur, sur un **faux Firestore en mémoire**
/// (`fake_cloud_firestore`) derrière le vrai `FirestoreDocumentStore` et le
/// vrai `FirestoreSdkAccess`.
///
/// Ce que cela prouve : les dépôts Firestore tiennent le même contrat que
/// drift et la mémoire, avec la traduction réelle des valeurs (dates, listes,
/// date du serveur) et des requêtes. Ce que cela NE prouve PAS : les règles de
/// sécurité, les index, les chemins réels, les quotas, le hors ligne (le faux
/// n'en applique aucun) : voir `docs/engineering/testing.md`, section FB4, et
/// `scripts/rules_test/repositories.test.mjs` pour le pendant contre
/// l'émulateur.
ClubStore _openClub() {
  final scope = SessionScope()
    ..signIn(const UserId('u-dir'))
    ..activate(const ClubId('c1'), Role.director);
  final firestore = FakeFirebaseFirestore();
  return ClubStore(
    FirestoreDocumentStore(
      access: FirestoreSdkAccess(firestore: () => firestore),
    ),
    scope,
  );
}

void main() {
  studentGroupContract('Firestore (faux en mémoire)', () async {
    final club = _openClub();
    return (
      students: FirestoreStudentRepository(club),
      groups: FirestoreGroupRepository(club),
      close: () async {},
    );
  });

  settingsContract(
    'Firestore (faux en mémoire)',
    () async => (
      repository: FirestoreSettingsRepository(_openClub()),
      close: () async {},
    ),
  );
}
