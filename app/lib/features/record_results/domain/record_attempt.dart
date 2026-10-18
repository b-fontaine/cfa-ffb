import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : enregistrer un passage d'un élève sur un exercice
/// (R1 validation, R2 exercice suivant, R4 alerte).
@injectable
class RecordAttempt {
  RecordAttempt(
    this._sessions,
    this._attempts,
    this._acquisitions,
    this._catalogue,
    this._ids,
    this._config,
  );

  final SessionRecordRepository _sessions;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final CatalogueRepository _catalogue;
  final IdGenerator _ids;
  final RulesConfig _config;

  Future<Result<RecordedAttempt>> call({
    required SessionId sessionId,
    required StudentId studentId,
    required ExerciseRef exercise,
    required int potted,
    required int total,
  }) => runGuarded(() async {
    final session = await _sessions.byId(sessionId);
    if (session == null) throw NotFound('session', sessionId.value);
    if (!session.present.contains(studentId)) {
      throw const InvariantViolation(InvariantCode.studentNotPresent);
    }
    final catalogue = await _catalogue.load();
    final spec = catalogue.exercise(exercise);
    if (spec == null) {
      throw const InvariantViolation(InvariantCode.unknownExercise);
    }
    if (!spec.rate.acceptsTotal(total)) {
      throw const InvariantViolation(InvariantCode.totalBelowSheet);
    }
    final inSession = (await _attempts.forSession(sessionId))
        .where((a) => a.studentId == studentId && a.exercise == exercise)
        .length;
    if (inSession >= _config.maxPassesPerExercisePerSession) {
      throw const InvariantViolation(InvariantCode.passesLimitReached);
    }
    final attempt = ExerciseAttempt(
      id: AttemptId(_ids.next()),
      studentId: studentId,
      sessionId: sessionId,
      exercise: exercise,
      date: session.date,
      potted: potted,
      total: total,
    );
    final history = await _attempts.forStudent(studentId);
    final acquisitions = await _acquisitions.forStudent(studentId);
    await _attempts.add(attempt);
    StudentProgress derive(List<ExerciseAttempt> attempts) =>
        StudentProgress.derive(
          studentId: studentId,
          attempts: attempts,
          acquisitions: acquisitions,
          rates: catalogue.rates,
          config: _config,
        );
    final before = derive(history);
    final progress = derive([...history, attempt]);
    // Un passage daté du jour du positionnement ou après reprend la main sur
    // son exercice (ADR 0008) : ce n'est pas une validation à fêter.
    final wasAcquired = before.acquiredExercises.contains(exercise);
    final resumed =
        wasAcquired && !progress.acquiredExercises.contains(exercise);
    final passed = attempt.isPassed(spec.rate);
    final result = progress.results[exercise]!;
    return RecordedAttempt(
      attempt: attempt,
      result: result,
      passed: passed,
      justValidated:
          passed &&
          result.passedCount == _config.passesRequired &&
          !wasAcquired,
      resumedFromPlacement: resumed,
      nextExercise: catalogue.nextExercise(validated: progress.validated),
    );
  });
}
