import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // La règle « quelles données déclenchent le bandeau » : un compteur à 1,
  // les autres à 0, suffit, sauf pour les saisons seules.
  group('LocalDataCounts.hasContent', () {
    final single = <String, LocalDataCounts>{
      'students': const LocalDataCounts(students: 1),
      'groups': const LocalDataCounts(groups: 1),
      'sessionRecords': const LocalDataCounts(sessionRecords: 1),
      'attempts': const LocalDataCounts(attempts: 1),
      'plannedSessions': const LocalDataCounts(plannedSessions: 1),
      'assessments': const LocalDataCounts(assessments: 1),
      'blockAcquisitions': const LocalDataCounts(blockAcquisitions: 1),
      'seasonArchives': const LocalDataCounts(seasonArchives: 1),
    };

    for (final entry in single.entries) {
      test('${entry.key} alone is content to protect', () {
        expect(entry.value.hasContent, isTrue);
        expect(
          LocalDataInventory(
            state: LocalStoreState.present,
            counts: entry.value,
          ).mayHoldData,
          isTrue,
        );
      });
    }

    test('seasons alone are not content', () {
      expect(const LocalDataCounts(seasons: 1).hasContent, isFalse);
    });

    test('all counters at zero are not content', () {
      expect(LocalDataCounts.zero.hasContent, isFalse);
    });
  });

  test('the file summary and the probe agree on what is nothing', () {
    for (final entry in {
      'students': const ImportSummary(
        seasons: 0,
        students: 1,
        groups: 0,
        sessionRecords: 0,
        attempts: 0,
        assessments: 0,
        plannedSessions: 0,
        blockAcquisitions: 0,
      ),
      'seasonArchives': const ImportSummary(
        seasons: 0,
        students: 0,
        groups: 0,
        sessionRecords: 0,
        attempts: 0,
        assessments: 0,
        plannedSessions: 0,
        blockAcquisitions: 0,
        seasonArchives: 1,
      ),
      'seasons only': const ImportSummary(
        seasons: 2,
        students: 0,
        groups: 0,
        sessionRecords: 0,
        attempts: 0,
        assessments: 0,
        plannedSessions: 0,
        blockAcquisitions: 0,
      ),
    }.entries) {
      final counts = LocalDataCounts(
        seasons: entry.value.seasons,
        students: entry.value.students,
        seasonArchives: entry.value.seasonArchives,
      );
      expect(entry.value.holdsNothing, !counts.hasContent, reason: entry.key);
    }
  });
}
