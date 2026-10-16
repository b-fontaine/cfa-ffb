import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/track_progress/domain/exercise_curve.dart';
import 'package:billard_cfa/features/track_progress/domain/path_row.dart';
import 'package:billard_cfa/features/track_progress/domain/sheet_header.dart';
import 'package:billard_cfa/features/track_progress/domain/student_report.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'student_sheet.freezed.dart';

/// Passages d'un élève sur un exercice pratiqué : taux requis, statut,
/// alerte et courbe (essais en abscisse, billes empochées en ordonnée).
@freezed
abstract class ExerciseSeries with _$ExerciseSeries {
  const factory ExerciseSeries({
    required ExerciseRef exercise,
    required SuccessRate rate,
    required ExerciseStatus status,
    required AlertLevel alert,

    /// Échecs consécutifs depuis la dernière réussite (R4).
    required int consecutiveFailures,
    required int passedCount,
    required ExerciseCurve curve,
  }) = _ExerciseSeries;
}

/// Fiche d'un élève : progression par bloc, courbes, exercice suivant et
/// dernier bilan de maturité (aide à la décision, jamais un déclencheur).
@freezed
abstract class StudentSheet with _$StudentSheet {
  const factory StudentSheet({
    required Student student,
    required StudentReport report,
    required ExerciseCatalogue catalogue,

    /// Exercices pratiqués, dans l'ordre d'enseignement.
    required List<ExerciseSeries> series,

    /// Le parcours : une ligne par technique, une case par exercice (lot U9).
    required List<PathRow> path,

    /// En cours, prochain, alerte (lot U9).
    required SheetHeader header,

    /// Exercice suivant recommandé (R2) ; `null` quand le niveau est terminé.
    required ExerciseRef? nextExercise,

    /// Passages réussis nécessaires pour valider un exercice.
    required int passesRequired,
    required int assessmentCount,
    required MaturityAssessment? latestAssessment,

    /// Aide issue du dernier bilan ; `null` sans bilan.
    required bool? readinessHint,
  }) = _StudentSheet;
}
