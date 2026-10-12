import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/track_progress/domain/exercise_curve.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : courbe de progression d'un élève sur un exercice.
@injectable
class GetExerciseCurve {
  GetExerciseCurve(this._attempts, this._catalogue, this._config);

  final AttemptRepository _attempts;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  Future<Result<ExerciseCurve>> call({
    required StudentId studentId,
    required ExerciseRef exercise,
  }) => runGuarded(() async {
    final spec = (await _catalogue.load()).exercise(exercise);
    if (spec == null) {
      throw const InvariantViolation(InvariantCode.unknownExercise);
    }
    final attempts = [
      for (final attempt in await _attempts.forStudent(studentId))
        if (attempt.exercise == exercise) attempt,
    ];
    return ExerciseCurve.of(
      ExerciseResult.derive(
        studentId: studentId,
        exercise: exercise,
        rate: spec.rate,
        attempts: attempts,
        config: _config,
      ),
      _config,
    );
  });
}
