import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
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

  /// Applique [operations] par lots de [maxBatchWrites] (limite de Firestore).
  /// Un lot est atomique ; au-delà, les lots se suivent et une coupure laisse
  /// un état partiel : les écritures des dépôts sont **idempotentes** (mêmes
  /// identifiants), la reprise rejoue l'ensemble (ADR 0024, décision 19).
  Future<void> commit(List<WriteOp> operations) async {
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
}

/// Écritures par lot au plus (limite de Firestore).
const int maxBatchWrites = 500;
