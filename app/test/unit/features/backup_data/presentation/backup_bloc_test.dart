import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/domain/preview_backup.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/storage_status.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExport extends Mock implements ExportBackup;

class _MockPreview extends Mock implements PreviewBackup;

class _MockImport extends Mock implements ImportBackup;

void main() {
  late _MockExport export;
  late _MockPreview preview;
  late _MockImport import;
  late InMemoryBackupFiles files;
  late InMemoryStorageStatus storage;
  const summary = ImportSummary(
    seasons: 1,
    students: 2,
    groups: 1,
    sessionRecords: 0,
    attempts: 3,
    assessments: 0,
    plannedSessions: 0,
    blockAcquisitions: 0,
  );

  setUp(() {
    export = _MockExport();
    preview = _MockPreview();
    import = _MockImport();
    files = InMemoryBackupFiles();
    storage = InMemoryStorageStatus();
  });

  BackupBloc build() => BackupBloc(export, preview, import, files, storage);

  blocTest<BackupBloc, BackupState>(
    'knows a persistent storage',
    build: build,
    act: (bloc) => bloc.add(const BackupEvent.started()),
    verify: (bloc) {
      expect(bloc.state.persistent, isTrue);
      expect(bloc.state.storageReasons, isEmpty);
    },
  );

  blocTest<BackupBloc, BackupState>(
    'warns when the storage is volatile',
    build: () {
      storage
        ..implementation = StorageImplementation.inMemory
        ..degradationReasons = ['OPFS indisponible'];
      return build();
    },
    act: (bloc) => bloc.add(const BackupEvent.started()),
    expect: () => [
      const BackupState(
        persistent: false,
        storageReasons: ['OPFS indisponible'],
      ),
    ],
  );

  group('export', () {
    blocTest<BackupBloc, BackupState>(
      'saves the exported content under the given name',
      build: () {
        when(() => export()).thenAnswer((_) async => const Ok('{"a":1}'));
        return build();
      },
      act: (bloc) =>
          bloc.add(const BackupEvent.exportRequested(fileName: 'club.json')),
      expect: () => [
        const BackupState(status: BackupStatus.working),
        const BackupState(status: BackupStatus.exported),
      ],
      verify: (_) {
        expect(files.lastSaved, (fileName: 'club.json', content: '{"a":1}'));
      },
    );

    blocTest<BackupBloc, BackupState>(
      'reports a cancelled save',
      build: () {
        files.cancelSave = true;
        when(() => export()).thenAnswer((_) async => const Ok('{}'));
        return build();
      },
      act: (bloc) =>
          bloc.add(const BackupEvent.exportRequested(fileName: 'club.json')),
      expect: () => [
        const BackupState(status: BackupStatus.working),
        const BackupState(status: BackupStatus.exportCancelled),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'reports an export failure',
      build: () {
        when(() => export()).thenAnswer(
          (_) async =>
              const Err(InvariantViolation(InvariantCode.invalidCatalogue)),
        );
        return build();
      },
      act: (bloc) =>
          bloc.add(const BackupEvent.exportRequested(fileName: 'club.json')),
      expect: () => [
        const BackupState(status: BackupStatus.working),
        const BackupState(
          status: BackupStatus.failure,
          failure: InvariantViolation(InvariantCode.invalidCatalogue),
        ),
      ],
    );
  });

  group('import', () {
    blocTest<BackupBloc, BackupState>(
      'previews a picked file without importing it',
      build: () {
        files.nextPick = '{"x":1}';
        when(() => preview('{"x":1}'))
            .thenAnswer((_) async => const Ok(summary));
        return build();
      },
      act: (bloc) => bloc.add(const BackupEvent.importRequested()),
      expect: () => [
        const BackupState(status: BackupStatus.working),
        const BackupState(
          status: BackupStatus.previewing,
          pendingContent: '{"x":1}',
          preview: summary,
        ),
      ],
      verify: (_) => verifyNever(() => import(any())),
    );

    blocTest<BackupBloc, BackupState>(
      'goes back to idle when no file is picked',
      build: build,
      act: (bloc) => bloc.add(const BackupEvent.importRequested()),
      expect: () => [
        const BackupState(status: BackupStatus.working),
        const BackupState(),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'reports an unreadable file',
      build: () {
        files.nextPick = 'x';
        when(() => preview('x')).thenAnswer(
          (_) async =>
              const Err(InvariantViolation(InvariantCode.backupUnreadable)),
        );
        return build();
      },
      act: (bloc) => bloc.add(const BackupEvent.importRequested()),
      expect: () => [
        const BackupState(status: BackupStatus.working),
        const BackupState(
          status: BackupStatus.failure,
          failure: InvariantViolation(InvariantCode.backupUnreadable),
        ),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'imports the previewed file once confirmed',
      build: () {
        when(() => import('{"x":1}'))
            .thenAnswer((_) async => const Ok(summary));
        return build();
      },
      seed: () => const BackupState(
        status: BackupStatus.previewing,
        pendingContent: '{"x":1}',
        preview: summary,
      ),
      act: (bloc) => bloc.add(const BackupEvent.importConfirmed()),
      expect: () => [
        const BackupState(
          status: BackupStatus.working,
          pendingContent: '{"x":1}',
          preview: summary,
        ),
        const BackupState(status: BackupStatus.imported, imported: summary),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'reports a refused import and forgets the file',
      build: () {
        when(() => import('{"x":1}')).thenAnswer(
          (_) async =>
              const Err(InvariantViolation(InvariantCode.backupInconsistent)),
        );
        return build();
      },
      seed: () => const BackupState(
        status: BackupStatus.previewing,
        pendingContent: '{"x":1}',
        preview: summary,
      ),
      act: (bloc) => bloc.add(const BackupEvent.importConfirmed()),
      verify: (bloc) {
        expect(bloc.state.status, BackupStatus.failure);
        expect(bloc.state.pendingContent, isNull);
        expect(bloc.state.preview, isNull);
      },
    );

    blocTest<BackupBloc, BackupState>(
      'ignores a confirmation without a previewed file',
      build: build,
      act: (bloc) => bloc.add(const BackupEvent.importConfirmed()),
      expect: () => <BackupState>[],
    );

    blocTest<BackupBloc, BackupState>(
      'cancelling forgets the previewed file',
      build: build,
      seed: () => const BackupState(
        status: BackupStatus.previewing,
        pendingContent: '{"x":1}',
        preview: summary,
      ),
      act: (bloc) => bloc.add(const BackupEvent.importCancelled()),
      expect: () => [const BackupState()],
    );
  });
}
