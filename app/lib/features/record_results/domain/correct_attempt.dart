import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : corriger en place les billes empochées et les tentatives
/// d'un passage déjà saisi (ADR 0006). La date, le rang du passage, l'élève
/// et l'exercice ne changent pas ; les règles de la saisie s'appliquent.
@injectable
class CorrectAttempt {
  CorrectAttempt(this._attempts, this._catalogue);

  final AttemptRepository _attempts;
  final CatalogueRepository _catalogue;

  Future<Result<ExerciseAttempt>> call({
    required SessionId sessionId,
    required AttemptId attemptId,
    required int potted,
    required int total,
  }) => runGuarded(() async {
    final existing = (await _attempts.forSession(sessionId))
        .where((a) => a.id == attemptId)
        .firstOrNull;
    if (existing == null) throw NotFound('attempt', attemptId.value);
    final spec = (await _catalogue.load()).exercise(existing.exercise);
    if (spec == null) {
      throw const InvariantViolation(InvariantCode.unknownExercise);
    }
    if (!spec.rate.acceptsTotal(total)) {
      throw const InvariantViolation(InvariantCode.totalBelowSheet);
    }
    final corrected = existing.copyWith(potted: potted, total: total);
    await _attempts.correct(corrected);
    return corrected;
  });
}
