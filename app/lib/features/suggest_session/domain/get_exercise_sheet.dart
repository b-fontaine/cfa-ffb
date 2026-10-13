import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_key.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : la fiche d'un exercice du catalogue, avec ses schémas.
///
/// Le schéma se trouve par les données : titre du bloc = titre de la fiche
/// transcrite, numéro d'exercice = numéro transcrit. Des schémas illisibles
/// ne font pas échouer la fiche (le catalogue reste la source de rang 1).
@injectable
class GetExerciseSheet {
  GetExerciseSheet(this._catalogue, this._diagrams);

  final CatalogueRepository _catalogue;
  final DiagramRepository _diagrams;

  Future<Result<ExerciseSheet>> call(
    ExerciseRef exercise,
  ) => runGuarded(() async {
    final catalogue = await _catalogue.load();
    final block = catalogue.blockById(exercise.blockId);
    final spec = catalogue.exercise(exercise);
    if (block == null || spec == null) {
      throw const InvariantViolation(InvariantCode.unknownExercise);
    }
    try {
      final library = await _diagrams.load();
      return ExerciseSheet(
        block: block,
        spec: spec,
        diagrams: library.find(
          DiagramKey.training(sheet: block.title, exercise: spec.ref.number),
        ),
      );
    } on InvariantViolation catch (violation) {
      // Seul « schéma illisible » est toléré ; le reste est une vraie erreur.
      if (violation.code != InvariantCode.invalidDiagram) rethrow;
      return ExerciseSheet(block: block, spec: spec, diagramsUnreadable: true);
    }
  });
}
