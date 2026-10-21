import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/drift_settings_repository.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/export_local_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:injectable/injectable.dart';

/// L'export de la base **locale** (FB7c). En production, il lit **toujours
/// les dépôts drift**, quel que soit le backend choisi pour le reste de
/// l'application : c'est justement l'export des données que le build
/// Firestore ne lit plus. Les scénarios BDD et les tests (`Environment.test`)
/// n'ont qu'un jeu de dépôts en mémoire : il joue la base locale.
@module
abstract class LocalExportModule {
  @Environment(Environment.prod)
  @injectable
  ExportLocalBackup exportLocalBackup(
    DriftSeasonRepository seasons,
    DriftSeasonArchiveRepository seasonArchives,
    DriftStudentRepository students,
    DriftGroupRepository groups,
    DriftSessionRecordRepository sessionRecords,
    DriftAttemptRepository attempts,
    DriftAcquisitionRepository acquisitions,
    DriftAcknowledgementRepository acknowledgements,
    DriftAssessmentRepository assessments,
    DriftSessionRepository plannedSessions,
    DriftSettingsRepository settings,
    BackupCodec codec,
    LocalDataProbe probe,
  ) => ExportLocalBackup(
    BackupSnapshotReader(
      seasons,
      seasonArchives,
      students,
      groups,
      sessionRecords,
      attempts,
      acquisitions,
      acknowledgements,
      assessments,
      plannedSessions,
    ),
    settings,
    codec,
    probe,
  );

  @Environment(Environment.test)
  @injectable
  ExportLocalBackup testExportLocalBackup(
    SeasonRepository seasons,
    SeasonArchiveRepository seasonArchives,
    StudentRepository students,
    GroupRepository groups,
    SessionRecordRepository sessionRecords,
    AttemptRepository attempts,
    AcquisitionRepository acquisitions,
    AcknowledgementRepository acknowledgements,
    AssessmentRepository assessments,
    SessionRepository plannedSessions,
    SettingsRepository settings,
    BackupCodec codec,
    LocalDataProbe probe,
  ) => ExportLocalBackup(
    BackupSnapshotReader(
      seasons,
      seasonArchives,
      students,
      groups,
      sessionRecords,
      attempts,
      acquisitions,
      acknowledgements,
      assessments,
      plannedSessions,
    ),
    settings,
    codec,
    probe,
  );
}
