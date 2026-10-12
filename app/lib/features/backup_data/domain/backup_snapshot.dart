import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_snapshot.freezed.dart';

/// Contenu complet d'une sauvegarde : toutes les données du club, hors
/// métadonnées de persistance (horodatages, suppressions logiques).
@freezed
abstract class BackupSnapshot with _$BackupSnapshot {
  const factory BackupSnapshot({
    @Default([]) List<Season> seasons,
    @Default([]) List<Student> students,
    @Default([]) List<Group> groups,
    @Default([]) List<SessionRecord> sessionRecords,
    @Default([]) List<ExerciseAttempt> attempts,
    @Default([]) List<MaturityAssessment> assessments,
    @Default([]) List<Session> plannedSessions,
  }) = _BackupSnapshot;
}
