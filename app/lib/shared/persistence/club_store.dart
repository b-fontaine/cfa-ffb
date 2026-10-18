import 'dart:async';

import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/pending_writes.dart';
import 'package:injectable/injectable.dart';

/// Le [DocumentStore] vu depuis le club actif : les dépôts Firestore y
/// résolvent **à chaque appel** le club de la session ([ActiveClubScope]), pas
/// à la construction. Un dépôt unique survit ainsi à un changement de club, et
/// aucun appel ne peut écrire dans le club précédent : la résolution est
/// relue avant chaque lecture ou écriture.
@LazySingleton()
final class ClubStore {
  const ClubStore(this.documents, this._scope);

  final DocumentStore documents;
  final ActiveClubScope _scope;

  /// Rôle courant dans le club actif (`null` sans club).
  Role? get role => _scope.role;

  /// Groupes du périmètre du membre (enseignant, parent, élève).
  List<GroupId> get groupIds => _scope.groupIds;

  /// Fiches du périmètre du membre (parent, élève).
  List<StudentId> get studentIds => _scope.studentIds;

  /// Directeur ou administrateur : voit tout le club.
  bool get manages => _scope.role == Role.director || _scope.role == Role.admin;

  /// Chemins du club actif. Sans club actif, l'accès est refusé (jamais un
  /// chemin construit au hasard) : [ServiceFailure] `denied`.
  ClubPaths get paths {
    final club = _scope.clubId;
    if (club == null) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'no-active-club');
    }
    return ClubPaths(club);
  }

  /// Les écritures en attente de l'unité de travail en cours (même zone),
  /// `null` hors unité.
  PendingWrites? get _pending => Zone.current[_unitKey] as PendingWrites?;

  /// Lit [path] ; dans une unité de travail, avec **ses propres écritures**
  /// (un dépôt relit ce qu'il vient d'écrire dans la même unité).
  Future<StoredDocument?> get(String path) async {
    final stored = await documents.get(path);
    final pending = _pending;
    if (pending == null) return stored;
    final fields = pending.overlay(path, stored?.fields);
    return fields == null ? null : StoredDocument(path, fields);
  }

  /// Écrit [operations]. Dans une unité de travail ([atomically]), elles
  /// attendent le lot unique de sa fin. Hors unité, elles partent par lots de
  /// [maxBatchWrites] : un lot est atomique ; au-delà, les lots se suivent et
  /// une coupure laisse un état partiel : les écritures des dépôts sont
  /// **idempotentes** (mêmes identifiants), la reprise rejoue l'ensemble (ADR
  /// 0024, décision 19).
  Future<void> commit(List<WriteOp> operations) async {
    final pending = _pending;
    if (pending != null) {
      operations.forEach(pending.add);
      return;
    }
    for (var i = 0; i < operations.length; i += maxBatchWrites) {
      final end = i + maxBatchWrites;
      await documents.commit(
        operations.sublist(
          i,
          end > operations.length ? operations.length : end,
        ),
      );
    }
  }

  /// Crée [path] s'il est absent (atomique côté serveur, voir
  /// `DocumentStore.createIfAbsent`) ; `false` s'il existe déjà. Réservé aux
  /// écritures **hors** unité de travail : une création conditionnelle ne peut
  /// pas attendre le lot de la fin : dans une unité, `StoreFailure`
  /// `unsupported` (donc `ServiceFailure` `unsupported` sorti d'un dépôt),
  /// jamais une exception hors `Failure`. C'est ce qui rend l'import d'une
  /// sauvegarde
  /// explicitement non supporté avec Firestore avant FB7.
  Future<bool> createIfAbsent(String path, Fields fields) async {
    if (_pending != null) {
      throw const StoreFailure(
        StoreFailureCode.unsupported,
        'createIfAbsent hors unité de travail seulement',
      );
    }
    return await documents.createIfAbsent(path, fields);
  }

  /// Exécute [body] ; toutes les écritures qu'il demande à [commit] partent
  /// en **un seul lot atomique** à sa fin (au plus [maxBatchWrites], sinon
  /// `StoreFailure(batchTooLarge)` sans rien écrire), ou aucune si [body]
  /// échoue. Une unité imbriquée rejoint l'unité englobante.
  ///
  /// Avec [onSend], le lot est **envoyé sans être attendu** : le SDK l'applique
  /// au cache local dès l'appel, l'accusé du serveur (jamais, hors ligne) est
  /// confié à [onSend] (`SendTracker.track`), pas à l'appelant : une
  /// transaction locale qui enveloppe l'unité ne reste pas ouverte.
  Future<T> atomically<T>(
    Future<T> Function() body, {
    void Function(Future<void> send)? onSend,
  }) async {
    if (_pending != null) return await body();
    final pending = PendingWrites();
    final result = await runZoned(body, zoneValues: {_unitKey: pending});
    final operations = pending.operations;
    if (operations.isEmpty) return result;
    // Taille vérifiée AVANT l'envoi : un envoi non attendu ne peut plus la
    // refuser à l'appelant.
    checkBatchSize(operations);
    final send = documents.commit(operations);
    if (onSend == null) {
      await send;
    } else {
      onSend(send);
    }
    return result;
  }
}

/// Clé de zone de l'unité de travail en cours.
final Object _unitKey = Object();
