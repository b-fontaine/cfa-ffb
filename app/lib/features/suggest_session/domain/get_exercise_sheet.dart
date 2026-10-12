import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : la fiche d'un exercice du catalogue.
@injectable
class GetExerciseSheet {
  GetExerciseSheet(this._catalogue);

  final CatalogueRepository _catalogue;

  Future<Result<ExerciseSheet>> call(ExerciseRef exercise) =>
      runGuarded(() async {
        final catalogue = await _catalogue.load();
        final block = catalogue.blockById(exercise.blockId);
        final spec = catalogue.exercise(exercise);
        if (block == null || spec == null) {
          throw const InvariantViolation(InvariantCode.unknownExercise);
        }
        return ExerciseSheet(block: block, spec: spec);
      });
}
