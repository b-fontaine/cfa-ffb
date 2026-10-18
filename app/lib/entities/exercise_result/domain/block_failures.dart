import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Résultats de [progress] sur les exercices pratiqués d'un bloc ([exercises],
/// dans l'ordre du bloc), hors exercices acquis au positionnement : leurs
/// anciens passages sont dormants (ADR 0008).
List<ExerciseResult> blockResults(
  List<ExerciseRef> exercises,
  StudentProgress progress,
) => [
  for (final exercise in exercises)
    if (!progress.acquiredExercises.contains(exercise))
      ?progress.results[exercise],
];

/// Résultat du bloc dont le dernier passage est le plus récent ; `null` si
/// l'élève n'a rien pratiqué du bloc.
ExerciseResult? latestBlockResult(
  List<ExerciseRef> exercises,
  StudentProgress progress,
) {
  final results = blockResults(exercises, progress);
  if (results.isEmpty) return null;
  return ([...results]..sort(compareLastAttempt)).last;
}

/// Ordre chronologique des derniers passages : date, puis rang dérivé du
/// passage dans sa séance (`lastAttemptRank`), puis
/// numéro d'exercice (dans une séance, on enchaîne les exercices dans l'ordre).
int compareLastAttempt(ExerciseResult a, ExerciseResult b) {
  final x = a.lastAttempt!;
  final y = b.lastAttempt!;
  final byDate = x.date.compareTo(y.date);
  if (byDate != 0) return byDate;
  final byPass = a.lastAttemptRank.compareTo(b.lastAttemptRank);
  return byPass != 0 ? byPass : a.exercise.number.compareTo(b.exercise.number);
}

/// Les élèves de [progress] dont le dernier passage sur le bloc ([exercises])
/// est un échec, avec la date de ce passage.
///
/// Définition unique de « échouer à une notion » : la sélection du rappel
/// (`selectRecall`) et les alertes de groupe l'appellent toutes deux.
Map<StudentId, DateTime> blockFailedStudents({
  required List<ExerciseRef> exercises,
  required Map<StudentId, StudentProgress> progress,
}) => {
  for (final entry in progress.entries)
    if (latestBlockResult(exercises, entry.value) case final latest?
        when latest.lastFailed)
      entry.key: latest.lastAttempt!.date,
};

/// Vrai quand [failed] élèves sur [members] atteignent la part d'échec
/// [sharePercent] (en %), sans arrondi : `failed / members >= share / 100`.
///
/// Définition unique du seuil de « échec de groupe », partagée par la sélection
/// du rappel et les alertes de groupe.
bool reachesGroupFailureShare({
  required int failed,
  required int members,
  required int sharePercent,
}) => failed * 100 >= sharePercent * members;
