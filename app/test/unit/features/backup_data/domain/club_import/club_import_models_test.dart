import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/unsupported_club_import_store.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/realistic_backup.dart';
import 'planner_support.dart';

void main() {
  group('what the rules tie to a student or a group', () {
    test('the data of a group', () {
      expect(
        {
          for (final c in ImportCategory.values)
            if (c.isGroupOwned) c,
        },
        {
          ImportCategory.plannedSessions,
          ImportCategory.sessionRecords,
          ImportCategory.attempts,
          ImportCategory.acquisitions,
          ImportCategory.assessments,
          ImportCategory.acknowledgements,
        },
      );
    });

    test('the data that needs the document of its student', () {
      expect(
        {
          for (final c in ImportCategory.values)
            if (c.needsStudentDocument) c,
        },
        {
          ImportCategory.attempts,
          ImportCategory.acquisitions,
          ImportCategory.assessments,
          ImportCategory.acknowledgements,
        },
      );
    });
  });

  group('the report of a refused file', () {
    final backup = RealisticBackup();
    final doubled = backup.snapshot.copyWith(
      attempts: [
        ...backup.snapshot.attempts,
        ...backup.snapshot.attempts.take(6),
      ],
      seasons: [...backup.snapshot.seasons, backup.snapshot.seasons.first],
    );
    final report = planOf(backup, snapshot: doubled).report;

    test('counts every problem, repeated ones included', () {
      expect(report.problems, hasLength(2));
      expect(report.totalProblems, 7);
    });

    test('shows the first problems only', () {
      expect(report.firstProblems(1), hasLength(1));
      expect(report.firstProblems(1).single, report.problems.first);
      expect(report.firstProblems(), report.problems);
    });
  });

  group('a club without Firestore data', () {
    const store = UnsupportedClubImportStore();

    test('refuses every call as unsupported', () async {
      Matcher unsupported() => throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.unsupported,
        ),
      );
      await expectLater(store.inventory('f' * 64), unsupported());
      await expectLater(store.readMarker('f' * 64), unsupported());
      final plan = planOf(RealisticBackup());
      await expectLater(
        store.commit(
          ImportLotCommit(
            lot: plan.lots.first,
            marker: ImportMarker(
              fileId: plan.fingerprint,
              planId: plan.planId,
              lots: plan.lots.length,
              done: 1,
              writes: plan.totalWrites,
              restored: 0,
              role: Role.director,
            ),
            createsMarker: true,
            inventory: ClubInventory.empty,
          ),
        ),
        unsupported(),
      );
    });
  });
}
