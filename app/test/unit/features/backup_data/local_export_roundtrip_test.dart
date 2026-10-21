import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_planner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/domain/export_local_backup.dart';
import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/local_store_probe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/import_world.dart';
import '../../../support/local_file_database.dart';
import '../../../support/realistic_backup.dart';

/// FB7c : l'export de la base locale (drift) d'un build Firestore. Vraie base
/// SQLite dans un fichier ; ce qui est prouvé : le fichier est celui du format
/// courant, il contient ce que la base contient, la base n'est pas modifiée,
/// et l'import de ce fichier dans le club (moteur FB7a) donne les mêmes
/// données que l'import de la sauvegarde d'origine.
void main() {
  final backup = RealisticBackup(history: true);

  // Comme au démarrage : la base est relevée AVANT que l'application ne
  // l'ouvre, et l'export tire la date du fichier de ce relevé.
  Future<String> exportOf(LocalFileDatabase db) async {
    final inventory = await probeLocalStore(db.settings);
    final opened = db.open();
    try {
      final result = await DriftRepos(opened).exporter(inventory).call();
      return switch (result) {
        Ok(:final value) => value.content,
        Err(:final failure) => fail('export refusé : $failure'),
      };
    } finally {
      await opened.close();
    }
  }

  test('the file holds what the base holds, with its counts', () async {
    final db = await LocalFileDatabase.create();
    await db.populate(backup.snapshot);
    final inventory = await probeLocalStore(db.settings);
    final opened = db.open();
    addTearDown(opened.close);

    final result = await DriftRepos(opened).exporter(inventory).call();

    final local = (result as Ok<LocalBackup>).value;
    final file = BackupCodec().decode(local.content);
    final s = backup.snapshot;
    expect(local.summary, ImportSummary.of(file));
    expect(file.students.map((e) => e.id).toSet(), {
      for (final e in s.students) e.id,
    });
    expect(file.groups, hasLength(s.groups.length));
    expect(file.sessionRecords, hasLength(s.sessionRecords.length));
    expect(file.attempts, hasLength(s.attempts.length));
    expect(file.assessments, hasLength(s.assessments.length));
    expect(file.plannedSessions, hasLength(s.plannedSessions.length));
    expect(file.blockAcquisitions, hasLength(s.blockAcquisitions.length));
    expect(file.seasonArchives, hasLength(s.seasonArchives.length));
    expect(
      file.alertAcknowledgements,
      hasLength(s.alertAcknowledgements!.length),
    );
    expect(local.summary.holdsNothing, isFalse);
  });

  test('the file is written in the current backup format', () async {
    final db = await LocalFileDatabase.create();
    await db.populate(backup.snapshot);

    final content = await exportOf(db);

    expect(content, contains('"schemaVersion": 5'));
    expect(BackupCodec.currentVersion, 5, reason: 'format v5 inchangé (FB7c)');
  });

  test('exporting does not modify the base, byte for byte', () async {
    final db = await LocalFileDatabase.create();
    await db.populate(backup.snapshot);
    final before = db.bytes;
    final names = db.fileNames;

    await exportOf(db);
    await exportOf(db);

    expect(db.bytes, before);
    expect(db.fileNames, names);
    expect(db.userVersion, 12);
  });

  test('an empty base exports a file that holds nothing', () async {
    final db = await LocalFileDatabase.create();
    final inventory = await probeLocalStore(db.settings);
    final opened = db.open();
    addTearDown(opened.close);

    final result = await DriftRepos(opened).exporter(inventory).call();

    expect((result as Ok<LocalBackup>).value.summary.holdsNothing, isTrue);
  });

  test(
    'importing the exported file into the club gives the same data',
    () async {
      final db = await LocalFileDatabase.create();
      await db.populate(backup.snapshot);
      final exported = await exportOf(db);

      // Le club de référence : la sauvegarde d'origine importée telle quelle.
      final reference = ImportWorld.open()
        ..backup = backup
        ..content = backup.content
        ..act(Role.director);
      reference.decisions = reference.createAll();
      final expected = await reference.referenceImport();

      // Le même import, avec le fichier exporté de la base locale.
      final world = ImportWorld.open()
        ..backup = backup
        ..content = exported
        ..act(Role.director);
      world.decisions = world.createAll();
      await world.prepare();
      expect(world.plan!.isRunnable, isTrue, reason: '${world.plan!.status}');
      await world.runPlan(budget: 1 << 30);

      expect(world.clubDocuments(), expected);
      expect(world.clubDocuments(), isNotEmpty);
    },
  );

  // T2 : la date du fichier doit être celle de la DERNIÈRE MODIFICATION de la
  // base, pas celle de l'export : sinon un fichier exporté après une clôture
  // faite dans le club paraît plus récent qu'elle alors qu'il contient encore
  // les élèves que le club a effacés.
  group('the date of the file', () {
    ClubImportPlan planAgainstClub(String content, {DateTime? closedOn}) {
      final decoded = BackupCodec().decodeForImport(content);
      return const ClubImportPlanner().plan(
        ClubImportInput(
          actor: const ImportActor(Role.director),
          now: DateTime.utc(2026, 10, 21, 9),
          snapshot: decoded.snapshot,
          fingerprint: decoded.fingerprint,
          version: decoded.version,
          exportedAt: decoded.exportedAt,
          decisions: ImportDecisions(
            groups: {
              for (final g in decoded.snapshot.groups)
                g.id: const CreateGroup(),
            },
          ),
          inventory: ClubInventory(
            seasons: {
              const SeasonId('season-club'): InventorySeason(
                startDate: DateTime(2026, 9),
                endDate: DateTime(2027, 6, 30),
                closedOn: closedOn,
              ),
            },
          ),
        ),
      );
    }

    test('a base not updated since a closure made in the club still asks '
        'the exact confirmation, though exported after it', () async {
      final db = await LocalFileDatabase.create();
      await db.populate(backup.snapshot);
      // Exporté le 21 octobre (« aujourd'hui » du test), la base n'a pas
      // bougé depuis début octobre ; le club a clos sa saison le 20 : les
      // élèves effacés au club sont encore dans ce fichier.
      final content = await exportOf(db);

      final plan = planAgainstClub(content, closedOn: DateTime(2026, 10, 20));

      expect(plan.status, ImportStatus.needsConfirmation);
      expect(plan.report.restoredStudents, backup.snapshot.students.length);
    });

    test(
      'the file is dated from the data, never from the export time',
      () async {
        final db = await LocalFileDatabase.create();
        await db.populate(backup.snapshot);

        final content = await exportOf(db);

        final exported = BackupCodec().decodeForImport(content).exportedAt;
        expect(exported, isNotNull);
        expect(exported!.year, 2026);
        expect(exported.month, 10);
        expect(exported.day, 1);
      },
    );

    test('a base without any timestamp gives a file with no date, which the '
        'import treats as possibly stale', () async {
      final db = await LocalFileDatabase.create();
      final opened = db.open();
      await opened.customSelect('SELECT 1').get();
      await opened.close();

      final content = await exportOf(db);

      expect(BackupCodec().decodeForImport(content).exportedAt, isNull);
      expect(content, isNot(contains('exportedAt')));
    });

    test('a file without a date is asked about as soon as the club has '
        'closed a season', () async {
      final db = await LocalFileDatabase.create();
      await db.populate(backup.snapshot);
      final dated = await exportOf(db);
      final content = dated.replaceFirst(
        RegExp(r'\s*"exportedAt": "[^"]*",'),
        '',
      );
      expect(content, isNot(contains('exportedAt')));

      final plan = planAgainstClub(content, closedOn: DateTime(2026, 6, 30));

      expect(plan.status, ImportStatus.needsConfirmation);
      expect(plan.report.restoredStudents, backup.snapshot.students.length);
    });
  });
}
