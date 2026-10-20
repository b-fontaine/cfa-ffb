import 'dart:io';

import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/backup_formats.dart';
import '../../../../../support/import_world.dart';
import '../../../../../support/realistic_backup.dart';

/// Les fichiers de `test/fixtures/backup/` sont des sauvegardes **fictives**
/// (aucune donnée réelle), une par format (1 à 5), écrites par le format
/// courant puis ramenées au format ancien (`backupAtVersion`). Le test les
/// régénère et échoue si le fichier du dépôt diffère : le format d'export ne
/// change pas sans que ce test le dise. `UPDATE_FIXTURES=1` les réécrit.
void main() {
  final backup = RealisticBackup(
    groups: 1,
    studentsPerGroup: 2,
    sessionsPerGroup: 2,
    attemptsPerStudentSession: 2,
    history: true,
  );
  File fixture(int version) =>
      File('test/fixtures/backup/club-small-v$version.json');

  group('the fixture files', () {
    for (final version in [1, 2, 3, 4, 5]) {
      test('format $version is what the current code writes', () {
        final expected = backupAtVersion(backup.content, version);
        if (Platform.environment['UPDATE_FIXTURES'] == '1') {
          fixture(version).writeAsStringSync('$expected\n');
        }
        expect(fixture(version).readAsStringSync().trimRight(), expected);
      });
    }

    test(
      'the current format is exactly the export format of the application',
      () {
        expect(
          fixture(5).readAsStringSync().trimRight(),
          BackupCodec().encode(backup.snapshot, exportedAt: backup.exportedAt),
        );
      },
    );

    test('the fixtures hold no real data', () {
      for (final version in [1, 2, 3, 4, 5]) {
        final text = fixture(version).readAsStringSync();
        expect(text, isNot(contains('@')));
        expect(RegExp(r'"firstName": "Élève\d+"').allMatches(text), isNotEmpty);
      }
    });
  });

  group('reading the formats 1 to 5', () {
    // Ce que chaque format apporte : réglages (2), acquittements (3),
    // archives (4), étiquettes (5).
    const acknowledgements = {1: 0, 2: 0, 3: 1, 4: 1, 5: 1};
    const archives = {1: 0, 2: 0, 3: 0, 4: 2, 5: 2};

    for (final version in [1, 2, 3, 4, 5]) {
      test('format $version is read, planned and written', () async {
        final world = ImportWorld.open()
          ..act(Role.director)
          ..backup = backup
          ..content = fixture(version).readAsStringSync();
        world.decisions = world.createAll();
        final plan = await world.prepare();
        expect(
          plan.status,
          ImportStatus.ready,
          reason: '${plan.report.problems}',
        );
        expect(plan.version, version);
        expect(plan.fingerprint, sha256Hex(world.content!));
        expect(
          plan.report.counts[ImportCategory.acknowledgements]!.writes,
          acknowledgements[version],
        );
        expect(
          plan.report.counts[ImportCategory.seasonArchives]!.writes,
          archives[version],
        );
        expect(
          plan.report.warnings.contains(ImportWarning.settingsIgnored),
          version >= 2,
        );
        final run = await world.runPlan();
        expect(run.status, ImportRunStatus.completed);
        final keys = world.server.documents.keys;
        expect(keys.where((p) => p.contains('/students/')), hasLength(2));
        expect(keys.where((p) => p.contains('/attempts/')), hasLength(8));
        expect(
          keys.where((p) => p.contains('/acknowledgements/')),
          hasLength(acknowledgements[version]),
        );
        expect(
          keys.where((p) => p.contains('/archives/')),
          hasLength(archives[version]),
        );
        final tags = [
          for (final entry in world.server.documents.entries)
            if (entry.key.contains('/records/')) entry.value['tags'],
        ];
        expect(
          tags.any((t) => (t! as List).isNotEmpty),
          version == 5,
          reason: 'étiquettes : format 5 seulement',
        );
      });
    }

    test('the same file in two formats has two fingerprints', () {
      expect(
        sha256Hex(fixture(4).readAsStringSync()),
        isNot(sha256Hex(fixture(5).readAsStringSync())),
      );
    });
  });
}
