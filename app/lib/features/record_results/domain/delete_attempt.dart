import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : supprimer un passage saisi (ADR 0006).
///
/// Le rang d'un passage est **dérivé** de l'ordre d'enregistrement (ADR 0024,
/// décision 17, qui amende l'ADR 0006) : les passages restants du même élève,
/// du même exercice et de la même séance ne sont **plus renumérotés**, il n'y
/// a rien à réécrire. Un seul document est supprimé.
@injectable
class DeleteAttempt {
  DeleteAttempt(this._attempts);

  final AttemptRepository _attempts;

  Future<Result<void>> call({
    required SessionId sessionId,
    required AttemptId attemptId,
  }) => runGuarded(() async {
    final inSession = await _attempts.forSession(sessionId);
    if (!inSession.any((a) => a.id == attemptId)) {
      throw NotFound('attempt', attemptId.value);
    }
    await _attempts.delete(attemptId);
  });
}
