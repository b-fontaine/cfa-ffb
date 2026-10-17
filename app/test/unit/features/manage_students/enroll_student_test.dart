import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/manage_students/domain/enroll_student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late EnrollStudent enroll;

  setUp(() {
    world = DomainWorld();
    enroll = EnrollStudent(
      world.students,
      world.groups,
      world.seasons,
      world.ids,
      InMemoryUnitOfWork(),
    );
  });

  Future<Result<EnrolledStudent>> call({
    String firstName = 'Léa',
    Audience audience = Audience.children,
    DateTime? today,
    String? groupName,
    GroupId? groupId,
  }) => enroll(
    firstName: firstName,
    audience: audience,
    today: today ?? day(12),
    groupName: groupName,
    groupId: groupId,
  );

  test('enrols the student in the group of the season of today', () async {
    await world.seedClub(studentNames: ['s1']);

    final enrolled = ok(await call());

    expect(enrolled.student.firstName, 'Léa');
    expect(enrolled.student.currentAudience, Audience.children);
    expect(enrolled.group.id, const GroupId('g1'));
    expect(enrolled.group.isMemberOn(enrolled.student.id, day(12)), isTrue);
    expect(await world.students.byId(enrolled.student.id), enrolled.student);
    expect(await world.groups.all(), hasLength(1));
  });

  test('is a member and a pupil from the start of the season', () async {
    await world.seedClub(studentNames: ['s1']);

    final enrolled = ok(await call());

    expect(enrolled.student.audienceHistory.single.effectiveFrom, day(1));
    expect(enrolled.group.isMemberOn(enrolled.student.id, day(1)), isTrue);
  });

  test('trims the first name', () async {
    await world.seedClub();

    expect(ok(await call(firstName: '  Léa ')).student.firstName, 'Léa');
  });

  test('creates the group of the audience when the season has none', () async {
    await world.seedClub();

    final enrolled = ok(
      await call(audience: Audience.adults, groupName: 'Adultes'),
    );

    expect(enrolled.group.name, 'Adultes');
    expect(enrolled.group.audience, Audience.adults);
    expect(enrolled.group.seasonId, const SeasonId('season'));
    expect(await world.groups.all(), hasLength(2));
  });

  test('names a created group after the audience by default', () async {
    await world.seedClub();

    expect(ok(await call(audience: Audience.adults)).group.name, 'adults');
  });

  test('creates the school year when no season exists', () async {
    final enrolled = ok(await call(today: DateTime(2026, 10, 12)));

    final seasons = await world.seasons.all();
    expect(seasons, hasLength(1));
    expect(seasons.single.label, '2026-2027');
    expect(seasons.single.startDate, DateTime(2026, 9));
    expect(seasons.single.endDate, DateTime(2027, 8, 31));
    expect(enrolled.group.seasonId, seasons.single.id);
  });

  test('a date before July belongs to the previous school year', () async {
    ok(await call(today: DateTime(2027, 2, 3)));

    expect((await world.seasons.all()).single.label, '2026-2027');
  });

  test('enrols at today when the season has not started yet', () async {
    await world.seasons.save(
      Season(
        id: const SeasonId('later'),
        label: '2027-2028',
        startDate: DateTime(2027, 9),
        endDate: DateTime(2028, 6, 30),
      ),
    );

    final enrolled = ok(await call(today: DateTime(2027, 8, 20)));

    expect(enrolled.group.seasonId, const SeasonId('later'));
    expect(
      enrolled.student.audienceHistory.single.effectiveFrom,
      DateTime(2027, 8, 20),
    );
  });

  test(
    'reuses a season starting late instead of creating a second one',
    () async {
      await world.seasons.save(
        Season(
          id: const SeasonId('late'),
          label: '2026-2027',
          startDate: DateTime(2026, 10),
          endDate: DateTime(2027, 6, 30),
        ),
      );

      final enrolled = ok(await call(today: DateTime(2026, 9, 15)));

      expect(await world.seasons.all(), hasLength(1));
      expect(enrolled.group.seasonId, const SeasonId('late'));
    },
  );

  test('refuses a blank first name and stores nothing', () async {
    await world.seedClub();

    expect(codeOf(await call(firstName: '  ')), InvariantCode.blankName);
    expect(await world.students.all(), hasLength(1));
    expect(await world.groups.all(), hasLength(1));
  });

  group('several groups for the audience', () {
    Future<void> addSecondGroup() => world.groups.save(
      Group(
        id: const GroupId('g2'),
        seasonId: const SeasonId('season'),
        name: 'Mercredi',
        audience: Audience.children,
      ),
    );

    test('asks for a group when the audience has several', () async {
      await world.seedClub();
      await addSecondGroup();

      expect(codeOf(await call()), InvariantCode.groupChoiceRequired);
      expect(await world.students.all(), hasLength(1));
    });

    test('enrols in the requested group', () async {
      await world.seedClub();
      await addSecondGroup();

      final enrolled = ok(await call(groupId: const GroupId('g2')));

      expect(enrolled.group.id, const GroupId('g2'));
      expect(enrolled.group.isMemberOn(enrolled.student.id, day(12)), isTrue);
      final other = await world.groups.byId(const GroupId('g1'));
      expect(other!.memberships.map((m) => m.studentId), [
        const StudentId('s1'),
      ]);
    });

    test('refuses a requested group of another audience', () async {
      await world.seedClub(studentNames: const []);
      await world.groups.save(
        Group(
          id: const GroupId('ga'),
          seasonId: const SeasonId('season'),
          name: 'Adultes',
          audience: Audience.adults,
        ),
      );

      expect(
        codeOf(await call(groupId: const GroupId('ga'))),
        InvariantCode.audienceMismatch,
      );
    });
  });

  test('accepts a first name of 40 characters and refuses 41', () async {
    expect(ok(await call(firstName: 'é' * 40)).student.firstName, 'é' * 40);

    final tooLong = await call(firstName: 'é' * 41);
    expect(codeOf(tooLong), InvariantCode.nameTooLong);
    expect(await world.students.all(), hasLength(1));
  });
}
