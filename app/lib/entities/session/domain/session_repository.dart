import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux séances planifiées (implémenté dans la couche data).
///
/// [add] d'un id déjà connu remplace la séance ; la suppression est logique.
abstract interface class SessionRepository {
  Future<List<Session>> getAll();

  Future<void> add(Session session);

  /// Supprime logiquement la séance ; sans effet si elle n'existe pas.
  Future<void> delete(String id);

  /// Les identifiants des séances planifiées de ces [groups], supprimées
  /// logiquement comprises (droit à l'effacement : une séance supprimée de ses
  /// groupes reste en base jusqu'à sa purge).
  Future<Set<String>> idsOfGroups(Set<GroupId> groups);

  /// Suit la liste que renvoie [getAll] (contrat des `watch…` : voir
  /// `StudentRepository.watchById`).
  Stream<List<Session>> watchAll();
}
