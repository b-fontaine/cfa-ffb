import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/realistic_backup.dart';
import 'planner_support.dart';

/// Les cas limites du planificateur : où atterrit une donnée sans groupe,
/// ce qu'une saison close permet, les identifiants que le fichier et le club
/// font se rencontrer.
void main() {
  final backup = RealisticBackup();
  final orphan = BackupSnapshotWithOrphan(backup).snapshot;
  const groupA = GroupId('club-a');

  ImportDecisions attach(GroupId target) =>
      createAll(orphan)
          .copyWith(plannedSessions: {'p-orphan': AttachTo(target)});

  ClubInventory club({DateTime? closedOn}) => ClubInventory(
    groups: clubGroups({'club-a': Audience.children}),
    seasons: clubSeason(closedOn: closedOn),
  );

  Session orphanOn(DateTime date) =>
      orphan.plannedSessions.single.copyWith(date: date);

  test('attaching the orphan session to another group changes the plan id', () {
    final both = ClubInventory(
      groups: clubGroups({
        'club-a': Audience.children,
        'club-b': Audience.children,
      }),
      seasons: clubSeason(),
    );
    final a = planOf(
      backup,
      snapshot: orphan,
      decisions: attach(groupA),
      inventory: both,
    );
    final b = planOf(
      backup,
      snapshot: orphan,
      decisions: attach(const GroupId('club-b')),
      inventory: both,
    );
    expect(a.status, ImportStatus.ready, reason: '${a.report.problems}');
    expect(b.status, ImportStatus.ready, reason: '${b.report.problems}');
    expect(a.planId, isNot(b.planId));
  });

  group('a planned session without a group', () {
    test('can join a group that already exists in the club', () {
      final plan = planOf(
        backup,
        snapshot: orphan,
        decisions: attach(groupA),
        inventory: club(),
      );
      expect(
        plan.status,
        ImportStatus.ready,
        reason: '${plan.report.problems}',
      );
      final planned = writesOf(plan, ImportCategory.plannedSessions).single;
      expect(planned.group, groupA);
      expect(planned.season, const SeasonId('season-club'));
    });

    test('a closed season of the club still takes it after its start', () {
      final plan = planOf(
        backup,
        snapshot: orphan,
        decisions: attach(groupA),
        inventory: club(closedOn: DateTime(2026, 10)),
      );
      expect(
        plan.status,
        ImportStatus.ready,
        reason: '${plan.report.problems}',
      );
      expect(writesOf(plan, ImportCategory.plannedSessions), hasLength(1));
    });

    test('a closed season refuses it before its start', () {
      final early = orphan.copyWith(
        plannedSessions: [orphanOn(DateTime(2026, 8))],
      );
      final plan = planOf(
        backup,
        snapshot: early,
        decisions: attach(groupA),
        inventory: club(closedOn: DateTime(2026, 10)),
      );
      expect(codes(plan), contains('outsideSeason'));
      final problem = plan.report.problems.firstWhere(
        (p) => p.code == ImportProblemCode.outsideSeason,
      );
      expect(problem.category, ImportCategory.plannedSessions);
      expect(problem.sample, ['p-orphan']);
    });
  });

  group('the records of the file meet the club', () {
    test('a sitting id too long for the target group is refused', () {
      final long = GroupId('x' * 60);
      final plan = planOf(
        backup,
        decisions: ImportDecisions(
          groups: {
            backup.groupId(1): UseExistingGroup(long),
            backup.groupId(2): const CreateGroup(),
          },
        ),
        inventory: ClubInventory(
          groups: clubGroups({long.value: Audience.children}),
          seasons: clubSeason(),
        ),
      );
      final problem = plan.report.problems.firstWhere(
        (p) => p.code == ImportProblemCode.badIdentifier,
      );
      expect(problem.category, ImportCategory.sessionRecords);
      expect(problem.sample.first, startsWith('g1_'));
    });

    test('two records that end on the same identifier are refused', () {
      final records = [...backup.snapshot.sessionRecords];
      final first = records.indexWhere(
        (r) => r.groupId == backup.groupId(1) && r.sheetId != null,
      );
      final second = records.indexWhere(
        (r) => r.groupId == backup.groupId(1) && r.id != records[first].id,
      );
      expect(first, isNot(-1));
      expect(second, isNot(-1));
      // Le second porte, tel quel, l'identifiant que le premier prendra dans
      // le groupe du club.
      final replaced = records[second].id;
      records[second] = records[second].copyWith(
        id: SessionId(
          records[first].id.value.replaceFirst('g1_', '${groupA.value}_'),
        ),
      );
      final snapshot = backup.snapshot.copyWith(
        sessionRecords: records,
        attempts: [
          for (final a in backup.snapshot.attempts)
            if (a.sessionId != replaced) a,
        ],
      );
      final plan = planOf(
        backup,
        snapshot: snapshot,
        decisions: ImportDecisions(
          groups: {
            backup.groupId(1): const UseExistingGroup(groupA),
            backup.groupId(2): const CreateGroup(),
          },
        ),
        inventory: club(),
      );
      final problem = plan.report.problems.firstWhere(
        (p) => p.code == ImportProblemCode.duplicateId,
      );
      expect(problem.category, ImportCategory.sessionRecords);
      expect(problem.sample, [records[second].id.value]);
    });

    test('a record whose audience is not the one of its group is refused', () {
      final records = [
        backup.snapshot.sessionRecords.first.copyWith(
          audience: Audience.adults,
        ),
        ...backup.snapshot.sessionRecords.skip(1),
      ];
      final plan = planOf(
        backup,
        snapshot: backup.snapshot.copyWith(sessionRecords: records),
      );
      final problem = plan.report.problems.firstWhere(
        (p) => p.code == ImportProblemCode.audienceMismatch,
      );
      expect(problem.category, ImportCategory.sessionRecords);
      expect(problem.sample, [records.first.id.value]);
    });
  });

  group('the group that owns the data of a student', () {
    // Une fiche dans deux groupes de la même saison, un bloc acquis sans
    // saisie : le groupe qui l'emporte est le premier par identifiant.
    final student = backup.studentId(1, 1);
    Group inBoth(Group g) => g.copyWith(
      memberships: [
        ...g.memberships,
        Membership(studentId: student, from: DateTime(2026, 9)),
      ],
    );

    BackupSnapshotWithData shared() => BackupSnapshotWithData(backup, student);

    test('the first group by identifier when the seasons are the same', () {
      final snapshot = shared().snapshot.copyWith(
        groups: [for (final g in shared().snapshot.groups) inBoth(g)],
      );
      final plan = planOf(backup, snapshot: snapshot);
      expect(
        plan.status,
        ImportStatus.ready,
        reason: '${plan.report.problems}',
      );
      expect(
        writesOf(plan, ImportCategory.acquisitions).single.group,
        backup.groupId(1),
      );
    });

    test('an attached student must name a group that exists', () {
      final snapshot = shared().snapshot;
      final plan = planOf(
        backup,
        snapshot: snapshot,
        decisions: createAll(snapshot)
            .copyWith(students: {student: const AttachTo(GroupId('nowhere'))}),
      );
      expect(codes(plan), contains('invalidDecision'));
      final problem = plan.report.problems.firstWhere(
        (p) => p.code == ImportProblemCode.invalidDecision,
      );
      expect(problem.category, ImportCategory.students);
      expect(problem.sample, [student.value]);
    });
  });
}
