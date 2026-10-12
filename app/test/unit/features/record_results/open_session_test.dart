import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

class Fixture {
  Fixture(this.world)
    : openSession = OpenSession(
        world.groups,
        world.seasons,
        world.sessions,
        world.catalogueRepository,
        world.ids,
      );

  final DomainWorld world;
  final OpenSession openSession;

  Future<Result<SessionRecord>> open({
    String group = 'g1',
    int dayOfMonth = 5,
    Set<String> present = const {'s1'},
    String? main,
    String? recall,
  }) => openSession(
    groupId: GroupId(group),
    date: day(dayOfMonth),
    present: {for (final name in present) StudentId(name)},
    mainBlockId: main,
    recallBlockId: recall,
  );
}

Future<Fixture> fixture({Audience audience = Audience.children}) async {
  final world = DomainWorld();
  await world.seedClub(studentNames: ['s1', 's2'], audience: audience);
  return Fixture(world);
}

void main() {
  test('opens and stores the session with the group audience', () async {
    final f = await fixture(audience: Audience.adults);

    final session = ok(
      await f.open(present: {'s1', 's2'}, main: 'a', recall: 'b'),
    );

    expect(session.audience, Audience.adults);
    expect(session.plannedDurationMinutes, 120);
    expect(session.present, {const StudentId('s1'), const StudentId('s2')});
    expect(session.mainBlockId, 'a');
    expect(session.recallBlockId, 'b');
    expect(session.seasonId, const SeasonId('season'));
    expect(await f.world.sessions.byId(session.id), session);
  });

  test('accepts the first and the last day of the season', () async {
    final f = await fixture();

    expect(await f.open(dayOfMonth: 1), isA<Ok<SessionRecord>>());
    expect(await f.open(dayOfMonth: 31), isA<Ok<SessionRecord>>());
  });

  test('refuses a date outside the season', () async {
    final f = await fixture();

    final result = await f.openSession(
      groupId: const GroupId('g1'),
      date: day(1).subtract(const Duration(days: 1)),
      present: {const StudentId('s1')},
    );
    final after = await f.openSession(
      groupId: const GroupId('g1'),
      date: day(31).add(const Duration(days: 1)),
      present: {const StudentId('s1')},
    );

    expect(codeOf(result), InvariantCode.seasonOutsidePeriod);
    expect(codeOf(after), InvariantCode.seasonOutsidePeriod);
  });

  test('refuses an unknown group', () async {
    final f = await fixture();

    final failure = err(await f.open(group: 'nope'));

    expect(failure, isA<NotFound>().having((n) => n.kind, 'kind', 'group'));
  });

  test('refuses a group whose season is unknown', () async {
    final world = DomainWorld();
    await world.groups.save(
      Group(
        id: const GroupId('g1'),
        seasonId: const SeasonId('missing'),
        name: 'Groupe',
        audience: Audience.children,
      ),
    );
    final f = Fixture(world);

    final failure = err(await f.open());

    expect(failure, isA<NotFound>().having((n) => n.kind, 'kind', 'season'));
  });

  test('refuses a present student who is not a member of the group', () async {
    final f = await fixture();

    expect(
      codeOf(await f.open(present: {'s1', 'stranger'})),
      InvariantCode.studentNotInGroup,
    );
  });

  test('refuses an unknown main block', () async {
    final f = await fixture();

    expect(codeOf(await f.open(main: 'zzz')), InvariantCode.unknownBlock);
  });

  test('refuses an unknown recall block', () async {
    final f = await fixture();

    expect(codeOf(await f.open(recall: 'zzz')), InvariantCode.unknownBlock);
  });

  test('refuses the same block as main and recall', () async {
    final f = await fixture();

    expect(
      codeOf(await f.open(main: 'a', recall: 'a')),
      InvariantCode.recallEqualsMainBlock,
    );
  });

  test('opens a session with nobody present', () async {
    final f = await fixture();

    expect(ok(await f.open(present: {})).present, isEmpty);
  });
}
