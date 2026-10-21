import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_local_data_probe.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'realistic_backup.dart';
import 'snapshot_seed.dart';
import 'ui_world.dart';

/// Le build qui lit le club sur Firestore (`DATA_BACKEND=firestore`) avec, ou
/// sans, des données locales sur l'appareil (FB7c). Dans la scène, les dépôts
/// en mémoire jouent la base locale : ce que le bandeau annonce et ce que
/// l'export lit sont les mêmes données.
class LocalDataWorld {
  LocalDataWorld._();

  static InMemoryLocalDataProbe get probe =>
      getIt<LocalDataProbe>() as InMemoryLocalDataProbe;

  static InMemoryBackupFiles get files =>
      getIt<BackupFiles>() as InMemoryBackupFiles;

  /// Le build Firestore : l'aiguillage de l'application lit ce backend.
  static Future<void> clubBuild(WidgetTester tester) async {
    await UiWorld.prepare(tester);
    if (getIt.isRegistered<DataBackendChoice>()) {
      await getIt.unregister<DataBackendChoice>();
    }
    getIt.registerSingleton<DataBackendChoice>(
      const DataBackendChoice(DataBackend.firestore),
    );
  }

  /// Aucune donnée locale.
  static Future<void> keepNothing(WidgetTester tester) async {
    await clubBuild(tester);
    probe.inventory = LocalDataInventory.none;
  }

  /// Des données locales : la sauvegarde fictive de [backup] est posée dans
  /// les dépôts, et le relevé du démarrage en donne les compteurs.
  static Future<void> keep(WidgetTester tester, RealisticBackup backup) async {
    await clubBuild(tester);
    await tester.runAsync(() => _seed(backup.snapshot));
    final s = backup.snapshot;
    probe.inventory = LocalDataInventory(
      state: LocalStoreState.present,
      schemaVersion: 12,
      counts: LocalDataCounts(
        students: s.students.length,
        groups: s.groups.length,
        seasons: s.seasons.length,
        sessionRecords: s.sessionRecords.length,
        attempts: s.attempts.length,
        plannedSessions: s.plannedSessions.length,
        assessments: s.assessments.length,
        blockAcquisitions: s.blockAcquisitions.length,
        seasonArchives: s.seasonArchives.length,
      ),
    );
  }

  /// Le build local (drift) dont la sonde annonce quand même des données.
  static Future<void> announceUnderLocalBackend(
    WidgetTester tester,
    RealisticBackup backup,
  ) async {
    await keep(tester, backup);
    await getIt.unregister<DataBackendChoice>();
    getIt.registerSingleton<DataBackendChoice>(
      const DataBackendChoice(DataBackend.drift),
    );
  }

  /// Une base écrite par une version plus récente.
  static Future<void> keepNewer(WidgetTester tester) async {
    await clubBuild(tester);
    probe.inventory = const LocalDataInventory(
      state: LocalStoreState.newerSchema,
      schemaVersion: 99,
    );
  }

  static Future<void> _seed(BackupSnapshot s) => seedSnapshot(
    s,
    seasons: getIt<SeasonRepository>(),
    seasonArchives: getIt<SeasonArchiveRepository>(),
    students: getIt<StudentRepository>(),
    groups: getIt<GroupRepository>(),
    sessionRecords: getIt<SessionRecordRepository>(),
    attempts: getIt<AttemptRepository>(),
    acquisitions: getIt<AcquisitionRepository>(),
    acknowledgements: getIt<AcknowledgementRepository>(),
    assessments: getIt<AssessmentRepository>(),
    plannedSessions: getIt<SessionRepository>(),
    settings: getIt<SettingsRepository>(),
  );

  /// Le fichier enregistré, relu par le codec.
  static BackupSnapshot savedFile() {
    final saved = files.lastSaved;
    expect(saved, isNotNull, reason: 'aucun fichier enregistré');
    expect(saved!.fileName, endsWith('.json'));
    return BackupCodec().decode(saved.content);
  }
}
