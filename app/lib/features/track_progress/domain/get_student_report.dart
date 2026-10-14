import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/features/track_progress/domain/attendance.dart';
import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/features/track_progress/domain/student_report.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : synthèse de progression d'un élève sur le catalogue.
@injectable
class GetStudentReport {
  GetStudentReport(
    this._attempts,
    this._sessions,
    this._groups,
    this._catalogue,
    this._config,
  );

  final AttemptRepository _attempts;
  final SessionRecordRepository _sessions;
  final GroupRepository _groups;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  Future<Result<StudentReport>> call(StudentId studentId) =>
      runGuarded(() async {
        final catalogue = await _catalogue.load();
        final attempts = await _attempts.forStudent(studentId);
        final sessions = await _sessions.forStudent(studentId);
        final progress = StudentProgress.derive(
          studentId: studentId,
          attempts: attempts,
          rates: catalogue.rates,
          config: _config,
        );
        return StudentReport(
          studentId: studentId,
          validatedCount: progress.validated.length,
          exerciseCount: catalogue.exercises.length,
          blocks: [
            for (final block in catalogue.blocks)
              BlockProgress.of(
                block: block,
                progress: progress,
                sessionsSpent: sessionsSpentOnBlock(
                  block: block,
                  studentId: studentId,
                  attempts: attempts,
                  sessions: sessions,
                ),
              ),
          ],
          activeAlerts: progress.activeAlerts,
          attendance: attendanceOf(
            studentId: studentId,
            sessions: await _sessions.all(),
            groups: await _groups.all(),
          ),
        );
      });
}
