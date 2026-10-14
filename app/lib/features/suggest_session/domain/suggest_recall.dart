import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/suggest_session/domain/recall_advice.dart';
import 'package:billard_cfa/features/suggest_session/domain/recall_selector.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : la notion à rappeler à un élève (R5), hors la notion en
/// cours d'enseignement ; `null` quand rien ne le justifie.
@injectable
class SuggestRecall {
  SuggestRecall(
    this._students,
    this._sessions,
    this._attempts,
    this._acquisitions,
    this._catalogue,
    this._config,
  );

  final StudentRepository _students;
  final SessionRecordRepository _sessions;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  Future<Result<RecallAdvice?>> call(StudentId studentId) =>
      runGuarded(() async {
        if (await _students.byId(studentId) == null) {
          throw NotFound('student', studentId.value);
        }
        final catalogue = await _catalogue.load();
        final progress = StudentProgress.derive(
          studentId: studentId,
          attempts: await _attempts.forStudent(studentId),
          acquisitions: await _acquisitions.forStudent(studentId),
          rates: catalogue.rates,
          config: _config,
        );
        final taught = catalogue.nextExercise(validated: progress.validated);
        final suggestion = selectRecall(
          catalogue: catalogue,
          progress: {studentId: progress},
          groupSessions: await _sessions.forStudent(studentId),
          mainBlockId: taught?.blockId ?? '',
          config: _config,
        );
        if (suggestion == null) return null;
        return RecallAdvice(
          blockId: suggestion.blockId,
          blockTitle: catalogue.blockById(suggestion.blockId)!.title,
          proposal: catalogue.blockById(suggestion.blockId)!.isProposal,
          exercise: suggestion.exercise,
          reason: suggestion.reason,
        );
      });
}
