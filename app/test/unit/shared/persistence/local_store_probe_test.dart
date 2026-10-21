import 'dart:async';
import 'dart:io';

import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:billard_cfa/shared/persistence/local_store_handle.dart';
import 'package:billard_cfa/shared/persistence/local_store_opener_native.dart';
import 'package:billard_cfa/shared/persistence/local_store_probe.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/local_file_database.dart';
import '../../../support/realistic_backup.dart';

void main() {
  // La détection de la base locale d'un build Firestore (FB7c) : elle doit
  // pouvoir tourner à chaque démarrage sans jamais créer, migrer ni écrire.
  group('probeLocalStore', () {
    final backup = RealisticBackup(history: true);

    test('an absent base is reported absent and nothing is created', () async {
      final db = await LocalFileDatabase.create();

      final found = await probeLocalStore(db.settings);

      expect(found.state, LocalStoreState.absent);
      expect(found.mayHoldData, isFalse);
      expect(db.fileNames, isEmpty, reason: 'ni base, ni journal créés');
      expect(db.file.existsSync(), isFalse);
    });

    test('a missing directory is not created either', () async {
      final db = await LocalFileDatabase.create();
      final missing = Directory('${db.directory.path}/absent');

      final found = await probeLocalStore(
        LocalFileDatabase.settingsFor(missing),
      );

      expect(found.state, LocalStoreState.absent);
      expect(missing.existsSync(), isFalse);
    });

    test('a populated base gives its counts without being touched', () async {
      final db = await LocalFileDatabase.create();
      await db.populate(backup.snapshot);
      final before = db.bytes;
      final names = db.fileNames;

      final found = await probeLocalStore(db.settings);

      expect(found.state, LocalStoreState.present);
      expect(found.schemaVersion, AppDatabase.currentSchemaVersion);
      expect(found.migrationPending, isFalse);
      expect(found.mayHoldData, isTrue);
      final s = backup.snapshot;
      expect(found.counts.students, s.students.length);
      expect(found.counts.groups, s.groups.length);
      expect(found.counts.seasons, s.seasons.length);
      expect(found.counts.sessionRecords, s.sessionRecords.length);
      expect(found.counts.attempts, s.attempts.length);
      expect(found.counts.plannedSessions, s.plannedSessions.length);
      expect(found.counts.assessments, s.assessments.length);
      expect(found.counts.blockAcquisitions, s.blockAcquisitions.length);
      expect(found.counts.seasonArchives, s.seasonArchives.length);
      expect(
        db.bytes,
        before,
        reason: 'le fichier est octet pour octet le même',
      );
      expect(db.fileNames, names, reason: 'aucun journal ni fichier de plus');
    });

    test(
      'a base that was just initialised and left empty has no data',
      () async {
        final db = await LocalFileDatabase.create();
        final opened = db.open();
        await opened.customSelect('SELECT 1').get();
        await opened.close();

        final found = await probeLocalStore(db.settings);

        expect(found.state, LocalStoreState.present);
        expect(found.mayHoldData, isFalse);
      },
    );

    test('an empty file is present without data and stays empty', () async {
      final db = await LocalFileDatabase.create();
      db.file.createSync();

      final found = await probeLocalStore(db.settings);

      expect(found.state, LocalStoreState.present);
      expect(found.mayHoldData, isFalse);
      expect(db.bytes, isEmpty);
      expect(db.fileNames, ['$appDatabaseName.sqlite']);
    });

    test(
      'an older base is read as it is: its version is not rewritten',
      () async {
        final db = await LocalFileDatabase.create();
        await db.populate(backup.snapshot);
        db.forceUserVersion(11);
        final before = db.bytes;

        final found = await probeLocalStore(db.settings);

        expect(found.state, LocalStoreState.present);
        expect(found.schemaVersion, 11);
        expect(found.migrationPending, isTrue);
        expect(found.counts.students, backup.snapshot.students.length);
        expect(db.userVersion, 11, reason: 'drift n écrit pas la version');
        expect(db.bytes, before);
      },
    );

    test('a newer base is refused, not read, and left as it is', () async {
      final db = await LocalFileDatabase.create();
      await db.populate(backup.snapshot);
      db.forceUserVersion(AppDatabase.currentSchemaVersion + 1);
      final before = db.bytes;

      final found = await probeLocalStore(db.settings);

      expect(found.state, LocalStoreState.newerSchema);
      expect(found.schemaVersion, AppDatabase.currentSchemaVersion + 1);
      expect(found.mayHoldData, isTrue);
      expect(found.counts.hasContent, isFalse, reason: 'rien n est lu');
      expect(db.bytes, before);
    });

    test('soft-deleted rows are not counted', () async {
      final db = await LocalFileDatabase.create();
      await db.populate(backup.snapshot);
      final opened = db.open();
      final repos = DriftRepos(opened);
      await repos.students.delete(backup.snapshot.students.first.id);
      await opened.close();

      final found = await probeLocalStore(db.settings);

      expect(found.counts.students, backup.snapshot.students.length - 1);
    });

    test(
      'a file that is not a SQLite base is unreadable, never empty',
      () async {
        final db = await LocalFileDatabase.create();
        db.file.writeAsStringSync('ceci n est pas une base de données' * 20);
        final before = db.bytes;

        final found = await probeLocalStore(db.settings);

        expect(found.state, LocalStoreState.unreadable);
        expect(found.mayHoldData, isTrue);
        expect(db.bytes, before);
      },
    );

    test(
      'a base holding only season archives has content to protect',
      () async {
        final db = await LocalFileDatabase.create();
        await db.populate(
          BackupSnapshot(
            blockAcquisitions: const [],
            seasonArchives: backup.snapshot.seasonArchives,
          ),
        );

        final found = await probeLocalStore(db.settings);

        expect(found.state, LocalStoreState.present);
        expect(
          found.counts.seasonArchives,
          backup.snapshot.seasonArchives.length,
        );
        expect(found.counts.students, 0);
        expect(found.mayHoldData, isTrue);
      },
    );

    test(
      'a failure before the executor exists is unreadable, never empty',
      () async {
        final db = await LocalFileDatabase.create();

        final found = await probeLocalStore(
          DatabaseSettings(
            native: DriftNativeOptions(
              databaseDirectory: () async => throw StateError('x'),
            ),
          ),
        );

        expect(found.state, LocalStoreState.unreadable);
        expect(found.mayHoldData, isTrue);
        expect(db.fileNames, isEmpty);
      },
    );

    test(
      'a probe that never answers ends unreadable, not a blank app',
      () async {
        final never = Completer<Directory>();

        final found = await probeLocalStore(
          DatabaseSettings(
            native: DriftNativeOptions(databaseDirectory: () => never.future),
          ),
          timeout: const Duration(milliseconds: 50),
        );

        expect(found.state, LocalStoreState.unreadable);
        expect(found.mayHoldData, isTrue);
      },
    );

    test(
      'a directory in place of the file is unreadable, never empty',
      () async {
        final db = await LocalFileDatabase.create();
        Directory(db.file.path).createSync();

        final found = await probeLocalStore(db.settings);

        expect(found.state, LocalStoreState.unreadable);
        expect(found.mayHoldData, isTrue);
      },
    );

    test(
      'an unreadable file (no permission) is unreadable, never empty',
      () async {
        final db = await LocalFileDatabase.create();
        await db.populate(backup.snapshot);
        Process.runSync('chmod', ['000', db.file.path]);
        addTearDown(() => Process.runSync('chmod', ['600', db.file.path]));
        if (Process.runSync('id', ['-u']).stdout.toString().trim() == '0') {
          return; // root lit tout : le cas n'existe pas.
        }

        final found = await probeLocalStore(db.settings);

        expect(found.state, LocalStoreState.unreadable);
        expect(found.mayHoldData, isTrue);
      },
    );

    test(
      'the result survives an error that loses its type (remote executor)',
      () async {
        final db = await LocalFileDatabase.create();
        await db.populate(backup.snapshot);
        // Comme sur le web : la connexion passe par un autre isolat, qui
        // transforme l'exception d'interruption en DriftRemoteException.
        final remote = NativeDatabase.createInBackground(db.file);

        final found = await inspectLocalStore(
          LocalStoreHandle(remote, privateConnection: false),
          AppDatabase.currentSchemaVersion,
        );

        expect(found.state, LocalStoreState.present);
        expect(found.counts.students, backup.snapshot.students.length);
      },
    );

    test(
      'a native opener resolves databasePath and refuses a bad directory',
      () async {
        final db = await LocalFileDatabase.create();
        await db.populate(backup.snapshot);

        final byPath = await localStoreFile(
          DatabaseSettings(
            native: DriftNativeOptions(databasePath: () async => db.file.path),
          ),
        );
        expect(byPath.path, db.file.path);

        await expectLater(
          localStoreFile(
            DatabaseSettings(
              native: DriftNativeOptions(databaseDirectory: () async => 42),
            ),
          ),
          throwsArgumentError,
        );
        final byString = await localStoreFile(
          DatabaseSettings(
            native: DriftNativeOptions(
              databaseDirectory: () async => db.directory.path,
            ),
          ),
        );
        expect(byString.path, db.file.path);
      },
    );

    test(
      'the native opener opens read-only: a write is refused by SQLite itself',
      () async {
        final db = await LocalFileDatabase.create();
        await db.populate(backup.snapshot);
        final before = db.bytes;

        final handle = await openExistingLocalStore(db.settings);
        expect(handle, isNotNull);
        final user = _PlainUser();
        await handle!.executor.ensureOpen(user);
        // Sans `PRAGMA query_only` : c'est l'ouverture elle-même qui refuse.
        await expectLater(
          handle.executor.runCustom('CREATE TABLE intrus (a INTEGER)'),
          throwsA(anything),
        );
        await handle.release();

        expect(db.bytes, before);
        expect(db.fileNames, ['$appDatabaseName.sqlite']);
      },
    );

    test('the native opener returns null for an absent file and creates '
        'nothing', () async {
      final db = await LocalFileDatabase.create();

      expect(await openExistingLocalStore(db.settings), isNull);
      expect(db.fileNames, isEmpty);
    });

    test(
      'a probe that times out releases the executor it had opened',
      () async {
        final db = await LocalFileDatabase.create();
        await db.populate(backup.snapshot);
        final late = Completer<void>();
        final executor = _SpyExecutor();

        final found = await probeLocalStore(
          db.settings,
          timeout: const Duration(milliseconds: 50),
          open: (_) async {
            await late.future; // l'ouverture dépasse le délai ...
            return LocalStoreHandle(executor);
          },
        );
        expect(found.state, LocalStoreState.unreadable);
        expect(executor.closed, isFalse, reason: 'rien n est encore ouvert');

        late.complete(); // ... et aboutit après coup : elle est refermée.
        await pumpEventQueue();
        expect(executor.closed, isTrue, reason: 'aucun verrou laissé');
      },
    );

    test(
      'a probe that times out while reading releases the executor',
      () async {
        final executor = _SpyExecutor(hangOnOpen: true);

        final found = await probeLocalStore(
          const DatabaseSettings(),
          timeout: const Duration(milliseconds: 50),
          open: (_) async => LocalStoreHandle(executor),
        );

        expect(found.state, LocalStoreState.unreadable);
        expect(executor.closed, isTrue);
      },
    );

    test(
      'a retry reads again: unreadable, then a readable base succeeds',
      () async {
        final db = await LocalFileDatabase.create();
        await db.populate(backup.snapshot);
        final good = db.file.readAsBytesSync();
        db.file.writeAsStringSync('abîmé' * 100);
        expect(
          (await probeLocalStore(db.settings)).state,
          LocalStoreState.unreadable,
        );

        db.file.writeAsBytesSync(good);

        final found = await probeLocalStore(db.settings);
        expect(found.state, LocalStoreState.present);
        expect(found.counts.students, backup.snapshot.students.length);
      },
    );

    test('the last modification is the latest updated_at, deleted rows '
        'included, never the time of the reading', () async {
      final db = await LocalFileDatabase.create();
      await db.populate(backup.snapshot);
      final opened = db.open();
      final latest = await opened
          .customSelect(
            'SELECT MAX(m) AS m FROM (SELECT MAX(updated_at) AS m FROM '
            'students UNION ALL SELECT MAX(updated_at) FROM attempts '
            'UNION ALL SELECT MAX(updated_at) FROM seasons UNION ALL SELECT '
            'MAX(updated_at) FROM groups UNION ALL SELECT MAX(updated_at) '
            'FROM session_records UNION ALL SELECT MAX(updated_at) FROM '
            'assessments UNION ALL SELECT MAX(updated_at) FROM '
            'planned_sessions UNION ALL SELECT MAX(updated_at) FROM '
            'block_acquisitions UNION ALL SELECT MAX(updated_at) FROM '
            'alert_acknowledgements)',
          )
          .getSingle();
      await opened.close();

      final found = await probeLocalStore(db.settings);

      expect(found.lastModified, isNotNull);
      expect(found.lastModified, DateTime.parse(latest.read<String>('m')));
      expect(found.lastModified!.isBefore(DateTime.now()), isTrue);
    });

    test('a base without any timestamp has no last modification', () async {
      final db = await LocalFileDatabase.create();
      await db.populate(
        BackupSnapshot(
          blockAcquisitions: const [],
          seasonArchives: backup.snapshot.seasonArchives,
        ),
      );

      final found = await probeLocalStore(db.settings);

      expect(found.state, LocalStoreState.present);
      expect(found.lastModified, isNull);
    });

    test('the probe leaves the base usable by the application', () async {
      final db = await LocalFileDatabase.create();
      await db.populate(backup.snapshot);

      await probeLocalStore(db.settings);
      final opened = db.open();
      addTearDown(opened.close);

      expect(
        (await DriftRepos(opened).students.all()).length,
        backup.snapshot.students.length,
      );
    });
  });
}

/// L'« utilisateur » minimal d'un exécuteur : aucune migration.
class _PlainUser implements QueryExecutorUser {
  @override
  int get schemaVersion => AppDatabase.currentSchemaVersion;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

/// Un exécuteur dont on observe la fermeture.
class _SpyExecutor extends QueryExecutor {
  _SpyExecutor({this.hangOnOpen = false});

  final bool hangOnOpen;
  bool closed = false;

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) =>
      hangOnOpen ? Completer<bool>().future : Future.value(true);

  @override
  Future<void> close() async => closed = true;

  @override
  TransactionExecutor beginTransaction() => throw UnimplementedError();

  @override
  QueryExecutor beginExclusive() => this;

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {}

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async => const [];

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 0;
}
