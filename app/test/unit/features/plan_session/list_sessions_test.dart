import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late ListSessions list;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    list = ListSessions(world.plannedSessions, world.groups, world.sessions);
  });

  Future<void> plan(String id, int dayOfMonth, {GroupId? group}) =>
      world.plannedSessions.add(
        Session(
          id: id,
          title: id,
          date: day(dayOfMonth),
          audience: Audience.children,
          groupId: group,
        ),
      );

  test('lists nothing when nothing is planned', () async {
    expect(await list(), isEmpty);
  });

  test('orders by date, then by planning order', () async {
    await plan('late', 19);
    await plan('first-12', 12);
    await plan('second-12', 12);
    await plan('early', 5);

    final ids = [for (final s in await list()) s.session.id];

    expect(ids, ['early', 'first-12', 'second-12', 'late']);
  });

  test('gives the group and the record of the same group and day', () async {
    await plan('p1', 12, group: const GroupId('g1'));
    await world.session(id: 'x-other', dayOfMonth: 11);
    await world.session(id: 'x-same', dayOfMonth: 12);

    final summary = (await list()).single;

    expect(summary.group?.name, 'Groupe');
    expect(summary.groupUnavailable, isFalse);
    expect(summary.recordId, const SessionId('x-same'));
  });

  test('ignores the record of another group on the same day', () async {
    await plan('p1', 12, group: const GroupId('g1'));
    await world.sessions.save(
      SessionRecord(
        id: const SessionId('x-g2'),
        groupId: const GroupId('g2'),
        seasonId: const SeasonId('season'),
        date: day(12),
        audience: Audience.children,
        present: const {},
      ),
    );

    expect((await list()).single.recordId, isNull);
  });

  test('has neither group nor record for a session without group', () async {
    await plan('p1', 12);
    await world.session(dayOfMonth: 12);

    final summary = (await list()).single;

    expect(summary.group, isNull);
    expect(summary.groupUnavailable, isFalse);
    expect(summary.recordId, isNull);
  });

  test('flags a group the club no longer knows', () async {
    await plan('p1', 12, group: const GroupId('gone'));

    final summary = (await list()).single;

    expect(summary.group, isNull);
    expect(summary.groupUnavailable, isTrue);
    expect(summary.recordId, isNull);
  });

  test('is unmodifiable', () async {
    final summaries = await list();

    expect(summaries.clear, throwsUnsupportedError);
  });
}
