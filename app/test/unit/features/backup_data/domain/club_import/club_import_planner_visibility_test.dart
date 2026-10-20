import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_planner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/realistic_backup.dart';
import 'planner_support.dart';

/// Ce qu'un enseignant ne peut pas savoir : une fiche qui existe déjà dans le
/// club **hors de ses groupes** (ou sans groupe) lui est invisible (les règles
/// ne lui laissent lire que les fiches de ses groupes, et refusent aussi la
/// lecture d'une fiche absente). Le plan la croirait neuve et annoncerait
/// permises des écritures que les règles refuseront en bloc : il le dit donc
/// avant d'écrire, et demande une confirmation explicite.
void main() {
  final single = RealisticBackup(groups: 1, history: true);
  final decisions = ImportDecisions(
    groups: {single.groupId(1): const UseExistingGroup(GroupId('club-a'))},
  );

  ClubInventory visibleToTeacher({
    Map<StudentId, Set<GroupId>> students = const {},
    ImportMarker? marker,
  }) => ClubInventory(
    groups: clubGroups({'club-a': Audience.children}),
    seasons: clubSeason(),
    students: students,
    existing: {
      ImportCategory.students: {for (final id in students.keys) id.value},
    },
    marker: marker,
  );

  ClubImportPlan plan(
    ImportActor actor,
    ClubInventory inventory, {
    int? unverifiedConfirmed,
  }) => const ClubImportPlanner().plan(
    ClubImportInput(
      snapshot: single.snapshot,
      fingerprint: sha256Hex(single.content),
      version: 5,
      exportedAt: single.exportedAt,
      actor: actor,
      inventory: inventory,
      decisions: decisions.copyWith(unverifiedConfirmed: unverifiedConfirmed),
      now: DateTime.utc(2026, 10, 12, 10),
    ),
  );

  test('a teacher is told that the fiches she creates cannot be checked', () {
    final result = plan(teacher(['club-a']), visibleToTeacher());
    expect(result.status, ImportStatus.needsConfirmation);
    expect(result.report.unverifiableStudents, 3);
    expect(result.isRunnable, isFalse);
    expect(result.lots, isEmpty);
  });

  test('the fiches she can see are not counted, the others are', () {
    final seen = single.studentId(1, 1);
    final memberships = {
      for (final w in writesOf(
        planOf(
          single,
          actor: director,
          decisions: decisions,
          inventory: visibleToTeacher(),
        ),
        ImportCategory.memberships,
      ))
        if (w.student == seen) w.id,
    };
    final result = plan(
      teacher(['club-a']),
      ClubInventory(
        groups: clubGroups({'club-a': Audience.children}),
        seasons: clubSeason(),
        students: {
          seen: const {GroupId('club-a')},
        },
        existing: {
          ImportCategory.students: {seen.value},
          ImportCategory.memberships: memberships,
        },
      ),
    );
    expect(result.report.unverifiableStudents, 2);
    expect(result.status, ImportStatus.needsConfirmation);
  });

  test('confirming the exact number makes the plan runnable', () {
    final result = plan(
      teacher(['club-a']),
      visibleToTeacher(),
      unverifiedConfirmed: 3,
    );
    expect(result.status, ImportStatus.ready);
    expect(result.report.unverifiableStudents, 3);
    expect(result.isRunnable, isTrue);
  });

  test('a wrong number is not a confirmation', () {
    final result = plan(
      teacher(['club-a']),
      visibleToTeacher(),
      unverifiedConfirmed: 2,
    );
    expect(result.status, ImportStatus.needsConfirmation);
  });

  test('a manager sees the whole club: nothing to confirm', () {
    final result = plan(director, visibleToTeacher());
    expect(result.report.unverifiableStudents, 0);
    expect(result.status, ImportStatus.ready);
  });

  test('a running import is not asked again, and keeps its plan id', () {
    final confirmed = plan(
      teacher(['club-a']),
      visibleToTeacher(),
      unverifiedConfirmed: 3,
    );
    final resumed = plan(
      teacher(['club-a']),
      visibleToTeacher(
        marker: ImportMarker(
          fileId: confirmed.fingerprint,
          planId: confirmed.planId,
          lots: confirmed.lots.length,
          done: 1,
          writes: confirmed.totalWrites,
          restored: 0,
          role: Role.teacher,
        ),
      ),
    );
    expect(resumed.status, ImportStatus.resumable);
  });

  test('a fiche appearing outside her groups between two runs leaves the '
      'plan unchanged (the rules refuse the lot, the runner reports it)', () {
    final confirmed = plan(
      teacher(['club-a']),
      visibleToTeacher(),
      unverifiedConfirmed: 3,
    );
    final marker = ImportMarker(
      fileId: confirmed.fingerprint,
      planId: confirmed.planId,
      lots: confirmed.lots.length,
      done: 1,
      writes: confirmed.totalWrites,
      restored: 0,
      role: Role.teacher,
    );
    // Entre-temps, quelqu'un crée la fiche du fichier dans un autre groupe :
    // l'enseignant ne la voit toujours pas, son inventaire est inchangé. Le
    // plan, indépendant de l'existant, reste le même et reprend au lot 1 sans
    // reposer la question ; le lot qui retomberait sur cette fiche est refusé
    // en bloc par les règles (marqueur inchangé), ce que le moteur signale
    // (`club_import_runner_test`, « a refusal of the rules stops the import »).
    final resumed = plan(teacher(['club-a']), visibleToTeacher(marker: marker));
    expect(resumed.status, ImportStatus.resumable);
    expect(resumed.planId, confirmed.planId);
    expect(resumed.startLot, 1);
    expect(resumed.lots.length, confirmed.lots.length);
    expect(resumed.report.unverifiableStudents, 0);
    expect(resumed.report.problems, isEmpty);
  });
}
