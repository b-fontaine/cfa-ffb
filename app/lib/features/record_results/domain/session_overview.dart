import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_overview.freezed.dart';

/// Une séance ouverte : groupe, élèves présents, passages déjà saisis,
/// catalogue des exercices (pour choisir le suivant) et séance du catalogue
/// notée, si elle est connue.
@freezed
abstract class SessionOverview with _$SessionOverview {
  const factory SessionOverview({
    required SessionRecord session,
    required String groupName,
    required List<Student> students,
    required List<ExerciseAttempt> attempts,
    required ExerciseCatalogue catalogue,

    /// Passages au plus par élève, exercice et séance (règle R1, configurable).
    required int maxPassesPerExercise,

    /// Passages réussis cumulés pour valider un exercice (règle R1).
    required int passesRequired,

    /// Séance du catalogue notée (ADR 0007) ; `null` sans séance ou quand le
    /// catalogue ne la connaît plus.
    SheetOption? sheet,

    /// Progression dérivée (`StudentProgress.derive`) de chaque élève présent,
    /// acquis au positionnement compris : source du « n sur 5 ».
    @Default(<StudentId, StudentProgress>{})
    Map<StudentId, StudentProgress> progress,
  }) = _SessionOverview;

  const SessionOverview._();

  /// Passages déjà saisis dans cette séance pour l'élève et l'exercice, dans
  /// l'ordre de saisie.
  List<ExerciseAttempt> passesFor(StudentId studentId, ExerciseRef exercise) =>
      [
        for (final a in attempts)
          if (a.studentId == studentId && a.exercise == exercise) a,
      ];

  /// Nom évocateur de l'exercice dans la séance du catalogue notée ; `null`
  /// sans séance ou quand elle ne le nomme pas (le bloc et le numéro
  /// tiennent alors lieu de nom).
  String? exerciseName(ExerciseRef exercise) => sheet?.exerciseTitles[exercise];

  /// « n sur 5 » de la ligne de saisie : passages réussis cumulés (toutes
  /// séances) de l'élève sur l'exercice, tels que dérivés par
  /// `StudentProgress.derive` ; un exercice encore acquis au positionnement
  /// (ADR 0008) compte pour tous les passages requis.
  int passedCount(StudentId studentId, ExerciseRef exercise) {
    final studentProgress = progress[studentId];
    if (studentProgress == null) return 0;
    if (studentProgress.acquiredExercises.contains(exercise)) {
      return passesRequired;
    }
    return studentProgress.results[exercise]?.passedCount ?? 0;
  }
}
