import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/exercise_result/domain/watch_list.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';

/// Le bilan chiffré de [record] : passages par exercice, exercices
/// nouvellement validés par cette saisie (validés avec tous les passages
/// moins validés sans ceux de la saisie, acquis compris), présents sans
/// passage et présents à surveiller.
///
/// [attempts] : les passages du club (toutes séances). Pure : aucun dépôt.
SessionOutcome reviewSession({
  required SessionRecord record,
  required List<ExerciseAttempt> attempts,
  required List<BlockAcquisition> acquisitions,
  required ExerciseCatalogue catalogue,
  required RulesConfig config,
  List<AlertAcknowledgement> acknowledgements = const [],
}) {
  final order = {
    for (final (index, spec) in catalogue.exercises.indexed) spec.ref: index,
  };
  int position(ExerciseRef exercise) => order[exercise] ?? order.length;

  final entered = [
    for (final attempt in attempts)
      if (attempt.sessionId == record.id) attempt,
  ];
  final others = [
    for (final attempt in attempts)
      if (attempt.sessionId != record.id) attempt,
  ];

  // Passages par exercice, dans l'ordre d'enseignement.
  final totals = <ExerciseRef, ({int passes, int passed})>{};
  for (final attempt in entered) {
    final rate = catalogue.rates[attempt.exercise];
    if (rate == null) {
      throw const InvariantViolation(InvariantCode.unknownExercise);
    }
    final known = totals[attempt.exercise] ?? (passes: 0, passed: 0);
    totals[attempt.exercise] = (
      passes: known.passes + 1,
      passed: known.passed + (attempt.isPassed(rate) ? 1 : 0),
    );
  }
  final byExercise = [
    for (final entry in totals.entries)
      ExercisePasses(
        exercise: entry.key,
        passes: entry.value.passes,
        passed: entry.value.passed,
      ),
  ]..sort((a, b) => position(a.exercise).compareTo(position(b.exercise)));

  StudentProgress progressOf(StudentId student, List<ExerciseAttempt> from) =>
      StudentProgress.derive(
        studentId: student,
        attempts: from,
        acquisitions: acquisitions,
        acknowledgements: acknowledgements,
        rates: catalogue.rates,
        config: config,
      );

  // Validé après (tous les passages) moins validé avant (sans ceux de la
  // saisie) : exact quel que soit le nombre de passages requis.
  final rated = {for (final attempt in entered) attempt.studentId};
  final afterByStudent = {
    for (final student in {...record.present, ...rated})
      student: progressOf(student, attempts),
  };
  final validations =
      <NewValidation>[
        for (final entry in afterByStudent.entries)
          for (final exercise in entry.value.validated.difference(
            progressOf(entry.key, others).validated,
          ))
            NewValidation(studentId: entry.key, exercise: exercise),
      ]..sort((a, b) {
        final byStudent = a.studentId.value.compareTo(b.studentId.value);
        return byStudent != 0
            ? byStudent
            : position(a.exercise).compareTo(position(b.exercise));
      });

  return SessionOutcome(
    totalPasses: entered.length,
    totalPassed: byExercise.fold(0, (sum, line) => sum + line.passed),
    byExercise: List.unmodifiable(byExercise),
    validations: List.unmodifiable(validations),
    unrated: List.unmodifiable(
      <StudentId>[
        for (final student in record.present)
          if (!rated.contains(student)) student,
      ]..sort((a, b) => a.value.compareTo(b.value)),
    ),
    watched: watchedStudents(
      [for (final student in record.present) afterByStudent[student]!],
      catalogueOrder: [for (final spec in catalogue.exercises) spec.ref],
    ),
  );
}
