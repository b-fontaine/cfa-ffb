import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/suggest_session/domain/recall_selector.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';

/// R6 : séance suggérée pour un groupe de [audience].
///
/// - notion principale : celle de l'exercice suivant le plus fréquent parmi
///   les élèves (égalité : plus petit `teachingOrder`) ;
/// - exercices : le suivant dominant puis ses voisins du même bloc, en nombre
///   fixé par la configuration, tous distincts ;
/// - rappel (si la configuration l'autorise, R5) ;
/// - phases : minutage de la configuration, somme égale à la durée du public.
///
/// Lève [InvariantViolation] `nothingToTeach` quand tous les élèves ont
/// terminé le niveau, `noStudents` sans élève.
SessionPlan planSession({
  required ExerciseCatalogue catalogue,
  required Audience audience,
  required Map<StudentId, StudentProgress> progress,
  required List<SessionRecord> groupSessions,
  required RulesConfig config,
}) {
  if (progress.isEmpty) {
    throw const InvariantViolation(InvariantCode.noStudents);
  }
  final next = [
    for (final student in progress.values)
      ?catalogue.nextExercise(validated: student.validated),
  ];
  if (next.isEmpty) {
    throw const InvariantViolation(InvariantCode.nothingToTeach);
  }
  int orderOf(String blockId) => catalogue.blockById(blockId)!.teachingOrder;
  final mainBlockId = _mostFrequent<String>(
    next.map((ref) => ref.blockId),
    orderOf,
  );
  final first = _mostFrequent<ExerciseRef>(
    next.where((ref) => ref.blockId == mainBlockId),
    (ref) => ref.number,
  );
  final shape = config.shapes[audience]!;
  final size = catalogue.blockById(mainBlockId)!.exercises.length;
  final neighbours = [
    for (var n = first.number; n <= size; n++) n,
    for (var n = first.number - 1; n >= 1; n--) n,
  ].take(shape.exerciseCount);
  final recall = shape.recallCount == 0
      ? null
      : selectRecall(
          catalogue: catalogue,
          progress: progress,
          groupSessions: groupSessions,
          mainBlockId: mainBlockId,
          config: config,
        );
  return SessionPlan(
    audience: audience,
    durationMinutes: audience.sessionDuration.inMinutes,
    mainBlockId: mainBlockId,
    exercises: [
      for (final n in neighbours) ExerciseRef(blockId: mainBlockId, number: n),
    ],
    phases: shape.phases,
    maxPassesPerExercise: config.maxPassesPerExercisePerSession,
    recallBlockId: recall?.blockId,
    recallExercise: recall?.exercise,
    recallReason: recall?.reason,
  );
}

/// Valeur la plus fréquente ; égalité : plus petite clé [tieBreak].
T _mostFrequent<T>(Iterable<T> values, int Function(T) tieBreak) {
  final counts = <T, int>{};
  for (final value in values) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  final ranked = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : tieBreak(a).compareTo(tieBreak(b));
    });
  return ranked.first;
}
