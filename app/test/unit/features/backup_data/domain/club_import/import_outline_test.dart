import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_outline.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/realistic_backup.dart';
import 'planner_support.dart';

void main() {
  final backup = RealisticBackup();

  test('lists the groups of the file with their season and head count', () {
    final outline = ImportOutline.of(backup.snapshot);
    expect([for (final g in outline.groups) g.name], ['Groupe 1', 'Groupe 2']);
    expect(outline.groups.first.seasonLabel, isNotNull);
    expect(outline.groups.first.students, 3);
    expect(outline.groups.first.audience, Audience.children);
    expect(outline.groups.last.audience, Audience.adults);
    expect(outline.looseSessions, isEmpty);
    expect(outline.looseStudents, isEmpty);
    expect(outline.marker, isNull);
  });

  test('lists the planned sessions and the students without a group', () {
    final snapshot = backup.snapshot.copyWith(
      plannedSessions: [
        ...backup.snapshot.plannedSessions,
        Session(
          id: 'p-orphan',
          title: 'Libre',
          date: DateTime(2026, 11, 5),
          audience: Audience.children,
        ),
      ],
      groups: [
        for (final g in backup.snapshot.groups)
          if (g.id == backup.groupId(2))
            g.copyWith(memberships: const <Membership>[])
          else
            g,
      ],
    );
    final outline = ImportOutline.of(snapshot);
    expect([for (final s in outline.looseSessions) s.id], ['p-orphan']);
    expect(outline.looseStudents.length, 3);
    expect(outline.groups.last.students, 0);
  });

  test('keeps the marker as counts only', () {
    const marker = ImportMarker(
      fileId: 'f',
      planId: 'p',
      lots: 4,
      done: 1,
      writes: 10,
      restored: 0,
      role: Role.director,
    );
    final outline = ImportOutline.of(backup.snapshot, marker: marker);
    expect(outline.marker!.done, 1);
    expect(outline.marker!.lots, 4);
  });

  test('a plan carries its outline through withOutline', () {
    final plan = planOf(backup, decisions: createAll(backup.snapshot));
    final outline = ImportOutline.of(backup.snapshot);
    final carried = plan.withOutline(outline);
    expect(carried.outline, same(outline));
    expect(carried.planId, plan.planId);
    expect(carried.lots.length, plan.lots.length);
    expect(plan.outline.groups, isEmpty);
  });
}
