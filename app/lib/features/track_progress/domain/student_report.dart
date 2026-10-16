import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/track_progress/domain/attendance.dart';
import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/shared/lib/attendance.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'student_report.freezed.dart';

/// Synthèse d'un élève : exercices validés, blocs, alertes actives,
/// assiduité.
@freezed
abstract class StudentReport with _$StudentReport {
  const factory StudentReport({
    required StudentId studentId,
    required int validatedCount,
    required int exerciseCount,
    required List<BlockProgress> blocks,
    required List<ExerciseResult> activeAlerts,
    required Attendance attendance,
  }) = _StudentReport;

  /// Dérive la synthèse des données chargées (fabrique pure, partagée par
  /// `GetStudentReport` et `GetStudentSheet`).
  ///
  /// [sessions] et [groups] : toutes les séances saisies et tous les groupes ;
  /// les séances du bloc et l'assiduité ne retiennent que celles qui
  /// concernent l'élève.
  factory StudentReport.derive({
    required StudentId studentId,
    required StudentProgress progress,
    required ExerciseCatalogue catalogue,
    required List<ExerciseAttempt> attempts,
    required List<SessionRecord> sessions,
    required List<Group> groups,
  }) => StudentReport(
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
      sessions: sessions,
      groups: groups,
    ),
  );
}
