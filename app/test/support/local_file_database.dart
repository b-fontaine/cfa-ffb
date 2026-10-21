import 'dart:io';
import 'dart:typed_data';

import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/drift_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_local_data_probe.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/export_local_backup.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:billard_cfa/shared/persistence/drift_storage_status.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drift_support.dart';
import 'snapshot_seed.dart';

/// Une vraie base SQLite **dans un fichier** d'un dossier temporaire, comme
/// celle d'un appareil (FB7c) : de quoi prouver ce que la détection et
/// l'export font — ou ne font pas — au fichier.
class LocalFileDatabase {
  LocalFileDatabase._(this.directory);

  final Directory directory;

  static Future<LocalFileDatabase> create() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final directory = await Directory.systemTemp.createTemp('billard_cfa_fb7c');
    addTearDown(() => directory.delete(recursive: true));
    return LocalFileDatabase._(directory);
  }

  DatabaseSettings get settings => settingsFor(directory);

  static DatabaseSettings settingsFor(Directory directory) => DatabaseSettings(
    native: DriftNativeOptions(
      databaseDirectory: () async => directory,
      tempDirectoryPath: () async => directory.path,
    ),
  );

  File get file => File('${directory.path}/$appDatabaseName.sqlite');

  /// Les noms des fichiers du dossier (la base, et jamais un journal ou un
  /// fichier de plus laissé par une lecture).
  List<String> get fileNames =>
      directory.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  Uint8List get bytes => file.readAsBytesSync();

  /// La version du schéma écrite dans l'en-tête SQLite (octets 60 à 63, grand
  /// boutiste) : une lecture du fichier sans SQLite.
  int get userVersion => ByteData.sublistView(bytes, 60, 64).getUint32(0);

  /// Écrit [version] dans l'en-tête, comme le ferait une autre version de
  /// l'application.
  void forceUserVersion(int version) {
    final data = bytes;
    ByteData.sublistView(data, 60, 64).setUint32(0, version);
    file.writeAsBytesSync(data);
  }

  /// Ouvre la base comme l'application (migrée à la version courante).
  AppDatabase open() =>
      openAppDatabase(status: DriftStorageStatus(), settings: settings);

  /// Crée la base avec le contenu de [snapshot], puis la ferme.
  Future<void> populate(BackupSnapshot snapshot) async {
    final db = open();
    final repos = DriftRepos(db);
    await seedSnapshot(
      snapshot,
      seasons: repos.seasons,
      seasonArchives: repos.seasonArchives,
      students: repos.students,
      groups: repos.groups,
      sessionRecords: repos.sessionRecords,
      attempts: repos.attempts,
      acquisitions: repos.acquisitions,
      acknowledgements: repos.acknowledgements,
      assessments: repos.assessments,
      plannedSessions: repos.plannedSessions,
      settings: repos.settings,
    );
    await db.close();
  }
}

/// Les dépôts drift d'une base ouverte.
class DriftRepos {
  DriftRepos(AppDatabase db)
    : seasons = DriftSeasonRepository(db, TickingClock()),
      seasonArchives = DriftSeasonArchiveRepository(db),
      students = DriftStudentRepository(db, TickingClock()),
      groups = DriftGroupRepository(db, TickingClock()),
      sessionRecords = DriftSessionRecordRepository(db, TickingClock()),
      attempts = DriftAttemptRepository(db, TickingClock()),
      acquisitions = DriftAcquisitionRepository(db, TickingClock()),
      acknowledgements = DriftAcknowledgementRepository(db, TickingClock()),
      assessments = DriftAssessmentRepository(db, TickingClock()),
      plannedSessions = DriftSessionRepository(db, TickingClock()),
      settings = DriftSettingsRepository(db, TickingClock());

  final DriftSeasonRepository seasons;
  final DriftSeasonArchiveRepository seasonArchives;
  final DriftStudentRepository students;
  final DriftGroupRepository groups;
  final DriftSessionRecordRepository sessionRecords;
  final DriftAttemptRepository attempts;
  final DriftAcquisitionRepository acquisitions;
  final DriftAcknowledgementRepository acknowledgements;
  final DriftAssessmentRepository assessments;
  final DriftSessionRepository plannedSessions;
  final DriftSettingsRepository settings;

  /// L'export de la base locale, tel que le câble `LocalExportModule`.
  ///
  /// [inventory] : le relevé du démarrage (`probeLocalStore`), dont l'export
  /// tire la date du fichier.
  ExportLocalBackup exporter(LocalDataInventory inventory) => ExportLocalBackup(
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
    BackupCodec(),
    InMemoryLocalDataProbe()..inventory = inventory,
  );
}
