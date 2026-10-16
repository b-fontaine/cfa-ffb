import 'package:billard_cfa/entities/exercise_result/domain/exercise_cell.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'student_showcase.freezed.dart';

/// État d'une ligne (technique) de la vue élève : quatre états, jamais
/// d'« à revoir » (une technique alertée se montre « en cours »).
enum ShowcaseRowStatus { todo, inProgress, finished, acquired }

/// Une case de la vue élève : le numéro de l'exercice, son état et ses seules
/// réussites (jamais les échecs).
@freezed
abstract class ShowcaseCell with _$ShowcaseCell {
  const factory ShowcaseCell({
    required int number,
    required ExerciseCellState state,
    required int passed,
  }) = _ShowcaseCell;
}

/// Une technique de la vue élève et ses cases. Aucune provenance : la vue élève
/// ne signale pas les propositions (décision U9-9, ADR 0014).
@freezed
abstract class ShowcaseRow with _$ShowcaseRow {
  const factory ShowcaseRow({
    required String title,
    required ShowcaseRowStatus status,
    required List<ShowcaseCell> cells,
  }) = _ShowcaseRow;
}

/// L'exercice en cours de la vue élève, avec ses seules réussites.
@freezed
abstract class ShowcaseCurrent with _$ShowcaseCurrent {
  const factory ShowcaseCurrent({
    required String blockTitle,
    required int number,

    /// Passages réussis (jamais les échecs).
    required int passed,

    /// Passages réussis nécessaires pour valider l'exercice.
    required int required,
  }) = _ShowcaseCurrent;
}

/// Ce qu'on peut montrer à l'élève : son prénom et son parcours, rien d'autre
/// (décision Q6). La garantie est de type : ce modèle n'a aucun champ pour les
/// alertes, les notes d'animateur, le bilan de maturité, l'assiduité, les
/// courbes, les dates ou un autre élève.
@freezed
abstract class StudentShowcase with _$StudentShowcase {
  const factory StudentShowcase({
    required String firstName,
    required List<ShowcaseRow> rows,

    /// `null` quand le niveau est terminé.
    required ShowcaseCurrent? current,

    /// Exercices validés ou acquis.
    required int validatedCount,
    required int finishedTechniques,
    required int techniqueCount,

    /// Aucun passage ni exercice validé ou acquis (règle du domaine).
    required bool toStart,

    /// Passages réussis nécessaires pour valider un exercice.
    required int passesRequired,
  }) = _StudentShowcase;
}
