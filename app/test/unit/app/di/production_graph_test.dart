import 'dart:io';

import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:billard_cfa/app/firebase_startup.dart';
import 'package:billard_cfa/app/platform/file_picker_pdf_files.dart';
import 'package:billard_cfa/app/platform/firebase_sdk_gateway.dart';
import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/app/platform/fullscreen_controller_native.dart';
import 'package:billard_cfa/app/platform/shared_preferences_key_value_store.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:billard_cfa/entities/account/data/firebase_auth_repository.dart';
import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/invitation/data/invitation_code_sources.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_code_source.dart';
import 'package:billard_cfa/entities/membership/data/store_memberships_source.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/data/in_memory_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/data/file_picker_backup_files.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/data/startup_local_data_probe.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/unsupported_club_import_store.dart';
import 'package:billard_cfa/features/backup_data/domain/export_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/export_local_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:billard_cfa/features/export_sheet/data/pdf_print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/domain/pdf_files.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/presentation/bloc/export_sheet_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/fullscreen_cubit.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/fullscreen_controller.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:billard_cfa/shared/lib/storage_status.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart' show Environment;

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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

  // Le défaut de production est Firestore (bascule du 2026-10-21) ; les tests
  // qui lisent la base locale demandent drift explicitement.
  Future<void> configureProduction({DataBackend? backend}) =>
      configureDependencies(
        backend: backend,
        settings: DatabaseSettings(
          native: DriftNativeOptions(
            databaseDirectory: () async => directory,
            tempDirectoryPath: () async => directory.path,
          ),
        ),
      );

  test('production wires Firestore repositories by default', () async {
    await configureProduction();

    expect(getIt<DataBackendChoice>().backend, DataBackend.firestore);
    expect(getIt<StudentRepository>(), isA<FirestoreStudentRepository>());
    expect(getIt<AttemptRepository>(), isA<FirestoreAttemptRepository>());
    expect(getIt<StudentRepository>(), isNot(isA<DriftStudentRepository>()));
    expect(
      (getIt<UnitOfWork>() as CompositeUnitOfWork).inner,
      isA<FirestoreUnitOfWork>(),
    );
  });

  test('production wires SQLite repositories when drift is explicit', () async {
    await configureProduction(backend: DataBackend.drift);

    expect(getIt<DataBackendChoice>().backend, DataBackend.drift);

    expect(getIt<StudentRepository>(), isA<DriftStudentRepository>());
    expect(getIt<AttemptRepository>(), isA<DriftAttemptRepository>());
    expect(getIt<UnitOfWork>(), isA<DriftUnitOfWork>());
    expect(getIt<IdGenerator>(), isA<UuidV4Generator>());
    expect(
      File('${directory.path}/$appDatabaseName.sqlite').existsSync(),
      isTrue,
    );
  });

  test('the club import is unsupported when drift is explicit', () async {
    await configureProduction(backend: DataBackend.drift);

    expect(getIt<ClubImportStore>(), isA<UnsupportedClubImportStore>());
  });

  test('production reports a persistent native storage', () async {
    await configureProduction();

    final status = getIt<StorageStatus>();

    expect(status.implementation, StorageImplementation.nativeFile);
    expect(status.implementation.persistent, isTrue);
  });

  test('production can export its (empty) database', () async {
    await configureProduction(backend: DataBackend.drift);

    final result = await getIt<ExportBackup>()();

    expect(result, isA<Ok<String>>());
  });

  test(
    'cubits are per screen, the full screen controller is a singleton',
    () async {
      await configureProduction();

      final first = getIt<FullscreenCubit>();
      final second = getIt<FullscreenCubit>();
      addTearDown(first.close);
      addTearDown(second.close);

      expect(identical(first, second), isFalse);
      expect(
        identical(getIt<FullscreenController>(), getIt<FullscreenController>()),
        isTrue,
      );
      // Hors navigateur : le contrôleur natif (immersif sur mobile).
      expect(getIt<FullscreenController>(), isA<NativeFullscreenController>());
    },
  );

  test(
    'production wires Firebase on production, started by main only',
    () async {
      await configureProduction();

      final startup = getIt<FirebaseStartup>();

      expect(startup.environment.target, FirebaseTarget.production);
      expect(startup.gateway, isA<FirebaseSdkGateway>());
      // Rien n'est lancé par le câblage : c'est `main` qui appelle start().
      expect(startup.isReady, equals(null));
      expect(identical(startup, getIt<FirebaseStartup>()), isTrue);
    },
  );

  test('the test environment does not wire Firebase', () async {
    await configureDependencies(environment: Environment.test);

    expect(getIt.isRegistered<FirebaseStartup>(), isFalse);
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

  test(
    'production exports PDF files through the file picker, native',
    () async {
      await configureProduction();

      final files = getIt<PdfFiles>();

      expect(files, isA<FilePickerPdfFiles>());
      // Hors navigateur : enregistrement seulement, pas d'impression directe.
      expect(files.canPrint, isFalse);
      expect(identical(files, getIt<PdfFiles>()), isTrue);
    },
  );

  test(
    'production renders PDF with the pdf package and wires the cubit',
    () async {
      await configureProduction();

      expect(getIt<PrintRenderer>(), isA<PdfPrintRenderer>());
      final cubit = getIt<ExportSheetCubit>();
      addTearDown(cubit.close);
      expect(cubit.state.canPrint, isFalse);
    },
  );

  test(
    'production wires the session: Firebase auth, one scope, local store',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await configureProduction();

      expect(getIt<AuthRepository>(), isA<FirebaseAuthRepository>());
      expect(getIt<MembershipsSource>(), isA<StoreMembershipsSource>());
      expect(getIt<DocumentStore>(), isA<FirestoreDocumentStore>());
      expect(getIt<InvitationCodeSource>(), isA<SecureInvitationCodeSource>());
      expect(getIt<KeyValueStore>(), isA<SharedPreferencesKeyValueStore>());
      expect(getIt<SessionStartup>(), same(getIt<FirebaseStartup>()));
      // Un seul porteur de session derrière les deux ports minuscules.
      expect(getIt<CurrentUser>(), same(getIt<SessionScope>()));
      expect(getIt<ActiveClubScope>(), same(getIt<SessionScope>()));
      final cubit = getIt<AuthCubit>();
      expect(identical(cubit, getIt<AuthCubit>()), isTrue);
      // Rien n'est lancé par le câblage : l'application démarre la session.
      expect(cubit.state, const AuthUnknown());
    },
  );

  test('the test environment keeps the session in memory', () async {
    await configureDependencies(environment: Environment.test);

    expect(getIt<AuthRepository>(), isA<InMemoryAuthRepository>());
    expect(getIt<MembershipsSource>(), isA<StoreMembershipsSource>());
    expect(getIt<DocumentStore>(), isA<InMemoryDocumentStore>());
    expect(
      getIt<InvitationCodeSource>(),
      isA<SequentialInvitationCodeSource>(),
    );
    expect(getIt<KeyValueStore>(), isA<InMemoryKeyValueStore>());
    expect(getIt<SessionStartup>(), isA<InMemorySessionStartup>());
  });

  test('production serves the start-up reading of the local base', () async {
    const found = LocalDataInventory(
      state: LocalStoreState.present,
      schemaVersion: 12,
      counts: LocalDataCounts(students: 6, attempts: 72),
    );
    await configureDependencies(
      settings: DatabaseSettings(
        native: DriftNativeOptions(
          databaseDirectory: () async => directory,
          tempDirectoryPath: () async => directory.path,
        ),
      ),
      localData: found,
    );

    final probe = getIt<LocalDataProbe>();

    expect(probe, isA<StartupLocalDataProbe>());
    expect(await probe.inspect(), same(found));
  });

  test(
    'the local export reads drift even when the club is elsewhere',
    () async {
      await configureProduction();
      await getIt<DriftStudentRepository>().save(
        Student.enroll(
          id: const StudentId('s1'),
          firstName: 'Léa',
          audience: Audience.children,
          since: DateTime(2026, 9),
        ),
      );
      // Le build Firestore : le dépôt de l'application est celui du club (ici
      // vide), la base locale reste lisible par l'export.
      await getIt.unregister<StudentRepository>();
      getIt.registerSingleton<StudentRepository>(InMemoryStudentRepository());

      final result = await getIt<ExportLocalBackup>()();

      final local = (result as Ok<LocalBackup>).value;
      expect(local.summary.students, 1);
      expect(local.content, contains('Léa'));
    },
  );
}
