import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/watch_list.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_review.freezed.dart';

/// Les passages saisis d'un exercice pendant la séance.
@freezed
abstract class ExercisePasses with _$ExercisePasses {
  const factory ExercisePasses({
    required ExerciseRef exercise,

    /// Passages saisis (tous élèves) et ceux réussis au taux requis.
    required int passes,
    required int passed,
  }) = _ExercisePasses;
}

/// Un exercice validé par cette saisie (pas avant).
@freezed
abstract class NewValidation with _$NewValidation {
  const factory NewValidation({
    required StudentId studentId,
    required ExerciseRef exercise,
  }) = _NewValidation;
}

/// Ce que la saisie a produit, dérivé des seuls passages (fonction pure).
@freezed
abstract class SessionOutcome with _$SessionOutcome {
  const factory SessionOutcome({
    /// Passages saisis et réussis, tous exercices.
    @Default(0) int totalPasses,
    @Default(0) int totalPassed,

    /// Passages par exercice, dans l'ordre d'enseignement.
    @Default(<ExercisePasses>[]) List<ExercisePasses> byExercise,

    /// Exercices nouvellement validés par cette saisie, par élève.
    @Default(<NewValidation>[]) List<NewValidation> validations,

    /// Élèves présents sans aucun passage dans cette saisie.
    @Default(<StudentId>[]) List<StudentId> unrated,

    /// Élèves présents ayant une alerte active (après cette saisie).
    @Default(<WatchedStudent>[]) List<WatchedStudent> watched,
  }) = _SessionOutcome;

  const SessionOutcome._();

  /// La saisie ne compte aucun passage.
  bool get isEmpty => totalPasses == 0;
}

/// Le bilan d'une séance donnée : ce qui a été saisi, ce qui a été validé,
/// qui surveiller, et de quoi proposer la suite.
@freezed
abstract class SessionReview with _$SessionReview {
  const factory SessionReview({
    required SessionRecord record,
    required SessionOutcome outcome,

    /// Date proposée pour la séance suivante : même jour de la semaine, la
    /// semaine suivante, strictement après aujourd'hui.
    required DateTime proposedDate,

    /// Séance du catalogue notée ; `null` si la saisie n'en a pas ou si le
    /// catalogue ne la connaît plus.
    SheetOption? sheet,

    /// Groupe ; `null` quand il n'existe plus.
    Group? group,

    /// Les élèves présents.
    @Default(<StudentId, Student>{}) Map<StudentId, Student> students,

    /// Séances planifiées du groupe datées d'après aujourd'hui.
    @Default(<Session>[]) List<Session> upcoming,

    /// Titre des blocs, pour libeller les exercices du bilan.
    @Default(<String, BlockLabel>{}) Map<String, BlockLabel> blockLabels,
  }) = _SessionReview;

  const SessionReview._();

  /// La séance planifiée du groupe pour [sheet], datée d'après aujourd'hui ;
  /// `null` quand elle n'est pas encore planifiée.
  Session? plannedFor(SheetId sheet) =>
      upcoming.where((s) => s.sheetId == sheet).firstOrNull;
}
