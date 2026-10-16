import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/get_upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;

  Future<void> plan(String id, int dayOfMonth, {String? sheet}) =>
      world.plannedSessions.add(
        Session(
          id: id,
          title: id,
          date: day(dayOfMonth),
          audience: Audience.children,
          groupId: const GroupId('g1'),
          sheetId: sheet == null ? null : SheetId(sheet),
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

  // D1 (ADR 0016) : l'accueil annonce la séance planifiée du jour même si une
  // autre séance du catalogue a été saisie ce jour-là.
  test('announces the session planned today despite the record of another '
      'catalogue session', () async {
    await world.session(
      id: 'x-posture',
      dayOfMonth: 12,
      sheet: SheetId('posture-1'),
    );
    await plan('p-demi', 12, sheet: 'demi-bille-2');

    final result = ok(await build(DateTime(2026, 10, 12, 9))());

    expect(result.next?.session.id, 'p-demi');
  });

  test(
    'keeps the other session of the day next once one is recorded',
    () async {
      await plan('p-posture', 12, sheet: 'posture-1');
      await plan('p-demi', 12, sheet: 'demi-bille-2');
      await world.session(
        id: 'x-posture',
        dayOfMonth: 12,
        sheet: SheetId('posture-1'),
      );

      final result = ok(await build(DateTime(2026, 10, 12, 9))());

      expect(result.next?.session.id, 'p-demi');
      expect(result.sameDayOthers, 0);
    },
  );
}
