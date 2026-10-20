import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_planner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';

import '../../../../../support/realistic_backup.dart';

const director = ImportActor(Role.director);

ImportActor teacher(Iterable<String> groups) =>
    ImportActor(Role.teacher, {for (final group in groups) GroupId(group)});

/// Toutes les décisions « créer » pour les groupes du fichier.
ImportDecisions createAll(BackupSnapshot snapshot) => ImportDecisions(
  groups: {for (final g in snapshot.groups) g.id: const CreateGroup()},
);

ClubImportPlan planOf(
  RealisticBackup backup, {
  BackupSnapshot? snapshot,
  ImportActor? actor,
  ClubInventory inventory = ClubInventory.empty,
  ImportDecisions? decisions,
  ImportLimits limits = const ImportLimits(),
  DateTime? now,
  Set<StudentId>? newer,
  List<ImportProblem> preProblems = const [],
  bool confirmUnverified = true,
}) {
  final file = snapshot ?? backup.snapshot;
  ClubImportPlan plan(ImportDecisions decided) =>
      const ClubImportPlanner().plan(
        ClubImportInput(
          snapshot: file,
          fingerprint: sha256Hex(backup.content),
          version: 5,
          exportedAt: backup.exportedAt,
          actor: actor ?? director,
          inventory: inventory,
          decisions: decided,
          now: now ?? DateTime.utc(2026, 10, 12, 10),
          limits: limits,
          newerFileStudents: newer,
          preProblems: preProblems,
        ),
      );
  final decided = decisions ?? createAll(file);
  final first = plan(decided);
  // Un enseignant confirme d'emblée les fiches qu'il ne peut pas vérifier
  // (voir `club_import_planner_visibility_test.dart`) : les autres tests
  // portent sur autre chose.
  if (confirmUnverified &&
      first.status == ImportStatus.needsConfirmation &&
      first.report.unverifiableStudents > 0 &&
      decided.unverifiedConfirmed == null) {
    return plan(
      decided.copyWith(unverifiedConfirmed: first.report.unverifiableStudents),
    );
  }
  return first;
}

/// Un groupe du club, dans la saison [season] (ouverte, 2026-2027).
Map<GroupId, InventoryGroup> clubGroups(
  Map<String, Audience> groups, {
  String season = 'season-club',
}) => {
  for (final entry in groups.entries)
    GroupId(entry.key): InventoryGroup(SeasonId(season), entry.value),
};

Map<SeasonId, InventorySeason> clubSeason({
  String id = 'season-club',
  DateTime? closedOn,
}) => {
  SeasonId(id): InventorySeason(
    startDate: DateTime(2026, 9),
    endDate: DateTime(2027, 6, 30),
    closedOn: closedOn,
  ),
};

Iterable<ImportWrite> writesOf(ClubImportPlan plan, ImportCategory category) =>
    plan.lots.expand((lot) => lot.writes).where((w) => w.category == category);

List<String> codes(ClubImportPlan plan) => [
  for (final problem in plan.report.problems) problem.code.name,
];

/// Le fichier de `backup` avec une séance planifiée sans groupe, pour enfants.
class BackupSnapshotWithOrphan {
  BackupSnapshotWithOrphan(RealisticBackup backup)
    : snapshot = backup.snapshot.copyWith(
        plannedSessions: [
          Session(
            id: 'p-orphan',
            title: 'Séance sans groupe',
            date: DateTime(2026, 11, 5),
            audience: Audience.children,
          ),
        ],
      );

  final BackupSnapshot snapshot;
}

/// Le fichier de `backup` où l'élève `student`, sans groupe, a un bloc acquis
/// (donnée sans saisie : il faut lui trouver un groupe).
class BackupSnapshotWithData {
  BackupSnapshotWithData(RealisticBackup backup, StudentId student)
    : snapshot = backup.snapshot.copyWith(
        groups: [
          for (final g in backup.snapshot.groups)
            g.copyWith(
              memberships: [
                for (final m in g.memberships)
                  if (m.studentId != student) m,
              ],
            ),
        ],
        sessionRecords: const [],
        attempts: const [],
        blockAcquisitions: [
          RealisticBackup(history: true).snapshot.blockAcquisitions.first
              .copyWith(studentId: student),
        ],
      );

  final BackupSnapshot snapshot;
}
