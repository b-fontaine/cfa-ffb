import 'dart:async';

import 'package:billard_cfa/features/purge_stale_markers/domain/stale_markers.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Les marqueurs **anciens** d'un club dans Firestore (FB8 partie B, B5 ;
/// ADR 0024 décision 19) : `clubs/{c}/imports/{empreinte}_{uid}` et
/// `clubs/{c}/operations/{empreinte}_{uid}`, de tout auteur.
///
/// - **Liste** ([list]) : requête de plage `updatedAt < borne` sur la
///   collection du club, la seule que les règles ouvrent au gestionnaire pour
///   les marqueurs d'opération d'un autre auteur (`staleMarker()`). Un
///   document dont l'identifiant n'a pas la forme `{64 hexa}_{uid}` est
///   ignoré.
/// - **Suppression** ([delete]) : chaque chemin est composé du club donné, de
///   la collection de sa nature et d'un identifiant **revérifié** (aucun `/`) ;
///   un seul lot atomique dont l'envoi **attend l'accusé du serveur**
///   (`DocumentStore.commit`), comme le nettoyage de l'auteur (B1). Au-delà de
///   [ackTimeout] sans réponse, `unavailable` ; le lot reste dans la file du
///   SDK (supprimer un document absent est accepté : rejouer est sans danger).
class FirestoreStaleMarkerStore implements StaleMarkerStore {
  FirestoreStaleMarkerStore(
    this._documents, {
    this.ackTimeout = const Duration(seconds: 30),
  });

  final DocumentStore _documents;

  /// Combien de temps attendre l'accusé du serveur pour un lot.
  final Duration ackTimeout;

  static final _markerId = RegExp(r'^[0-9a-f]{64}_[^/]+$');

  static String _collection(ClubId club, MarkerKind kind) {
    final paths = ClubPaths(club);
    return switch (kind) {
      MarkerKind.import => paths.imports,
      MarkerKind.operation => paths.operations,
    };
  }

  @override
  Future<List<StaleMarker>> list(
    ClubId club,
    MarkerKind kind,
    DateTime before,
  ) => guardStore(() async {
    final documents = await _documents.query(
      _collection(club, kind),
      FieldBefore('updatedAt', before),
    );
    return [
      for (final document in documents)
        if (_markerId.hasMatch(document.id)) StaleMarker(kind, document.id),
    ];
  });

  @override
  Future<void> delete(ClubId club, List<StaleMarker> markers) =>
      guardStore(() async {
        if (markers.length > maxOwnMarkerLot) {
          throw ServiceFailure(
            ServiceFailureCode.other,
            '${markers.length} deletions > $maxOwnMarkerLot',
          );
        }
        for (final marker in markers) {
          if (!_markerId.hasMatch(marker.id)) {
            throw const ServiceFailure(ServiceFailureCode.other, 'identifiant');
          }
        }
        if (markers.isEmpty) return;
        final send = Future.sync(
          () => _documents.commit([
            for (final marker in markers)
              DeleteOp('${_collection(club, marker.kind)}/${marker.id}'),
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
      });
}
