import 'package:billard_cfa/app/firestore_own_marker_store.dart';
import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/in_memory_own_marker_store.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'own_marker_store_contract.dart';

/// Le chemin d'un marqueur, composé ici à la main (comme `firestore.rules`) :
/// le contrat ne fait pas confiance à `ClubPaths` pour le prouver.
String _path(ClubId club, MarkerKind kind, String key, String author) =>
    'clubs/${club.value}/'
    '${kind == MarkerKind.import ? 'imports' : 'operations'}/${key}_$author';

/// Un marqueur tel que le pose l'application (champs utiles à la requête).
Fields _fields(MarkerKind kind, String key, String author) => {
  if (kind == MarkerKind.import) 'fileId': key else 'operationId': key,
  'createdBy': author,
};

OwnMarkerHarness _onDocuments(DocumentStore documents) {
  final scope = SessionScope();
  return OwnMarkerHarness(
    store: FirestoreOwnMarkerStore(documents, scope),
    scope: scope,
    seed: (club, kind, key, author) => documents.commit([
      SetOp(_path(club, kind, key, author), _fields(kind, key, author)),
    ]),
    exists: (club, kind, key, author) async =>
        await documents.get(_path(club, kind, key, author)) != null,
  );
}

void main() {
  ownMarkerStoreContract('mémoire', () async {
    final scope = SessionScope();
    final store = InMemoryOwnMarkerStore(scope);
    return OwnMarkerHarness(
      store: store,
      scope: scope,
      seed: (club, kind, key, author) async =>
          store.seed(club, kind, key, author),
      exists: (club, kind, key, author) async =>
          store.contains(club, kind, key, author),
    );
  });

  ownMarkerStoreContract(
    'Firestore (stock en mémoire)',
    () async => _onDocuments(InMemoryDocumentStore()),
  );

  ownMarkerStoreContract('Firestore (fake_cloud_firestore)', () async {
    final firestore = FakeFirebaseFirestore();
    return _onDocuments(
      FirestoreDocumentStore(
        access: FirestoreSdkAccess(firestore: () => firestore),
      ),
    );
  });
}
