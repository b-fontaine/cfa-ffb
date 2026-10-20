import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_planner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/realistic_backup.dart';
import 'planner_support.dart';

void main() {
  final backup = RealisticBackup();
  final full = RealisticBackup(history: true);

  group('the plan of a new club', () {
    test(
      'writes every document of the file, in the order of the categories',
      () {
        final plan = planOf(backup);
        expect(plan.status, ImportStatus.ready);
        final byCategory = {
          for (final c in ImportCategory.values) c: writesOf(plan, c).length,
        };
        expect(byCategory, {
          ImportCategory.seasons: 1,
          ImportCategory.groups: 2,
          ImportCategory.students: 6,
          ImportCategory.memberships: 6,
          ImportCategory.seasonArchives: 0,
          ImportCategory.plannedSessions: 0,
          ImportCategory.sessionRecords: 6,
          ImportCategory.attempts: 72,
          ImportCategory.acquisitions: 0,
          ImportCategory.assessments: 0,
          ImportCategory.acknowledgements: 0,
        });
        expect(plan.totalWrites, 93);
      },
    );

    test(
      'a file with history writes archives, blocks, assessments and more',
      () {
        final plan = planOf(full);
        expect(plan.status, ImportStatus.ready);
        expect(writesOf(plan, ImportCategory.seasons), hasLength(2));
        expect(writesOf(plan, ImportCategory.seasonArchives), hasLength(2));
        expect(writesOf(plan, ImportCategory.plannedSessions), hasLength(2));
        expect(writesOf(plan, ImportCategory.acquisitions), hasLength(6));
        expect(writesOf(plan, ImportCategory.assessments), hasLength(6));
        expect(writesOf(plan, ImportCategory.acknowledgements), hasLength(2));
      },
    );

    test('keeps the identifiers of the file', () {
      final plan = planOf(full);
      expect(writesOf(plan, ImportCategory.attempts).map((w) => w.id).toSet(), {
        for (final a in full.snapshot.attempts) a.id.value,
      });
      expect(writesOf(plan, ImportCategory.students).map((w) => w.id).toSet(), {
        for (final s in full.snapshot.students) s.id.value,
      });
      expect(
        writesOf(plan, ImportCategory.sessionRecords).map((w) => w.id).toSet(),
        {for (final r in full.snapshot.sessionRecords) r.id.value},
      );
    });

    test(
      'a lot holds 399 writes at most and the marker takes the last place',
      () {
        final plan = planOf(RealisticBackup(sessionsPerGroup: 20));
        expect(plan.totalWrites, greaterThan(399));
        for (final lot in plan.lots) {
          expect(lot.writes.length, lessThanOrEqualTo(399));
        }
        expect(plan.lots.length, greaterThan(1));
      },
    );

    test('a student and its memberships are never split across lots', () {
      final plan = planOf(backup, limits: const ImportLimits(lotSize: 5));
      for (final lot in plan.lots) {
        for (final write in lot.writes) {
          if (write.category != ImportCategory.memberships) continue;
          expect(
            lot.writes.any(
              (w) =>
                  w.category == ImportCategory.students &&
                  w.student == write.student,
            ),
            isTrue,
            reason: 'membership of ${write.student} without its student',
          );
        }
      }
    });

    test('a lot never holds a student and data that need its document', () {
      final plan = planOf(backup, limits: const ImportLimits(lotSize: 12));
      for (final lot in plan.lots) {
        final hasStudent = lot.writes.any(
          (w) => w.category == ImportCategory.students,
        );
        final needsStudent = lot.writes.any(
          (w) => w.category.needsStudentDocument,
        );
        expect(hasStudent && needsStudent, isFalse, reason: 'lot ${lot.index}');
      }
    });

    test(
      'a lot cites 18 distinct students at most: the rules read each one',
      () {
        final big = RealisticBackup(
          groups: 4,
          studentsPerGroup: 8,
          sessionsPerGroup: 14,
          history: true,
        );
        final plan = planOf(big);
        expect(plan.status, ImportStatus.ready);
        expect(plan.totalWrites, greaterThan(1500));
        for (final lot in plan.lots) {
          final students = {
            for (final w in lot.writes)
              if (w.category.needsStudentDocument) w.student,
          };
          expect(
            students.length,
            lessThanOrEqualTo(18),
            reason: 'lot ${lot.index}',
          );
          expect(lot.writes.length, lessThanOrEqualTo(399));
        }
        // Les écritures de 32 fiches ne tiennent pas dans un seul lot.
        final dependent = plan.lots.where(
          (lot) => lot.writes.any((w) => w.category.needsStudentDocument),
        );
        expect(dependent.length, greaterThan(1));
      },
    );

    test("a teacher's lot reads one document per new student and group", () {
      final big = RealisticBackup(
        groups: 1,
        studentsPerGroup: 30,
        sessionsPerGroup: 2,
        history: true,
      );
      final plan = planOf(
        big,
        actor: teacher(['club-a']),
        decisions: ImportDecisions(
          groups: {big.groupId(1): const UseExistingGroup(GroupId('club-a'))},
        ),
        inventory: ClubInventory(
          groups: clubGroups({'club-a': Audience.children}),
          seasons: clubSeason(),
        ),
      );
      expect(
        plan.status,
        ImportStatus.ready,
        reason: '${plan.report.problems}',
      );
      for (final lot in plan.lots) {
        final students = {
          for (final w in lot.writes)
            if (w.category == ImportCategory.students) w.student,
        };
        // La fiche (exists et getAfter : un seul document) et le groupe.
        expect(students.length + 1, lessThanOrEqualTo(18));
      }
      expect(
        plan.lots
            .where(
              (l) => l.writes.any((w) => w.category == ImportCategory.students),
            )
            .length,
        2,
      );
    });

    test('attempts keep the file order, recordedAt strictly increasing', () {
      final plan = planOf(backup);
      final attempts = writesOf(plan, ImportCategory.attempts).toList();
      expect(attempts.map((w) => w.id), [
        for (final a in backup.snapshot.attempts) a.id.value,
      ]);
      for (var i = 1; i < attempts.length; i++) {
        expect(
          attempts[i].recordedAt!.isAfter(attempts[i - 1].recordedAt!),
          isTrue,
        );
      }
    });

    test('is deterministic: same inputs, same lots, same plan id', () {
      final a = planOf(full);
      final b = planOf(full, now: DateTime.utc(2027));
      expect(a.planId, b.planId);
      expect(a.planId, hasLength(64));
    });

    test('the plan does not depend on what the club already holds', () {
      final fresh = planOf(backup);
      final inventory = ClubInventory(
        students: {backup.studentId(1, 1): const {}},
        existing: {
          ImportCategory.students: {backup.studentId(1, 1).value},
          ImportCategory.attempts: {backup.snapshot.attempts.first.id.value},
        },
      );
      expect(planOf(backup, inventory: inventory).planId, fresh.planId);
    });

    test('another choice of lot size gives another plan id', () {
      expect(
        planOf(backup).planId,
        isNot(planOf(backup, limits: const ImportLimits(lotSize: 50)).planId),
      );
    });

    test('counts per category tell what is already in the club', () {
      final inventory = ClubInventory(
        students: {backup.studentId(1, 1): const {}},
        existing: {
          ImportCategory.students: {backup.studentId(1, 1).value},
        },
      );
      final counts = planOf(backup, inventory: inventory).report.counts;
      expect(counts[ImportCategory.students]!.inFile, 6);
      expect(counts[ImportCategory.students]!.writes, 6);
      expect(counts[ImportCategory.students]!.alreadyPresent, 1);
    });
  });

  group('matching the groups', () {
    test('a group without a choice must be decided', () {
      final plan = planOf(backup, decisions: ImportDecisions.none);
      expect(plan.status, ImportStatus.needsDecisions);
      expect(plan.report.undecidedGroups, [
        backup.groupId(1),
        backup.groupId(2),
      ]);
      expect(plan.lots, isEmpty);
    });

    test(
      'a file group already in the club under the same id needs no choice',
      () {
        final plan = planOf(
          backup,
          decisions: ImportDecisions.none,
          inventory: ClubInventory(
            groups: {
              backup.groupId(1): const InventoryGroup(
                RealisticBackup.season,
                Audience.children,
              ),
              backup.groupId(2): const InventoryGroup(
                RealisticBackup.season,
                Audience.adults,
              ),
            },
          ),
        );
        expect(plan.status, ImportStatus.ready);
        // Le groupe existe : il n'est pas réécrit.
        expect(writesOf(plan, ImportCategory.groups), isEmpty);
      },
    );

    test(
      'an existing group of the club receives the data of the file group',
      () {
        final plan = planOf(
          backup,
          decisions: ImportDecisions(
            groups: {
              backup.groupId(1): const UseExistingGroup(GroupId('club-a')),
              backup.groupId(2): const UseExistingGroup(GroupId('club-b')),
            },
          ),
          inventory: ClubInventory(
            groups: clubGroups({
              'club-a': Audience.children,
              'club-b': Audience.adults,
            }),
            seasons: clubSeason(),
          ),
        );
        expect(
          plan.status,
          ImportStatus.ready,
          reason: '${plan.report.problems}',
        );
        expect(writesOf(plan, ImportCategory.groups), isEmpty);
        final records = writesOf(plan, ImportCategory.sessionRecords);
        expect(
          records.every((w) => w.season == const SeasonId('season-club')),
          isTrue,
        );
        expect(records.map((w) => w.group!.value).toSet(), {
          'club-a',
          'club-b',
        });
        for (final write in writesOf(plan, ImportCategory.memberships)) {
          expect(write.id, startsWith('club-'));
        }
      },
    );

    test('a deterministic sitting id follows the group of the club', () {
      final plan = planOf(
        backup,
        decisions: ImportDecisions(
          groups: {
            backup.groupId(1): const UseExistingGroup(GroupId('club-a')),
            backup.groupId(2): const UseExistingGroup(GroupId('club-b')),
          },
        ),
        inventory: ClubInventory(
          groups: clubGroups({
            'club-a': Audience.children,
            'club-b': Audience.adults,
          }),
          seasons: clubSeason(),
        ),
      );
      final ids = writesOf(
        plan,
        ImportCategory.sessionRecords,
      ).map((w) => w.id).toList();
      expect(ids, contains('club-a_20260908_demi-bille-1'));
      expect(ids.where((id) => id.startsWith('g1_')), isEmpty);
      // Les passages citent l'identifiant final de leur saisie.
      final sessions = writesOf(
        plan,
        ImportCategory.attempts,
      ).map((w) => (w.payload as ExerciseAttempt).sessionId.value).toSet();
      expect(sessions, ids.toSet());
      // Une saisie libre garde son identifiant (UUID).
      expect(ids, contains('r-g1-2'));
    });

    test(
      'two file groups on one club group are refused without a merge choice',
      () {
        final decisions = ImportDecisions(
          groups: {
            backup.groupId(1): const UseExistingGroup(GroupId('club-a')),
            backup.groupId(2): const UseExistingGroup(GroupId('club-a')),
          },
        );
        final inventory = ClubInventory(
          groups: clubGroups({'club-a': Audience.children}),
          seasons: clubSeason(),
        );
        final refused = planOf(
          backup,
          decisions: decisions,
          inventory: inventory,
        );
        expect(codes(refused), contains('mergeNotConfirmed'));
        expect(refused.status, ImportStatus.blocked);
        final merged = planOf(
          backup,
          decisions: decisions.copyWith(
            confirmedMerges: {const GroupId('club-a')},
          ),
          inventory: inventory,
        );
        expect(codes(merged), isNot(contains('mergeNotConfirmed')));
      },
    );

    test('a target group that does not exist is refused', () {
      final plan = planOf(
        backup,
        decisions: ImportDecisions(
          groups: {
            backup.groupId(1): const UseExistingGroup(GroupId('nowhere')),
            backup.groupId(2): const CreateGroup(),
          },
        ),
      );
      expect(codes(plan), contains('unknownTargetGroup'));
    });

    test('an audience that differs from the chosen group is refused', () {
      final plan = planOf(
        backup,
        decisions: ImportDecisions(
          groups: {
            backup.groupId(1): const UseExistingGroup(GroupId('club-b')),
            backup.groupId(2): const CreateGroup(),
          },
        ),
        inventory: ClubInventory(
          groups: clubGroups({'club-b': Audience.adults}),
          seasons: clubSeason(),
        ),
      );
      expect(codes(plan), contains('audienceMismatch'));
    });

    test('a group of a closed season of the club is refused as a target', () {
      final plan = planOf(
        backup,
        decisions: ImportDecisions(
          groups: {
            backup.groupId(1): const UseExistingGroup(GroupId('club-a')),
            backup.groupId(2): const CreateGroup(),
          },
        ),
        inventory: ClubInventory(
          groups: clubGroups({'club-a': Audience.children}),
          seasons: clubSeason(closedOn: DateTime(2026, 6, 30)),
        ),
      );
      expect(codes(plan), contains('targetSeasonClosed'));
    });

    test('dates must fall in the season of the chosen group', () {
      final plan = planOf(
        backup,
        decisions: ImportDecisions(
          groups: {
            backup.groupId(1): const UseExistingGroup(GroupId('club-a')),
            backup.groupId(2): const CreateGroup(),
          },
        ),
        inventory: ClubInventory(
          groups: clubGroups({'club-a': Audience.children}),
          seasons: {
            const SeasonId('season-club'): InventorySeason(
              startDate: DateTime(2027, 9),
              endDate: DateTime(2028, 6, 30),
            ),
          },
        ),
      );
      expect(codes(plan), contains('outsideSeason'));
    });

    test('a file that reopens a season the club closed is refused', () {
      final plan = planOf(
        backup,
        inventory: ClubInventory(
          seasons: clubSeason(id: 'season', closedOn: DateTime(2026, 10, 20)),
        ),
      );
      expect(codes(plan), contains('reopensClosedSeason'));
    });
  });

  group('sessions and students without a group', () {
    BackupSnapshotWithOrphan orphan() => BackupSnapshotWithOrphan(backup);

    test('a planned session without a group needs an explicit decision', () {
      final plan = planOf(backup, snapshot: orphan().snapshot);
      expect(plan.status, ImportStatus.needsDecisions);
      expect(plan.report.undecidedSessions, ['p-orphan']);
      expect(plan.lots, isEmpty);
    });

    test('it can be attached to a group of the import', () {
      final snapshot = orphan().snapshot;
      final plan = planOf(
        backup,
        snapshot: snapshot,
        decisions: createAll(
          snapshot,
        ).copyWith(plannedSessions: {'p-orphan': AttachTo(backup.groupId(1))}),
      );
      expect(plan.status, ImportStatus.ready);
      final planned = writesOf(plan, ImportCategory.plannedSessions).single;
      expect((planned.payload as Session).groupId, backup.groupId(1));
      expect(planned.group, backup.groupId(1));
    });

    test('it can be skipped, and the report counts it as ignored', () {
      final snapshot = orphan().snapshot;
      final plan = planOf(
        backup,
        snapshot: snapshot,
        decisions: createAll(snapshot)
            .copyWith(plannedSessions: {'p-orphan': const SkipIt()}),
      );
      expect(plan.status, ImportStatus.ready);
      expect(writesOf(plan, ImportCategory.plannedSessions), isEmpty);
      expect(plan.report.counts[ImportCategory.plannedSessions]!.ignored, 1);
    });

    test('attaching to an unknown group or another audience is refused', () {
      final snapshot = orphan().snapshot;
      final unknown = planOf(
        backup,
        snapshot: snapshot,
        decisions: createAll(snapshot).copyWith(
          plannedSessions: {'p-orphan': const AttachTo(GroupId('nowhere'))},
        ),
      );
      expect(codes(unknown), contains('invalidDecision'));
      // g2 est un groupe d'adultes, la séance est pour des enfants.
      final mismatch = planOf(
        backup,
        snapshot: snapshot,
        decisions: createAll(
          snapshot,
        ).copyWith(plannedSessions: {'p-orphan': AttachTo(backup.groupId(2))}),
      );
      expect(codes(mismatch), contains('audienceMismatch'));
    });

    test(
      'a student without a group whose data has no group needs a decision',
      () {
        final snapshot = backup.snapshot.copyWith(
          groups: [
            for (final g in backup.snapshot.groups)
              g.copyWith(memberships: const []),
          ],
          sessionRecords: const [],
          attempts: const [],
          blockAcquisitions: [
            full.snapshot.blockAcquisitions.first.copyWith(
              studentId: backup.studentId(1, 1),
            ),
          ],
        );
        final plan = planOf(backup, snapshot: snapshot);
        expect(plan.status, ImportStatus.needsDecisions);
        expect(plan.report.undecidedStudents, [backup.studentId(1, 1)]);
        final attached = planOf(
          backup,
          snapshot: snapshot,
          decisions: createAll(snapshot).copyWith(
            students: {backup.studentId(1, 1): AttachTo(backup.groupId(1))},
          ),
        );
        expect(attached.status, ImportStatus.ready);
        expect(
          writesOf(attached, ImportCategory.acquisitions).single.group,
          backup.groupId(1),
        );
        final skipped = planOf(
          backup,
          snapshot: snapshot,
          decisions: createAll(snapshot)
              .copyWith(students: {backup.studentId(1, 1): const SkipIt()}),
        );
        expect(skipped.status, ImportStatus.ready);
        expect(writesOf(skipped, ImportCategory.acquisitions), isEmpty);
        expect(skipped.report.counts[ImportCategory.acquisitions]!.ignored, 1);
      },
    );
  });

  group('what the role may write', () {
    test('a director and an administrator write everything', () {
      expect(planOf(full).status, ImportStatus.ready);
      expect(
        planOf(full, actor: const ImportActor(Role.admin)).status,
        ImportStatus.ready,
      );
    });

    test('a parent or a student cannot import', () {
      final plan = planOf(backup, actor: const ImportActor(Role.guardian));
      expect(plan.status, ImportStatus.blocked);
      expect(codes(plan), ['roleDenied']);
    });

    test('a teacher cannot create a group', () {
      final plan = planOf(backup, actor: teacher(['club-a']));
      expect(plan.status, ImportStatus.blocked);
      expect(codes(plan), contains('roleDenied'));
    });

    test('a teacher cannot target a group that is not hers', () {
      final plan = planOf(
        backup,
        actor: teacher(['club-a']),
        decisions: ImportDecisions(
          groups: {
            backup.groupId(1): const UseExistingGroup(GroupId('club-a')),
            backup.groupId(2): const UseExistingGroup(GroupId('club-b')),
          },
        ),
        inventory: ClubInventory(
          groups: clubGroups({
            'club-a': Audience.children,
            'club-b': Audience.adults,
          }),
          seasons: clubSeason(),
        ),
      );
      expect(plan.status, ImportStatus.blocked);
      expect(
        plan.report.problems.where(
          (p) => p.code == ImportProblemCode.roleDenied,
        ),
        isNotEmpty,
      );
    });

    test(
      'a teacher imports her own groups and the plan says what is left out',
      () {
        final single = RealisticBackup(groups: 1, history: true);
        final plan = planOf(
          single,
          actor: teacher(['club-a']),
          decisions: ImportDecisions(
            groups: {
              single.groupId(1): const UseExistingGroup(GroupId('club-a')),
            },
          ),
          inventory: ClubInventory(
            groups: clubGroups({'club-a': Audience.children}),
            seasons: clubSeason(),
          ),
        );
        expect(
          plan.status,
          ImportStatus.ready,
          reason: '${plan.report.problems}',
        );
        expect(writesOf(plan, ImportCategory.seasons), isEmpty);
        expect(writesOf(plan, ImportCategory.groups), isEmpty);
        expect(writesOf(plan, ImportCategory.seasonArchives), isEmpty);
        expect(plan.report.warnings, contains(ImportWarning.roleScope));
        expect(writesOf(plan, ImportCategory.students), hasLength(3));
      },
    );

    test('a teacher cannot import a student whose membership was closed', () {
      final single = RealisticBackup(groups: 1);
      final closed = single.snapshot.copyWith(
        groups: [
          for (final g in single.snapshot.groups)
            g.copyWith(
              memberships: [
                for (final m in g.memberships)
                  m.copyWith(to: DateTime(2026, 9, 30)),
              ],
            ),
        ],
      );
      final plan = planOf(
        single,
        snapshot: closed,
        actor: teacher(['club-a']),
        decisions: ImportDecisions(
          groups: {
            single.groupId(1): const UseExistingGroup(GroupId('club-a')),
          },
        ),
        inventory: ClubInventory(
          groups: clubGroups({'club-a': Audience.children}),
          seasons: clubSeason(),
        ),
      );
      expect(plan.status, ImportStatus.blocked);
      final denied = plan.report.problems.where(
        (p) => p.code == ImportProblemCode.roleDenied,
      );
      expect(
        denied.map((p) => p.category),
        containsAll([
          ImportCategory.students,
          ImportCategory.memberships,
          // La fiche refusée n'existera pas : ses passages le sont avec elle.
          ImportCategory.attempts,
        ]),
      );
    });

    test('a teacher cannot import a shifted student, nor his data', () {
      final single = RealisticBackup(groups: 1);
      final shifted = single.snapshot.copyWith(
        groups: [
          for (final g in single.snapshot.groups)
            g.copyWith(
              memberships: [
                for (final m in g.memberships)
                  if (m.studentId == single.studentId(1, 1))
                    m.copyWith(from: DateTime(2026, 9, 15))
                  else
                    m,
              ],
            ),
        ],
      );
      final plan = planOf(
        single,
        snapshot: shifted,
        actor: teacher(['club-a']),
        decisions: ImportDecisions(
          groups: {
            single.groupId(1): const UseExistingGroup(GroupId('club-a')),
          },
        ),
        inventory: ClubInventory(
          groups: clubGroups({'club-a': Audience.children}),
          seasons: clubSeason(),
        ),
      );
      expect(plan.status, ImportStatus.blocked);
      final denied = {
        for (final p in plan.report.problems)
          if (p.code == ImportProblemCode.roleDenied) p.category: p.count,
      };
      // La fiche, son appartenance, et les passages de cet élève (la fiche
      // refusée n'existera pas : les règles ne la trouvent pas).
      expect(denied[ImportCategory.students], 1);
      expect(denied[ImportCategory.memberships], 1);
      expect(denied[ImportCategory.attempts], 3 * 4);
    });

    test('a teacher cannot add data to a student who is not in the group', () {
      final single = RealisticBackup(groups: 1);
      final moved = single.snapshot.copyWith(
        groups: [
          for (final g in single.snapshot.groups)
            g.copyWith(
              memberships: [
                for (final m in g.memberships)
                  if (m.studentId != single.studentId(1, 1)) m,
              ],
            ),
        ],
      );
      final plan = planOf(
        single,
        snapshot: moved,
        actor: teacher(['club-a']),
        decisions: ImportDecisions(
          groups: {
            single.groupId(1): const UseExistingGroup(GroupId('club-a')),
          },
        ),
        inventory: ClubInventory(
          groups: clubGroups({'club-a': Audience.children}),
          seasons: clubSeason(),
        ),
      );
      expect(plan.status, ImportStatus.blocked);
      expect(
        plan.report.problems.map((p) => (p.code, p.category)),
        containsAll([
          (ImportProblemCode.roleDenied, ImportCategory.students),
          (ImportProblemCode.roleDenied, ImportCategory.attempts),
        ]),
      );
    });
  });

  group('erased students', () {
    final inventoryAfterClosure = ClubInventory(
      seasons: clubSeason(closedOn: DateTime(2026, 10, 20)),
      students: {for (var n = 1; n <= 3; n++) backup.studentId(1, n): const {}},
    );

    test(
      'students absent after a closure that followed the export are counted',
      () {
        final plan = planOf(backup, inventory: inventoryAfterClosure);
        expect(plan.status, ImportStatus.needsConfirmation);
        expect(plan.report.restoredStudents, 3);
        expect(plan.lots, isEmpty);
      },
    );

    test(
      'the confirmation must equal the count, and then the plan is ready',
      () {
        ClubImportPlan confirm(int count) => planOf(
          backup,
          inventory: inventoryAfterClosure,
          decisions: createAll(backup.snapshot)
              .copyWith(restoreConfirmed: count),
        );
        expect(confirm(2).status, ImportStatus.needsConfirmation);
        expect(confirm(4).status, ImportStatus.needsConfirmation);
        expect(confirm(3).status, ImportStatus.ready);
      },
    );

    test('a club that closed nothing after the export asks for nothing', () {
      final plan = planOf(
        backup,
        inventory: ClubInventory(
          seasons: clubSeason(closedOn: DateTime(2026, 6, 30)),
        ),
      );
      expect(plan.status, ImportStatus.ready);
      expect(plan.report.restoredStudents, 0);
    });

    test('students missing from a newer file are counted', () {
      final newer = {for (var n = 1; n <= 4; n++) backup.studentId(1, n)};
      final plan = planOf(
        backup,
        newer: newer,
        inventory: ClubInventory(students: {backup.studentId(1, 1): const {}}),
      );
      // g1-1 est au club ; g1-2..3 sont dans le fichier récent ; il reste 3.
      expect(plan.report.restoredStudents, 5 - 2);
      expect(plan.status, ImportStatus.needsConfirmation);
    });

    test('a student being erased in the club blocks the import', () {
      final plan = planOf(
        backup,
        inventory: ClubInventory(erasingStudents: {backup.studentId(1, 1)}),
      );
      expect(codes(plan), contains('studentBeingErased'));
      expect(plan.status, ImportStatus.blocked);
    });

    test('a running import is not asked to confirm again', () {
      final confirmed = planOf(
        backup,
        decisions: createAll(backup.snapshot).copyWith(restoreConfirmed: 3),
        inventory: inventoryAfterClosure,
      );
      expect(confirmed.status, ImportStatus.ready);
      final running = ImportMarker(
        fileId: confirmed.fingerprint,
        planId: confirmed.planId,
        lots: confirmed.lots.length,
        done: 1,
        writes: confirmed.totalWrites,
        restored: 3,
        role: Role.director,
      );
      // L'animateur ne confirme plus rien : la confirmation est au marqueur.
      final plan = planOf(
        backup,
        inventory: ClubInventory(
          seasons: inventoryAfterClosure.seasons,
          students: inventoryAfterClosure.students,
          marker: running,
        ),
      );
      expect(plan.status, ImportStatus.resumable);
    });
  });

  group('the marker of the club', () {
    final fresh = planOf(backup);

    ImportMarker marker({int done = 1, int? lots, String? planId}) =>
        ImportMarker(
          fileId: fresh.fingerprint,
          planId: planId ?? fresh.planId,
          lots: lots ?? fresh.lots.length,
          done: done,
          writes: fresh.totalWrites,
          restored: 0,
          role: Role.director,
        );

    test('a finished import is not offered again', () {
      final plan = planOf(
        backup,
        inventory: ClubInventory(marker: marker(done: fresh.lots.length)),
      );
      expect(plan.status, ImportStatus.alreadyImported);
      expect(plan.isRunnable, isFalse);
      expect(plan.lots, isEmpty);
    });

    test('a started import resumes at the next lot', () {
      final small = planOf(backup, limits: const ImportLimits(lotSize: 30));
      final plan = planOf(
        backup,
        limits: const ImportLimits(lotSize: 30),
        inventory: ClubInventory(
          marker: ImportMarker(
            fileId: small.fingerprint,
            planId: small.planId,
            lots: small.lots.length,
            done: 2,
            writes: small.totalWrites,
            restored: 0,
            role: Role.director,
          ),
        ),
      );
      expect(plan.status, ImportStatus.resumable);
      expect(plan.startLot, 2);
      expect(plan.remainingWrites, lessThan(small.remainingWrites));
    });

    test('a started import does not resume with other choices', () {
      final plan = planOf(
        backup,
        inventory: ClubInventory(marker: marker(planId: 'f' * 64, done: 0)),
      );
      expect(codes(plan), contains('planChanged'));
      expect(plan.status, ImportStatus.blocked);
    });
  });

  group('the plan identity covers the content and the decisions', () {
    final club = ClubInventory(
      groups: clubGroups({
        'club-a': Audience.children,
        'club-b': Audience.adults,
        'club-c': Audience.children,
      }),
      seasons: clubSeason(),
    );
    ImportDecisions mapping(String first, String second) => ImportDecisions(
      groups: {
        backup.groupId(1): UseExistingGroup(GroupId(first)),
        backup.groupId(2): UseExistingGroup(GroupId(second)),
      },
    );

    test('another group mapping gives another plan id', () {
      final a = planOf(
        backup,
        decisions: mapping('club-a', 'club-b'),
        inventory: club,
      );
      final b = planOf(
        backup,
        decisions: mapping('club-c', 'club-b'),
        inventory: club,
      );
      expect(a.status, ImportStatus.ready, reason: '${a.report.problems}');
      expect(b.status, ImportStatus.ready, reason: '${b.report.problems}');
      expect(a.planId, isNot(b.planId));
    });

    test('the same file, decisions and role give the same plan id', () {
      expect(
        planOf(
          backup,
          decisions: mapping('club-a', 'club-b'),
          inventory: club,
        ).planId,
        planOf(
          backup,
          decisions: mapping('club-a', 'club-b'),
          inventory: club,
        ).planId,
      );
    });

    test('a resume with another group mapping is a changed plan', () {
      final started = planOf(
        backup,
        decisions: mapping('club-a', 'club-b'),
        inventory: club,
      );
      final plan = planOf(
        backup,
        decisions: mapping('club-c', 'club-b'),
        inventory: ClubInventory(
          groups: club.groups,
          seasons: club.seasons,
          marker: ImportMarker(
            fileId: started.fingerprint,
            planId: started.planId,
            lots: started.lots.length,
            done: 1,
            writes: started.totalWrites,
            restored: 0,
            role: Role.director,
          ),
        ),
      );
      expect(codes(plan), contains('planChanged'));
      expect(plan.status, ImportStatus.blocked);
    });

    test('a resume with the same mapping resumes', () {
      final started = planOf(
        backup,
        decisions: mapping('club-a', 'club-b'),
        inventory: club,
      );
      final plan = planOf(
        backup,
        decisions: mapping('club-a', 'club-b'),
        inventory: ClubInventory(
          groups: club.groups,
          seasons: club.seasons,
          marker: ImportMarker(
            fileId: started.fingerprint,
            planId: started.planId,
            lots: started.lots.length,
            done: 1,
            writes: started.totalWrites,
            restored: 0,
            role: Role.director,
          ),
        ),
      );
      expect(plan.status, ImportStatus.resumable);
    });
  });

  group('the cost of an import', () {
    test('warns and splits an import over several days', () {
      final plan = planOf(
        backup,
        limits: const ImportLimits(lotSize: 30, dailyWrites: 60),
      );
      expect(plan.daysNeeded, 2);
      expect(plan.report.warnings, contains(ImportWarning.largeImport));
    });

    test('a small import fits in one day without a warning', () {
      final plan = planOf(backup);
      expect(plan.daysNeeded, 1);
      expect(plan.report.warnings, isNot(contains(ImportWarning.largeImport)));
    });

    test('a lot bigger than the daily budget still takes a day', () {
      final plan = planOf(
        backup,
        limits: const ImportLimits(lotSize: 50, dailyWrites: 10),
      );
      expect(plan.daysNeeded, plan.lots.length);
    });

    test('warns about an old file and about ignored settings', () {
      final plan = planOf(backup, now: DateTime.utc(2026, 12, 20));
      expect(plan.report.warnings, contains(ImportWarning.staleFile));
      expect(plan.report.warnings, contains(ImportWarning.settingsIgnored));
      expect(plan.report.fileAgeDays, greaterThan(31));
      expect(
        planOf(backup).report.warnings,
        isNot(contains(ImportWarning.staleFile)),
      );
    });
  });

  group('the report', () {
    test('lists problems by code and category without any first name', () {
      final broken = backup.snapshot.copyWith(
        attempts: [...backup.snapshot.attempts, backup.snapshot.attempts.first],
      );
      final plan = planOf(backup, snapshot: broken);
      expect(plan.status, ImportStatus.blocked);
      expect(codes(plan), contains('duplicateId'));
      final text = '${plan.report.problems}';
      for (final student in backup.snapshot.students) {
        expect(text, isNot(contains(student.firstName)));
      }
    });

    test(
      'a file that could not be read gives a blocked plan with its reason',
      () {
        final plan = const ClubImportPlanner().plan(
          ClubImportInput(
            actor: director,
            now: DateTime.utc(2026, 10, 12),
            preProblems: const [
              ImportProblem(ImportProblemCode.unreadable, null),
            ],
          ),
        );
        expect(plan.status, ImportStatus.blocked);
        expect(codes(plan), ['unreadable']);
        expect(plan.lots, isEmpty);
      },
    );
  });
}
