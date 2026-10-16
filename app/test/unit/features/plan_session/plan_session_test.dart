import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late PlanSession planSession;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(audience: Audience.adults);
    planSession = PlanSession(
      world.plannedSessions,
      world.groups,
      world.seasons,
      world.ids,
    );
  });

  test(
    'stores a trimmed session at the given day with a generated id',
    () async {
      final session = await planSession(
        title: '  Posture  ',
        date: DateTime(2026, 10, 12, 18, 30),
        audience: Audience.children,
      );

      final expected = Session(
        id: 'id-1',
        title: 'Posture',
        date: day(12),
        audience: Audience.children,
      );
      expect(session, expected);
      expect(await world.plannedSessions.getAll(), [expected]);
    },
  );

  test('keeps the chosen catalogue session', () async {
    final session = await planSession(
      title: 'Demi-bille',
      date: day(12),
      audience: Audience.adults,
      sheetId: SheetId('demi-bille-2'),
    );

    expect(session.sheetId?.value, 'demi-bille-2');
    expect(session.groupId, isNull);
  });

  test('takes the audience of the group it is planned for', () async {
    final session = await planSession(
      title: 'Cours',
      date: day(12),
      audience: Audience.children,
      groupId: const GroupId('g1'),
    );

    expect(session.groupId, const GroupId('g1'));
    expect(session.audience, Audience.adults, reason: 'public du groupe');
  });

  test('refuses an unknown group', () {
    expect(
      () => planSession(
        title: 'Cours',
        date: day(12),
        audience: Audience.adults,
        groupId: const GroupId('nope'),
      ),
      violation(InvariantCode.unknownGroup),
    );
  });

  test('refuses a date outside the season of the group', () async {
    expect(
      () => planSession(
        title: 'Cours',
        date: DateTime(2027, 7),
        audience: Audience.adults,
        groupId: const GroupId('g1'),
      ),
      violation(InvariantCode.seasonOutsidePeriod),
    );
    expect(await world.plannedSessions.getAll(), isEmpty);
  });

  test(
    'accepts the first and the last day of the season, whatever the hour',
    () async {
      final first = await planSession(
        title: 'Premier',
        date: DateTime(2026, 10, 1, 9),
        audience: Audience.adults,
        groupId: const GroupId('g1'),
      );
      final last = await planSession(
        title: 'Dernier',
        date: DateTime(2026, 10, 31, 23),
        audience: Audience.adults,
        groupId: const GroupId('g1'),
      );

      expect(first.date, day(1));
      expect(last.date, day(31));
    },
  );

  test('refuses the eve of the season and the day after its end', () async {
    for (final date in [DateTime(2026, 9, 30, 23), DateTime(2026, 11)]) {
      expect(
        () => planSession(
          title: 'Cours',
          date: date,
          audience: Audience.adults,
          groupId: const GroupId('g1'),
        ),
        violation(InvariantCode.seasonOutsidePeriod),
        reason: '$date',
      );
    }
    expect(await world.plannedSessions.getAll(), isEmpty);
  });

  test('refuses a group whose season is unknown', () async {
    await world.groups.save(
      Group(
        id: const GroupId('orphan'),
        seasonId: const SeasonId('missing'),
        name: 'Orphelin',
        audience: Audience.adults,
      ),
    );

    expect(
      () => planSession(
        title: 'Cours',
        date: day(12),
        audience: Audience.adults,
        groupId: const GroupId('orphan'),
      ),
      throwsA(
        isA<NotFound>()
            .having((n) => n.kind, 'kind', 'season')
            .having((n) => n.id, 'id', 'missing'),
      ),
    );
  });

  test('rejects a blank title without storing anything', () async {
    expect(
      () => planSession(title: '   ', date: day(12), audience: Audience.adults),
      throwsA(isA<InvalidSessionTitle>()),
    );
    expect(await world.plannedSessions.getAll(), isEmpty);
  });

  test('refuses a group of a closed season', () async {
    await world.seasons.save(
      (await world.seasons.byId(const SeasonId('season')))!
          .copyWith(closedOn: day(10)),
    );

    await expectLater(
      planSession(
        title: 'Posture',
        date: day(12),
        audience: Audience.adults,
        groupId: const GroupId('g1'),
      ),
      throwsA(
        isA<InvariantViolation>().having(
          (e) => e.code,
          'code',
          InvariantCode.seasonClosed,
        ),
      ),
    );
    expect(await world.plannedSessions.getAll(), isEmpty);
  });
}
