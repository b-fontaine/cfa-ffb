import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/track_progress/domain/exercise_curve.dart';
import 'package:billard_cfa/features/track_progress/domain/student_report.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : la fiche complète d'un élève (blocs, courbes, suivant,
/// assiduité, dernier bilan).
@injectable
class GetStudentSheet {
  GetStudentSheet(
    this._students,
    this._attempts,
    this._sessions,
    this._groups,
    this._assessments,
    this._catalogue,
    this._config,
  );

  final StudentRepository _students;
  final AttemptRepository _attempts;
  final SessionRecordRepository _sessions;
  final GroupRepository _groups;
  final AssessmentRepository _assessments;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  Future<Result<StudentSheet>> call(StudentId studentId) =>
      runGuarded(() async {
        final student = await _students.byId(studentId);
        if (student == null) throw NotFound('student', studentId.value);
        final catalogue = await _catalogue.load();
        final attempts = await _attempts.forStudent(studentId);
        final assessments = await _assessments.forStudent(studentId);
        final progress = StudentProgress.derive(
          studentId: studentId,
          attempts: attempts,
          rates: catalogue.rates,
          config: _config,
        );
        final latest = assessments.lastOrNull;
        return StudentSheet(
          student: student,
          catalogue: catalogue,
          report: StudentReport.derive(
            studentId: studentId,
            progress: progress,
            catalogue: catalogue,
            attempts: attempts,
            sessions: await _sessions.all(),
            groups: await _groups.all(),
          ),
          series: [
            for (final spec in catalogue.exercises)
              if (progress.results[spec.ref] case final result?)
                ExerciseSeries(
                  exercise: spec.ref,
                  rate: spec.rate,
                  status: result.status,
                  alert: result.alert,
                  consecutiveFailures: result.consecutiveFailures,
                  passedCount: result.passedCount,
                  curve: ExerciseCurve.of(result, _config),
                ),
          ],
          nextExercise: catalogue.nextExercise(validated: progress.validated),
          passesRequired: _config.passesRequired,
          assessmentCount: assessments.length,
          latestAssessment: latest,
          readinessHint: latest?.readinessHint(_config),
        );
      });
}
