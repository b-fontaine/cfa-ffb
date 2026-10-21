import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_local_data_probe.dart';
import 'package:billard_cfa/features/backup_data/domain/export_local_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/local_export_cubit.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExport extends Mock implements ExportLocalBackup;

class _ThrowingFiles extends InMemoryBackupFiles {
  @override
  Future<bool> save({required String fileName, required String content}) =>
      throw StateError('disque plein');
}

ImportSummary _summary({int students = 0, int attempts = 0, int seasons = 1}) =>
    ImportSummary(
      seasons: seasons,
      students: students,
      groups: 0,
      sessionRecords: 0,
      attempts: attempts,
      assessments: 0,
      plannedSessions: 0,
      blockAcquisitions: 0,
    );

void main() {
  late _MockExport export;
  late InMemoryLocalDataProbe probe;
  late InMemoryBackupFiles files;

  LocalExportCubit build([InMemoryBackupFiles? custom]) =>
      LocalExportCubit(export, custom ?? files, probe);

  setUp(() {
    export = _MockExport();
    probe = InMemoryLocalDataProbe();
    files = InMemoryBackupFiles();
  });

  void exports(ImportSummary summary) => when(() => export()).thenAnswer(
    (_) async => Ok(LocalBackup(content: '{"file":1}', summary: summary)),
  );

  test('prepare shows what the file holds before anything is saved', () async {
    exports(_summary(students: 6, attempts: 72));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.prepare();

    expect(cubit.state.status, LocalExportStatus.ready);
    expect(cubit.state.summary!.students, 6);
    expect(cubit.state.canSave, isTrue);
    expect(files.lastSaved, isNull);
  });

  test('save writes the prepared file and reports it', () async {
    exports(_summary(students: 6, attempts: 72));
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.prepare();

    await cubit.save(fileName: 'donnees.json');

    expect(cubit.state.status, LocalExportStatus.saved);
    expect(files.lastSaved, (fileName: 'donnees.json', content: '{"file":1}'));
  });

  test('an empty file cannot be saved, never reported as saved', () async {
    exports(_summary());
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.prepare();

    await cubit.save(fileName: 'donnees.json');

    expect(cubit.state.empty, isTrue);
    expect(cubit.state.canSave, isFalse);
    expect(cubit.state.status, isNot(LocalExportStatus.saved));
    expect(files.lastSaved, isNull);
  });

  test('cancelling the location saves nothing and allows a new try', () async {
    exports(_summary(students: 1));
    files.cancelSave = true;
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.prepare();

    await cubit.save(fileName: 'donnees.json');

    expect(cubit.state.status, LocalExportStatus.cancelled);
    expect(cubit.state.canSave, isTrue);
    expect(files.lastSaved, isNull);
  });

  test(
    'a save that throws is reported as a failed save, not as saved',
    () async {
      exports(_summary(students: 1));
      final cubit = build(_ThrowingFiles());
      addTearDown(cubit.close);
      await cubit.prepare();

      await cubit.save(fileName: 'donnees.json');

      expect(cubit.state.status, LocalExportStatus.saveFailed);
    },
  );

  test(
    'a base written by a newer version is refused without being read',
    () async {
      probe.inventory = const LocalDataInventory(
        state: LocalStoreState.newerSchema,
        schemaVersion: 99,
      );
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.prepare();

      expect(cubit.state.status, LocalExportStatus.newerSchema);
      verifyNever(() => export());
    },
  );

  test('an unreadable base is never presented as empty', () async {
    probe.inventory = const LocalDataInventory(
      state: LocalStoreState.unreadable,
    );
    when(() => export()).thenAnswer(
      (_) async => const Err(InvariantViolation(InvariantCode.backupInvalid)),
    );
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.prepare();

    expect(cubit.state.status, LocalExportStatus.unreadable);
    expect(cubit.state.empty, isFalse);
  });

  test(
    'a probe that said unreadable does not forbid reading the base',
    () async {
      // Le relevé du démarrage a pu échouer (stockage bloqué, erreur de
      // transport) alors que la lecture par les dépôts réussit.
      probe.inventory = const LocalDataInventory(
        state: LocalStoreState.unreadable,
      );
      exports(_summary(students: 3, attempts: 1));
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.prepare();

      expect(cubit.state.status, LocalExportStatus.ready);
      expect(cubit.state.summary!.students, 3);
    },
  );

  test('retrying reads the base again', () async {
    when(() => export()).thenAnswer(
      (_) async => const Err(InvariantViolation(InvariantCode.backupInvalid)),
    );
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.prepare();
    expect(cubit.state.status, LocalExportStatus.unreadable);

    exports(_summary(students: 2));
    await cubit.prepare();

    expect(cubit.state.status, LocalExportStatus.ready);
    verify(() => export()).called(2);
  });

  test('a read that fails is unreadable, not empty', () async {
    when(() => export()).thenAnswer(
      (_) async => const Err(InvariantViolation(InvariantCode.backupInvalid)),
    );
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.prepare();

    expect(cubit.state.status, LocalExportStatus.unreadable);
  });

  test('a read that throws is unreadable, not a crash', () async {
    when(() => export()).thenThrow(StateError('SQLite'));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.prepare();

    expect(cubit.state.status, LocalExportStatus.unreadable);
  });

  test('an older base says it was upgraded when it opened', () async {
    probe.inventory = const LocalDataInventory(
      state: LocalStoreState.present,
      schemaVersion: 11,
      migrationPending: true,
    );
    exports(_summary(students: 1));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.prepare();

    expect(cubit.state.migrated, isTrue);
  });
}
