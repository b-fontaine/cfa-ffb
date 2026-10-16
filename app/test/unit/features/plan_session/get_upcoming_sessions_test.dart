import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/get_upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;

  Future<void> plan(String id, int dayOfMonth) => world.plannedSessions.add(
    Session(
      id: id,
      title: id,
      date: day(dayOfMonth),
      audience: Audience.children,
      groupId: const GroupId('g1'),
    ),
  );

  GetUpcomingSessions build(DateTime now) => GetUpcomingSessions(
    ListSessions(world.plannedSessions, world.groups, world.sessions),
    world.groups,
    FixedClock(now),
  );

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
  });

  test('reads the next session from the injected clock', () async {
    await plan('past', 5);
    await plan('next', 14);

    final result = ok(await build(DateTime(2026, 10, 12, 18))());

    expect(result.next?.session.id, 'next');
    expect(result.next?.group?.name, 'Groupe');
  });

  test('moving the clock moves the next session', () async {
    await plan('first', 14);
    await plan('second', 20);

    final result = ok(await build(DateTime(2026, 10, 15))());

    expect(result.next?.session.id, 'second');
    expect([for (final s in result.toRecord) s.session.id], ['first']);
  });

  test('gives the name of the groups of the club', () async {
    final result = ok(await build(DateTime(2026, 10, 12))());

    expect(result.groupNames, {const GroupId('g1'): 'Groupe'});
  });
}
