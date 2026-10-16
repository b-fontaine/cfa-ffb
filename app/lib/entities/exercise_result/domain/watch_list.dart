import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'watch_list.freezed.dart';

/// Un élève à surveiller : l'exercice le plus alarmant de ses alertes
/// actives (R4) et le nombre de ses autres alertes.
@freezed
abstract class WatchedStudent with _$WatchedStudent {
  const factory WatchedStudent({
    required StudentId studentId,
    required ExerciseRef exercise,
    required AlertLevel alert,
    required int consecutiveFailures,

    /// Alertes actives sur d'autres exercices du même élève.
    required int otherAlerts,
  }) = _WatchedStudent;
}

/// Ordre unique des élèves à surveiller (accueil et bilan) : niveau
/// persistant avant attention, puis plus d'échecs consécutifs, puis
/// identifiant de l'élève (départage déterministe).
///
/// Le départage compare les identifiants comme des chaînes (ordre des unités
/// de code, majuscules avant minuscules) : il est stable mais ne suit pas
/// l'ordre alphabétique des prénoms.
int compareWatched(WatchedStudent a, WatchedStudent b) {
  final byAlarm = _compareAlarm(
    a.alert,
    a.consecutiveFailures,
    b.alert,
    b.consecutiveFailures,
  );
  return byAlarm != 0
      ? byAlarm
      : a.studentId.value.compareTo(b.studentId.value);
}

/// Niveau persistant avant attention, puis plus d'échecs consécutifs : le
/// critère commun aux deux tris (élèves et exercices d'un élève).
int _compareAlarm(
  AlertLevel levelA,
  int failuresA,
  AlertLevel levelB,
  int failuresB,
) {
  final byLevel = _levelRank(levelA).compareTo(_levelRank(levelB));
  return byLevel != 0 ? byLevel : failuresB.compareTo(failuresA);
}

int _levelRank(AlertLevel level) => level == AlertLevel.persistent ? 0 : 1;

/// Les élèves de [progress] ayant au moins une alerte active, un
/// [WatchedStudent] par élève.
///
/// Exercice le plus alarmant : niveau persistant avant attention, puis plus
/// d'échecs consécutifs, puis ordre d'enseignement ([catalogueOrder]). Liste
/// triée par [compareWatched].
/// Les alertes d'un exercice encore acquis sont déjà masquées par
/// `StudentProgress.activeAlerts`.
List<WatchedStudent> watchedStudents(
  Iterable<StudentProgress> progress, {
  required List<ExerciseRef> catalogueOrder,
}) {
  final position = {
    for (final (index, exercise) in catalogueOrder.indexed) exercise: index,
  };
  int byExercise(ExerciseResult a, ExerciseResult b) {
    final byAlarm = _compareAlarm(
      a.alert,
      a.consecutiveFailures,
      b.alert,
      b.consecutiveFailures,
    );
    if (byAlarm != 0) return byAlarm;
    return (position[a.exercise] ?? catalogueOrder.length).compareTo(
      position[b.exercise] ?? catalogueOrder.length,
    );
  }

  final watched = <WatchedStudent>[];
  for (final student in progress) {
    final alerts = [...student.activeAlerts]..sort(byExercise);
    if (alerts.isEmpty) continue;
    final worst = alerts.first;
    watched.add(
      WatchedStudent(
        studentId: student.studentId,
        exercise: worst.exercise,
        alert: worst.alert,
        consecutiveFailures: worst.consecutiveFailures,
        otherAlerts: alerts.length - 1,
      ),
    );
  }
  watched.sort(compareWatched);
  return List.unmodifiable(watched);
}
