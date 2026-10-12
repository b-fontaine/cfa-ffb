import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux groupes (implémenté dans la couche data).
///
/// Même contrat que `StudentRepository` : ordre de première sauvegarde,
/// remplacement par id, suppression logique.
abstract interface class GroupRepository {
  Future<void> save(Group group);

  Future<Group?> byId(GroupId id);

  Future<List<Group>> all();

  /// Supprime logiquement le groupe ; sans effet s'il n'existe pas.
  Future<void> delete(GroupId id);

  /// Efface physiquement les appartenances de l'élève dans tous les groupes
  /// (droit à l'effacement) ; les groupes eux-mêmes restent.
  Future<void> eraseStudent(StudentId studentId);
}
