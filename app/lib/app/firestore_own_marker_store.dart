import 'dart:async';

import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Les marqueurs du **compte courant** dans Firestore (FB8 partie B, B1 ;
/// ADR 0024 décision 19) : `clubs/{c}/imports/{empreinte}_{uid}` et
/// `clubs/{c}/operations/{empreinte}_{uid}`. Le club est donné à chaque appel
/// (la suppression d'un compte parcourt tous ses clubs), pas lu dans la
/// session.
///
/// - **Liste** ([list]) : requête **filtrée sur `createdBy == uid`**, la
///   seule que les règles permettent à un enseignant (imports) et à quiconque
///   (opérations), **lue au serveur** (`DocumentStore.queryFromServer`) :
///   hors ligne, `unavailable` plutôt qu'une liste vide venue du cache, qui
///   laisserait la suppression d'un compte retirer son `member` avant ses
///   marqueurs. Un document dont l'identifiant ne finit pas par `_{uid}`
///   est ignoré (l'identifiant fait foi, comme dans les règles).
/// - **Suppression** ([delete]) : chaque chemin est **recomposé avec l'uid du
///   compte courant** (`ClubPaths.importMarker`, `operationMarker`) : aucun
///   appel ne peut désigner le marqueur d'un autre. Un seul lot atomique, dont
///   l'envoi **attend l'accusé du serveur** (`DocumentStore.commit`, jamais
///   `ClubStore.commit`) : la suppression d'un compte (B2) ne doit continuer
///   qu'une fois ses marqueurs réellement partis. Au-delà de [ackTimeout] sans
///   réponse (hors ligne), `unavailable` ; l'écriture reste dans la file du
///   SDK et partira à la reconnexion (supprimer un document absent est
///   accepté : rejouer est sans danger).
class FirestoreOwnMarkerStore implements OwnMarkerStore {
  FirestoreOwnMarkerStore(
    this._documents,
    this._user, {
    this.ackTimeout = const Duration(seconds: 30),
  });

  final DocumentStore _documents;
  final CurrentUser _user;

  /// Combien de temps attendre l'accusé du serveur pour un lot.
  final Duration ackTimeout;

  @override
  Future<List<OwnMarker>> list(ClubId club, MarkerKind kind) =>
      guardStore(() async {
        final author = _author;
        final paths = ClubPaths(club);
        final collection = switch (kind) {
          MarkerKind.import => paths.imports,
          MarkerKind.operation => paths.operations,
        };
        final suffix = '_${author.value}';
        final documents = await _documents.queryFromServer(
          collection,
          FieldEquals('createdBy', author.value),
        );
        return [
          for (final document in documents)
            if (document.id.endsWith(suffix))
              OwnMarker(
                kind,
                document.id.substring(0, document.id.length - suffix.length),
              ),
        ];
      });

  @override
  Future<void> delete(ClubId club, List<OwnMarker> markers) => guardStore(
    () async {
      final author = _author;
      if (markers.length > maxOwnMarkerLot) {
        throw ServiceFailure(
          ServiceFailureCode.other,
          '${markers.length} deletions > $maxOwnMarkerLot',
        );
      }
      if (markers.isEmpty) return;
      final paths = ClubPaths(club);
      final send = Future.sync(
        () => _documents.commit([
          for (final marker in markers)
            DeleteOp(switch (marker.kind) {
              MarkerKind.import => paths.importMarker(marker.key, author),
              MarkerKind.operation => paths.operationMarker(marker.key, author),
            }),
        ]),
      );
      try {
        await send.timeout(ackTimeout);
      } on TimeoutException {
        // L'écriture reste dans la file du SDK ; une erreur tardive ne doit
        // pas remonter comme non gérée.
        unawaited(send.then<void>((_) {}, onError: (Object _) {}));
        throw const StoreFailure(
          StoreFailureCode.unavailable,
          'lot sans réponse du serveur',
        );
      }
    },
  );

  UserId get _author {
    final author = _user.id;
    if (author == null) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'user');
    }
    return author;
  }
}
