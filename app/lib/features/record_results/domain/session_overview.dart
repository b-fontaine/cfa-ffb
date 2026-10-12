import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_overview.freezed.dart';

/// Une séance ouverte : groupe, élèves présents, passages déjà saisis et
/// catalogue des exercices (pour choisir le suivant).
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
  }) = _SessionOverview;

  const SessionOverview._();

  /// Passages déjà saisis dans cette séance pour l'élève et l'exercice.
  int passesOf(StudentId studentId, ExerciseRef exercise) => attempts
      .where((a) => a.studentId == studentId && a.exercise == exercise)
      .length;
}
