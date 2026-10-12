import 'dart:io';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/data/file_picker_backup_files.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/storage_status.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart' show Environment;

void main() {
  late Directory directory;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await getIt.reset();
    directory = await Directory.systemTemp.createTemp('billard_cfa_di');
  });
  tearDown(() async {
    await getIt.reset();
    await directory.delete(recursive: true);
  });

  Future<void> configureProduction() => configureDependencies(
    settings: DatabaseSettings(
      native: DriftNativeOptions(
        databaseDirectory: () async => directory,
        tempDirectoryPath: () async => directory.path,
      ),
    ),
  );

  test('production wires SQLite repositories and UUID identifiers', () async {
    await configureProduction();

    expect(getIt<StudentRepository>(), isA<DriftStudentRepository>());
    expect(getIt<AttemptRepository>(), isA<DriftAttemptRepository>());
    expect(getIt<UnitOfWork>(), isA<DriftUnitOfWork>());
    expect(getIt<IdGenerator>(), isA<UuidV4Generator>());
    expect(
      File('${directory.path}/$appDatabaseName.sqlite').existsSync(),
      isTrue,
    );
  });

  test('production reports a persistent native storage', () async {
    await configureProduction();

    final status = getIt<StorageStatus>();

    expect(status.implementation, StorageImplementation.nativeFile);
    expect(status.implementation.persistent, isTrue);
  });

  test('production can export its (empty) database', () async {
    await configureProduction();

    final result = await getIt<ExportBackup>()();

    expect(result, isA<Ok<String>>());
  });

  test('the test environment keeps repositories in memory', () async {
    await configureDependencies(environment: Environment.test);

    expect(getIt<StudentRepository>(), isNot(isA<DriftStudentRepository>()));
    expect(getIt<IdGenerator>(), isA<SequentialIdGenerator>());
    expect(getIt<StorageStatus>(), isA<InMemoryStorageStatus>());
    expect(getIt<BackupFiles>(), isA<InMemoryBackupFiles>());
  });

  test('production saves backups through the file picker', () async {
    await configureProduction();

    expect(getIt<BackupFiles>(), isA<FilePickerBackupFiles>());
  });
}
