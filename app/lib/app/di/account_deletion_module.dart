import 'package:billard_cfa/app/firestore_own_marker_store.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:billard_cfa/shared/lib/operations/remove_own_markers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:injectable/injectable.dart';

/// Câblage du nettoyage des marqueurs de l'auteur (FB8 partie B, B1),
/// qu'emploie la suppression d'un compte (B2). Les marqueurs vivent toujours
/// dans Firestore (le stock de documents des comptes et des clubs), quel que
/// soit le backend des données du club : sous drift, la liste est vide.
/// Les scénarios (`Environment.test`) les posent dans le stock en mémoire.
@module
abstract class AccountDeletionModule {
  @lazySingleton
  OwnMarkerStore ownMarkerStore(DocumentStore documents, CurrentUser user) =>
      FirestoreOwnMarkerStore(documents, user);

  @lazySingleton
  RemoveOwnMarkers removeOwnMarkers(OwnMarkerStore store) =>
      RemoveOwnMarkers(store);
}
