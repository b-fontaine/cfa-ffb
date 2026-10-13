import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_exercise.freezed.dart';

/// Erreur fréquente et correction (lecture animateur).
@freezed
abstract class SheetMistake with _$SheetMistake {
  const factory SheetMistake({required String symptom, required String fix}) =
      _SheetMistake;
}

/// Accroche et défi ludiques `[Prop]` d'un exercice.
@freezed
abstract class SheetPlayful with _$SheetPlayful {
  const factory SheetPlayful({
    required String hook,
    required String challenge,
  }) = _SheetPlayful;
}

/// Exercice d'entraînement d'une séance : référence au catalogue (taux,
/// chevalet, bronze y sont lus) et contenu pédagogique propre à la séance.
@freezed
abstract class SheetExercise with _$SheetExercise {
  const factory SheetExercise({
    required String id,
    required ExerciseRef ref,

    /// Identifiant du schéma de mise en place (`DiagramLibrary.byId`).
    required String diagramId,
    required String title,
    required AudienceWeight weight,
    required String setup,
    required String instruction,
    required String expected,
    required SheetPlayful playful,

    /// Passages prévus par élève, de 1 à 2.
    required int passes,
    required Provenance src,
    @Default(<SheetMistake>[]) List<SheetMistake> mistakes,
  }) = _SheetExercise;
}
