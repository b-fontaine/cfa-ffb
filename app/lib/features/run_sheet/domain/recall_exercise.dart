import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recall_exercise.freezed.dart';

/// Exercice retenu pour le créneau de rappel d'une séance (ADR 0011).
@freezed
abstract class RecallExercise with _$RecallExercise {
  const factory RecallExercise({
    /// Séance du catalogue d'où vient l'exercice.
    required SessionSheet origin,
    required SheetExercise exercise,

    /// Élèves suivis qui n'ont pas encore validé l'exercice.
    required int pending,

    /// Élèves suivis.
    required int students,
  }) = _RecallExercise;
}

/// Choisit l'exercice du créneau de rappel de [sheet] (ADR 0011, décision 2).
///
/// Candidats : les exercices des séances d'`order` inférieur, de la plus
/// récente à la plus ancienne, et dans chaque séance du dernier exercice au
/// premier. Est retenu celui que **le plus d'élèves** de [validatedByStudent]
/// n'ont pas encore validé ; à égalité, le plus récent. Sans élève, ou quand
/// tout est validé, c'est donc le dernier exercice de la séance précédente.
///
/// `null` quand [sheet] n'a pas de créneau ou quand aucune séance ne la
/// précède.
RecallExercise? chooseRecallExercise({
  required SessionSheet sheet,
  required Iterable<SessionSheet> all,
  required Map<StudentId, Set<ExerciseRef>> validatedByStudent,
}) {
  if (sheet.recallSlot == null) return null;
  final earlier = [
    for (final s in all)
      if (s.order < sheet.order) s,
  ]..sort((a, b) => b.order.compareTo(a.order));
  RecallExercise? best;
  for (final origin in earlier) {
    for (final exercise in origin.exercises.reversed) {
      final pending = validatedByStudent.values
          .where((validated) => !validated.contains(exercise.ref))
          .length;
      if (best == null || pending > best.pending) {
        best = RecallExercise(
          origin: origin,
          exercise: exercise,
          pending: pending,
          students: validatedByStudent.length,
        );
      }
    }
  }
  return best;
}
