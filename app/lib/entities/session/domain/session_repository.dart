import 'package:billard_cfa/entities/session/domain/session.dart';

/// Port d'accès aux séances planifiées (implémenté dans la couche data).
///
/// [add] d'un id déjà connu remplace la séance ; la suppression est logique.
abstract interface class SessionRepository {
  Future<List<Session>> getAll();

  Future<void> add(Session session);

  /// Supprime logiquement la séance ; sans effet si elle n'existe pas.
  Future<void> delete(String id);
}
