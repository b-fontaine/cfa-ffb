import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/manage_students/domain/get_club_overview.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late GetClubOverview overview;

  setUp(() {
    world = DomainWorld();
    overview = GetClubOverview(
      world.groups,
      world.students,
      world.seasons,
      world.attempts,
      world.catalogueRepository,
      world.config,
    );
  });

  test('is empty for a new club', () async {
    final club = ok(await overview(today: day(12)));

    expect(club.groups, isEmpty);
    expect(club.unassigned, isEmpty);
  });

  test('lists the members of each group with their progress', () async {
    await world.seedClub(studentNames: ['s1', 's2']);
    for (var pass = 0; pass < 5; pass++) {
      await world.attempts.add(
        attempt(
          ref('a', 1),
          potted: 4,
          id: 'v$pass',
          passIndex: 1 + pass % 2,
          dayOfMonth: 2 + pass,
        ),
      );
    }
    for (var pass = 0; pass < 3; pass++) {
      await world.attempts.add(
        attempt(
          ref('b', 1),
          potted: 1,
          student: 's2',
          id: 'f$pass',
          dayOfMonth: 2 + pass,
        ),
      );
    }

    final club = ok(await overview(today: day(12)));

    final group = club.groups.single;
    expect(group.group.id, const GroupId('g1'));
    expect(group.members.map((m) => m.student.firstName), ['s1', 's2']);
    final first = group.members.first;
    expect(first.validatedCount, 1);
    expect(first.exerciseCount, 9);
    expect(first.alertCount, 0);
    expect(group.members.last.alertCount, 1);
    expect(club.alertCount, 1);
  });

  test('puts a student without membership in the unassigned list', () async {
    await world.seedClub();
    await world.students.save(
      Student.enroll(
        id: const StudentId('loner'),
        firstName: 'Loner',
        audience: Audience.adults,
        since: day(1),
      ),
    );

    final club = ok(await overview(today: day(12)));

    expect(club.unassigned.map((s) => s.student.firstName), ['Loner']);
  });

  test('hides a student who left the group before today', () async {
    await world.seedClub(studentNames: ['s1', 's2']);
    final group = (await world.groups.byId(const GroupId('g1')))!
        .release(studentId: const StudentId('s2'), to: day(5));
    await world.groups.save(group);

    final club = ok(await overview(today: day(12)));

    expect(club.groups.single.members.map((m) => m.student.firstName), ['s1']);
    expect(club.unassigned.map((s) => s.student.firstName), ['s2']);
  });

  test('keeps only the groups of the current season', () async {
    await world.seedClub();
    await world.seasons.save(
      Season(
        id: const SeasonId('old'),
        label: '2025-2026',
        startDate: DateTime(2025, 9),
        endDate: DateTime(2026, 6, 30),
      ),
    );
    await world.groups.save(
      Group(
        id: const GroupId('old-group'),
        seasonId: const SeasonId('old'),
        name: 'Ancien',
        audience: Audience.adults,
      ),
    );

    final club = ok(await overview(today: day(12)));

    expect(club.groups.map((g) => g.group.id), [const GroupId('g1')]);
  });

  test('falls back to every group when no season contains today', () async {
    await world.seedClub();

    final club = ok(await overview(today: DateTime(2027, 7)));

    expect(club.groups.map((g) => g.group.id), [const GroupId('g1')]);
  });
}
