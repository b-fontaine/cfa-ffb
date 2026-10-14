import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : supprimer un passage saisi (ADR 0006).
///
/// Les passages restants du même élève, du même exercice et de la même séance
/// sont renumérotés `1..n` : `RecordAttempt` attribue l'index suivant d'après
/// le nombre de passages, et les résultats se dérivent par `(date, passIndex)`.
/// Tout ou rien (unité de travail).
@injectable
class DeleteAttempt {
  DeleteAttempt(this._attempts, this._unitOfWork);

  final AttemptRepository _attempts;
  final UnitOfWork _unitOfWork;

  Future<Result<void>> call({
    required SessionId sessionId,
    required AttemptId attemptId,
  }) => runGuarded(() async {
    final inSession = await _attempts.forSession(sessionId);
    final deleted = inSession.where((a) => a.id == attemptId).firstOrNull;
    if (deleted == null) throw NotFound('attempt', attemptId.value);
    final siblings =
        inSession
            .where(
              (a) =>
                  a.id != attemptId &&
                  a.studentId == deleted.studentId &&
                  a.exercise == deleted.exercise,
            )
            .toList()
          ..sort((a, b) => a.passIndex.compareTo(b.passIndex));
    await _unitOfWork.run(() async {
      await _attempts.delete(attemptId);
      for (final (index, sibling) in siblings.indexed) {
        if (sibling.passIndex != index + 1) {
          await _attempts.add(sibling.copyWith(passIndex: index + 1));
        }
      }
    });
  });
}
