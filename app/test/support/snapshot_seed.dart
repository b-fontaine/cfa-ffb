import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';

/// Pose [snapshot] dans des dépôts, dans l'ordre d'un import local (sans les
/// règles de l'import : le fichier fictif est celui de `RealisticBackup`,
/// dont les séances citent le catalogue de test).
Future<void> seedSnapshot(
  BackupSnapshot snapshot, {
  required SeasonRepository seasons,
  required SeasonArchiveRepository seasonArchives,
  required StudentRepository students,
  required GroupRepository groups,
  required SessionRecordRepository sessionRecords,
  required AttemptRepository attempts,
  required AcquisitionRepository acquisitions,
  required AcknowledgementRepository acknowledgements,
  required AssessmentRepository assessments,
  required SessionRepository plannedSessions,
  required SettingsRepository settings,
}) async {
  final s = snapshot;
  if (s.settings != null) await settings.save(s.settings!);
  for (final season in s.seasons) {
    await seasons.save(season);
  }
  for (final archive in s.seasonArchives) {
    await seasonArchives.save(archive);
  }
  for (final student in s.students) {
    await students.save(student);
  }
  for (final group in s.groups) {
    await groups.save(group);
  }
  for (final record in s.sessionRecords) {
    await sessionRecords.save(record);
  }
  for (final attempt in s.attempts) {
    await attempts.add(attempt);
  }
  for (final acquisition in s.blockAcquisitions) {
    await acquisitions.add(acquisition);
  }
  for (final ack in s.alertAcknowledgements ?? const <AlertAcknowledgement>[]) {
    await acknowledgements.add(ack);
  }
  for (final assessment in s.assessments) {
    await assessments.add(assessment);
  }
  for (final session in s.plannedSessions) {
    await plannedSessions.add(session);
  }
}
