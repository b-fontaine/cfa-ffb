import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/change_audience/domain/audience_change_outcome.dart';
import 'package:billard_cfa/features/change_audience/domain/change_audience.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late ChangeAudience change;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    change = ChangeAudience(
      world.students,
      world.assessments,
      world.groups,
      world.ids,
      world.config,
      InMemoryUnitOfWork(),
    );
  });

  Future<void> assess(int score, {int dayOfMonth = 3}) => world.assessments.add(
    MaturityAssessment(
      id: AssessmentId('m$dayOfMonth'),
      studentId: const StudentId('s1'),
      date: day(dayOfMonth),
      concentration: score,
      endurance: score,
      frustration: score,
    ),
  );

  Future<Result<AudienceChangeOutcome>> toAdults({
    int dayOfMonth = 10,
    String? groupName,
    GroupId? destinationGroupId,
  }) => change(
    studentId: const StudentId('s1'),
    audience: Audience.adults,
    effectiveFrom: day(dayOfMonth),
    groupName: groupName,
    destinationGroupId: destinationGroupId,
  );

  test('moves the student and keeps the history', () async {
    await assess(4);

    final outcome = ok(await toAdults());

    expect(outcome.student.currentAudience, Audience.adults);
    expect(outcome.student.audienceHistory, hasLength(2));
    final saved = await world.students.byId(const StudentId('s1'));
    expect(saved, outcome.student);
  });

  test(
    'warns when there is no maturity assessment, without blocking',
    () async {
      final outcome = ok(await toAdults());

      expect(outcome.warnings, [AudienceChangeWarning.noAssessment]);
      expect(outcome.student.currentAudience, Audience.adults);
    },
  );

  test(
    'warns when the latest assessment does not indicate readiness',
    () async {
      await assess(2);

      final outcome = ok(await toAdults());

      expect(outcome.warnings, [AudienceChangeWarning.readinessNotIndicated]);
    },
  );

  test(
    'does not warn when the latest assessment indicates readiness',
    () async {
      await assess(2, dayOfMonth: 2);
      await assess(3, dayOfMonth: 5);

      final outcome = ok(await toAdults());

      expect(outcome.warnings, isEmpty);
    },
  );

  test('judges only the most recent assessment', () async {
    await assess(4, dayOfMonth: 2);
    await assess(1, dayOfMonth: 5);

    final outcome = ok(await toAdults());

    expect(outcome.warnings, [AudienceChangeWarning.readinessNotIndicated]);
  });

  test('does not warn when going back to children', () async {
    ok(await toAdults());

    final outcome = ok(
      await change(
        studentId: const StudentId('s1'),
        audience: Audience.children,
        effectiveFrom: day(20),
      ),
    );

    expect(outcome.warnings, isEmpty);
    expect(outcome.student.audienceHistory, hasLength(3));
  });

  test('refuses an unchanged audience and stores nothing', () async {
    final result = await change(
      studentId: const StudentId('s1'),
      audience: Audience.children,
      effectiveFrom: day(10),
    );

    expect(codeOf(result), InvariantCode.audienceUnchanged);
  });

  test('refuses a change that is not after the enrolment', () async {
    expect(
      codeOf(await toAdults(dayOfMonth: 1)),
      InvariantCode.audienceChangeNotChronological,
    );
  });

  test('refuses an unknown student', () async {
    final result = await change(
      studentId: const StudentId('nope'),
      audience: Audience.adults,
      effectiveFrom: day(10),
    );

    expect(
      err(result),
      isA<NotFound>()
          .having((n) => n.kind, 'kind', 'student')
          .having((n) => n.id, 'id', 'nope'),
    );
  });

  group('group membership', () {
    Future<List<Group>> groups() => world.groups.all();

    test('closes the old membership the day before and opens a new '
        'group of the new audience', () async {
      ok(await toAdults(groupName: 'Grands'));

      final all = await groups();
      expect(all, hasLength(2));
      final old = all.first;
      expect(old.memberships.single.to, day(9));
      expect(old.isMemberOn(const StudentId('s1'), day(10)), isFalse);
      final created = all.last;
      expect(created.name, 'Grands');
      expect(created.audience, Audience.adults);
      expect(created.seasonId, old.seasonId);
      expect(created.isMemberOn(const StudentId('s1'), day(10)), isTrue);
      expect(created.isMemberOn(const StudentId('s1'), day(9)), isFalse);
    });

    test('names the new group after the audience by default', () async {
      ok(await toAdults());

      expect((await groups()).last.name, 'adults');
    });

    test(
      'reuses an existing group of the new audience in the season',
      () async {
        await world.groups.save(
          Group(
            id: const GroupId('g2'),
            seasonId: const SeasonId('season'),
            name: 'Adultes',
            audience: Audience.adults,
          ),
        );

        ok(await toAdults());

        final all = await groups();
        expect(all, hasLength(2));
        final adults = await world.groups.byId(const GroupId('g2'));
        expect(adults!.isMemberOn(const StudentId('s1'), day(10)), isTrue);
      },
    );

    test('never closes a membership before it started', () async {
      var late = Group(
        id: const GroupId('g3'),
        seasonId: const SeasonId('season'),
        name: 'Tard',
        audience: Audience.children,
      );
      late = late.admit(
        studentId: const StudentId('s2'),
        studentAudience: Audience.children,
        from: day(8),
      );
      await world.groups.save(late);
      await world.students.save(
        Student.enroll(
          id: const StudentId('s2'),
          firstName: 's2',
          audience: Audience.children,
          since: day(1),
        ),
      );

      ok(
        await change(
          studentId: const StudentId('s2'),
          audience: Audience.adults,
          effectiveFrom: day(5),
        ),
      );

      final closed = await world.groups.byId(const GroupId('g3'));
      expect(closed!.memberships.single.to, day(8));
    });

    test(
      'leaves the groups alone when the student has no membership',
      () async {
        await world.students.save(
          Student.enroll(
            id: const StudentId('loner'),
            firstName: 'Loner',
            audience: Audience.children,
            since: day(1),
          ),
        );

        ok(
          await change(
            studentId: const StudentId('loner'),
            audience: Audience.adults,
            effectiveFrom: day(10),
          ),
        );

        expect(await groups(), hasLength(1));
      },
    );

    test('does not touch other members of the old group', () async {
      await world.seedClub(studentNames: ['s1', 's2']);

      ok(await toAdults());

      final old = await world.groups.byId(const GroupId('g1'));
      expect(old!.isMemberOn(const StudentId('s2'), day(10)), isTrue);
    });

    test('moves nothing when the change is refused', () async {
      await toAdults(dayOfMonth: 1);

      expect(await groups(), hasLength(1));
      expect(
        (await groups()).single.isMemberOn(const StudentId('s1'), day(10)),
        isTrue,
      );
    });
  });

  group('several adult groups', () {
    Future<void> addAdultGroups() async {
      for (final id in ['ga1', 'ga2']) {
        await world.groups.save(
          Group(
            id: GroupId(id),
            seasonId: const SeasonId('season'),
            name: id,
            audience: Audience.adults,
          ),
        );
      }
    }

    test('asks for the destination group and changes nothing', () async {
      await addAdultGroups();

      expect(codeOf(await toAdults()), InvariantCode.groupChoiceRequired);

      final saved = await world.students.byId(const StudentId('s1'));
      expect(saved!.currentAudience, Audience.children);
      final origin = await world.groups.byId(const GroupId('g1'));
      expect(origin!.memberships.single.to, isNull);
    });

    test('joins the requested destination group', () async {
      await addAdultGroups();

      ok(await toAdults(destinationGroupId: const GroupId('ga2')));

      final chosen = await world.groups.byId(const GroupId('ga2'));
      expect(chosen!.isMemberOn(const StudentId('s1'), day(10)), isTrue);
      final other = await world.groups.byId(const GroupId('ga1'));
      expect(other!.memberships, isEmpty);
    });

    test('refuses a destination of the wrong audience', () async {
      await addAdultGroups();
      await world.groups.save(
        Group(
          id: const GroupId('gk'),
          seasonId: const SeasonId('season'),
          name: 'Autre',
          audience: Audience.children,
        ),
      );

      final result = await toAdults(destinationGroupId: const GroupId('gk'));

      expect(codeOf(result), InvariantCode.audienceMismatch);
    });
  });
}
