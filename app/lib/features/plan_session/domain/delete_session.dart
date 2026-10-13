import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : retirer une séance planifiée (une erreur de public ou de
/// séance du catalogue se corrige en la supprimant puis en la replanifiant).
/// Le contenu du catalogue, en lecture seule, n'est jamais touché ; une
/// séance inconnue est sans effet.
@injectable
class DeleteSession {
  DeleteSession(this._repository);

  final SessionRepository _repository;

  Future<void> call(String id) => _repository.delete(id);
}
