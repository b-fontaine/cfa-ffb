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
      world.acquisitions,
      world.acknowledgements,
      world.catalogueRepository,
      world.config,
    );
  });

  test('a student without any pass or acquired block is to start', () async {
    await world.seedClub(studentNames: ['s1', 's2', 's3']);
    await world.attempts.add(
      attempt(ref('a', 1), potted: 0, student: 's2', id: 'f1'),
    );
    await world.acquisitions.add(acquisition('b', student: 's3'));

    final club = ok(await overview(today: day(12)));
    final members = {
      for (final m in club.groups.single.members) m.student.id.value: m,
    };

    expect(members['s1']!.toStart, isTrue);
    expect(members['s2']!.toStart, isFalse, reason: 'a failed pass is a start');
    expect(members['s3']!.toStart, isFalse, reason: 'an acquired block counts');
    expect(members['s2']!.validatedCount, 0);
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
        attempt(ref('a', 1), potted: 4, id: 'v$pass', dayOfMonth: 2 + pass),
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

  test('counts the exercises acquired at placement in the progress', () async {
    await world.seedClub(studentNames: ['s1', 's2']);
    await world.acquisitions.add(acquisition('b', student: 's2'));

    final club = ok(await overview(today: day(12)));

    final members = club.groups.single.members;
    expect(members.first.validatedCount, 0);
    expect(members.last.validatedCount, 3);
  });

  test('puts a student without membership in the unassigned list', () async {
    await world.seedClub();
    await world.students.create(
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

  test('does not count an alert the instructor has seen', () async {
    await world.seedClub(studentNames: ['s1']);
    for (var pass = 0; pass < 3; pass++) {
      await world.attempts.add(
        attempt(ref('a', 1), potted: 1, id: 'f$pass', dayOfMonth: 2 + pass),
      );
    }
    expect(
      ok(await overview(today: day(12)))
          .groups
          .single
          .members
          .single
          .alertCount,
      1,
    );

    await world.acknowledgements.add(
      acknowledgement(ref('a', 1), lastAttempt: 'f2'),
    );

    expect(
      ok(await overview(today: day(12)))
          .groups
          .single
          .members
          .single
          .alertCount,
      0,
    );
  });

  test('does not list the groups of a closed season', () async {
    await world.seedClub(studentNames: ['s1']);
    await world.seasons.save(
      (await world.seasons.byId(const SeasonId('season')))!
          .copyWith(closedOn: day(10)),
    );

    final club = ok(await overview(today: day(8)));

    expect(club.groups, isEmpty);
  });

  group('a prepared season that has not started', () {
    setUp(() async {
      await world.seedClub(studentNames: ['s1']);
      await world.seasons.save(
        (await world.seasons.byId(const SeasonId('season')))!
            .copyWith(closedOn: day(10)),
      );
      await world.seasons.save(
        Season(
          id: const SeasonId('next'),
          label: '2026-2027 (2)',
          startDate: day(20),
          endDate: DateTime(2027, 8, 31),
        ),
      );
      await world.groups.save(
        Group(
          id: const GroupId('gn'),
          seasonId: const SeasonId('next'),
          name: 'Groupe',
          audience: Audience.children,
        ).admit(
          studentId: const StudentId('s1'),
          studentAudience: Audience.children,
          from: day(20),
        ),
      );
    });

    test('shows its roster as of its first day, not as unassigned', () async {
      final club = ok(await overview(today: day(12)));

      expect(club.groups.map((g) => g.group.id.value), ['gn']);
      expect(club.groups.single.members.map((m) => m.student.id.value), ['s1']);
      expect(club.unassigned, isEmpty);
    });

    test('shows the roster of the day once the season has started', () async {
      final club = ok(await overview(today: day(25)));

      expect(club.groups.single.members, hasLength(1));
      expect(club.unassigned, isEmpty);
    });
  });
}
