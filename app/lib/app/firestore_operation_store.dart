import 'dart:async';

import 'package:billard_cfa/app/operation_marker_document.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Le club Firestore vu par une opération reprenable (FB8, ADR 0024 décision
/// 19) : le marqueur **de ce compte**, relu au serveur, et l'écriture d'un lot
/// atomique avec lui. Choisi par `DataBackendModule` avec
/// `DataBackend.firestore`.
///
/// - **Écriture** ([commit]) : les écritures de l'opération (les dépôts
///   habituels, qui s'accumulent dans l'unité de travail du `ClubStore`) et le
///   marqueur partent **en un seul lot atomique**, dont l'envoi **attend
///   l'accusé du serveur** : le marqueur n'avance que si le lot est accepté.
///   Au-delà de [ackTimeout] sans réponse (hors ligne), l'opération est dite
///   interrompue (`unavailable`) ; l'écriture reste dans la file du SDK et sera
///   envoyée à la reconnexion, **au plus une fois** : le marqueur refuse un lot
///   déjà appliqué.
/// - **Marqueur** : créé au premier lot (`done == 1`), avancé d'un lot par lot,
///   **supprimé** par le dernier (aucune trace). Un lot qui crée et finit à la
///   fois (une opération d'un seul lot) n'écrit aucun marqueur.
class FirestoreOperationStore implements OperationStore {
  FirestoreOperationStore(
    this._club,
    this._user, {
    this.ackTimeout = const Duration(seconds: 30),
  });

  final ClubStore _club;
  final CurrentUser _user;

  /// Combien de temps attendre l'accusé du serveur pour un lot.
  final Duration ackTimeout;

  @override
  Future<OperationMarker?> readMarker(String key) => guardStore(() async {
    final author = _author;
    final document = await _club.documents.getFromServer(
      _club.paths.operationMarker(key, author),
    );
    return document == null ? null : OperationMarkerDocument.decode(document);
  });

  @override
  Future<List<OperationMarker>> ownMarkers() => guardStore(() async {
    final author = _author;
    final documents = await _club.documents.query(
      _club.paths.operations,
      FieldEquals('createdBy', author.value),
    );
    return [for (final d in documents) OperationMarkerDocument.decode(d)];
  });

  @override
  Future<void> commit(OperationLotCommit commit) => guardStore(() async {
    final paths = _club.paths;
    final author = _author;
    final markerPath = paths.operationMarker(commit.marker.key, author);
    final send = Future.sync(
      () => _club.atomically(() async {
        await commit.lot.apply();
        if (commit.finishes) {
          if (!commit.createsMarker) await _club.commit([DeleteOp(markerPath)]);
        } else {
          await _club.commit([
            if (commit.createsMarker)
              SetOp(
                markerPath,
                OperationMarkerDocument.create(
                  commit.marker,
                  createdBy: author,
                ),
              )
            else
              UpdateOp(
                markerPath,
                OperationMarkerDocument.advance(commit.marker),
              ),
          ]);
        }
      }),
    );
    try {
      await send.timeout(ackTimeout);
    } on TimeoutException {
      // L'écriture reste dans la file du SDK ; une erreur tardive ne doit pas
      // remonter comme non gérée.
      unawaited(send.then<void>((_) {}, onError: (Object _) {}));
      throw const StoreFailure(
        StoreFailureCode.unavailable,
        'lot sans réponse du serveur',
      );
    }
  });

  UserId get _author {
    final author = _user.id;
    if (author == null) {
      throw const StoreFailure(StoreFailureCode.permissionDenied, 'user');
    }
    return author;
  }
}
