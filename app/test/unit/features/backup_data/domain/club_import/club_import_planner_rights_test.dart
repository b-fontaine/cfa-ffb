import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_planner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/realistic_backup.dart';
import 'planner_support.dart';

/// `ClubImportPlanner.explain` : les écritures d'un gestionnaire et celles que
/// les règles refuseraient à un enseignant (le miroir de `firestore.rules`,
/// joué contre l'émulateur par `import.test.mjs`).
void main() {
  final backup = RealisticBackup();

  ClubInventory both({
    Map<StudentId, Set<GroupId>> students = const {},
    Map<ImportCategory, Set<String>> existing = const {},
  }) => ClubInventory(
    groups: {
      const GroupId('g1'): const InventoryGroup(
        RealisticBackup.season,
        Audience.children,
      ),
      const GroupId('g2'): const InventoryGroup(
        RealisticBackup.season,
        Audience.adults,
      ),
    },
    seasons: clubSeason(id: 'season'),
    students: students,
    existing: existing,
  );

  ClubImportInput inputOf(
    ClubInventory inventory, {
    bool withSnapshot = true,
    ImportDecisions? decisions,
  }) => ClubImportInput(
    snapshot: withSnapshot ? backup.snapshot : null,
    fingerprint: sha256Hex(backup.content),
    version: 5,
    exportedAt: backup.exportedAt,
    actor: director,
    inventory: inventory,
    decisions: decisions ?? ImportDecisions.none,
    now: DateTime.utc(2026, 10, 12, 10),
  );

  Set<String> ids(Map<ImportCategory, List<String>> denied, ImportCategory c) =>
      {...?denied[c]};

  group('explain', () {
    const planner = ClubImportPlanner();

    test(
      'says nothing without a file, with a broken file or undecided groups',
      () {
        expect(planner.explain(inputOf(both(), withSnapshot: false)), isNull);
        final broken = backup.snapshot.copyWith(
          attempts: [
            ...backup.snapshot.attempts,
            backup.snapshot.attempts.first,
          ],
        );
        expect(
          planner.explain(
            ClubImportInput(
              snapshot: broken,
              fingerprint: 'f' * 64,
              version: 5,
              actor: director,
              inventory: both(),
              now: DateTime.utc(2026, 10, 12, 10),
            ),
          ),
          isNull,
        );
        // Des groupes du fichier absents du club et sans choix.
        expect(planner.explain(inputOf(ClubInventory.empty)), isNull);
      },
    );

    test('says nothing when a decision is missing or wrong', () {
      final orphan = BackupSnapshotWithOrphan(backup).snapshot;
      expect(
        planner.explain(
          ClubImportInput(
            snapshot: orphan,
            fingerprint: 'f' * 64,
            version: 5,
            actor: director,
            inventory: both(),
            now: DateTime.utc(2026, 10, 12, 10),
          ),
        ),
        isNull,
      );
      const wrong = ImportDecisions(
        plannedSessions: {'p-orphan': AttachTo(GroupId('nowhere'))},
      );
      expect(
        planner.explain(
          ClubImportInput(
            snapshot: orphan,
            fingerprint: 'f' * 64,
            version: 5,
            actor: director,
            inventory: both(),
            decisions: wrong,
            now: DateTime.utc(2026, 10, 12, 10),
          ),
        ),
        isNull,
      );
    });

    test('a teacher of g1 is denied what the director writes for g2', () {
      final explained = planner.explain(
        inputOf(both()),
        analyzedFor: teacher(['g1']),
      )!;
      final denied = explained.denied;
      // Une saison est au gestionnaire.
      expect(ids(denied, ImportCategory.seasons), {'season'});
      // Les fiches, appartenances, saisies et passages du groupe g2 ne sont pas
      // à elle ; ceux de g1 le sont.
      expect(ids(denied, ImportCategory.students), {
        for (var n = 1; n <= 3; n++) 's-g2-$n',
      });
      expect(
        ids(denied, ImportCategory.memberships),
        everyElement(contains('g2_')),
      );
      expect(ids(denied, ImportCategory.memberships), hasLength(3));
      expect(ids(denied, ImportCategory.sessionRecords), {
        for (final r in backup.snapshot.sessionRecords)
          if (r.groupId == const GroupId('g2')) r.id.value,
      });
      expect(
        ids(denied, ImportCategory.attempts),
        everyElement(contains('-g2-')),
      );
      final g1Attempts = explained.writes.where(
        (w) =>
            w.category == ImportCategory.attempts &&
            w.group == const GroupId('g1'),
      );
      expect(g1Attempts, isNotEmpty);
      expect(
        ids(
          denied,
          ImportCategory.attempts,
        ).intersection({for (final w in g1Attempts) w.id}),
        isEmpty,
      );
      expect(
        ids(denied, ImportCategory.attempts).length + g1Attempts.length,
        backup.attemptCount,
      );
    });

    test('a manager is denied nothing', () {
      final explained = planner.explain(inputOf(both()))!;
      expect(explained.denied, isEmpty);
      expect(explained.writes, isNotEmpty);
    });

    test('a student already in the club: only a missing group is denied', () {
      final student = backup.studentId(1, 1);
      final inventory = both(
        students: {
          student: {const GroupId('g1')},
          backup.studentId(1, 2): {const GroupId('g2')},
        },
        existing: {
          ImportCategory.students: {
            student.value,
            backup.studentId(1, 2).value,
          },
        },
      );
      final denied = planner
          .explain(inputOf(inventory), analyzedFor: teacher(['g1']))!
          .denied;
      // s-g1-1 a déjà g1 : rien à écrire de plus. s-g1-2 est connue sous g2
      // seulement : lui ajouter g1 ne passe pas (la fiche n'est pas à elle).
      expect(ids(denied, ImportCategory.students), contains('s-g1-2'));
      expect(ids(denied, ImportCategory.students), isNot(contains('s-g1-1')));
    });

    test('a record or a session already in the club is not denied again', () {
      final record = backup.snapshot.sessionRecords.firstWhere(
        (r) => r.groupId == const GroupId('g2'),
      );
      final inventory = both(
        existing: {
          ImportCategory.sessionRecords: {record.id.value},
        },
      );
      final denied = planner
          .explain(inputOf(inventory), analyzedFor: teacher(['g1']))!
          .denied;
      expect(
        ids(denied, ImportCategory.sessionRecords),
        isNot(contains(record.id.value)),
      );
      expect(ids(denied, ImportCategory.sessionRecords), hasLength(2));
    });
  });
}
