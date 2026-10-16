import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
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

  Future<void> plan(
    String id,
    int dayOfMonth, {
    GroupId? group,
    String? sheet,
  }) => world.plannedSessions.add(
    Session(
      id: id,
      title: id,
      date: day(dayOfMonth),
      audience: Audience.children,
      groupId: group,
      sheetId: sheet == null ? null : SheetId(sheet),
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

  // D1 (ADR 0016) : une saisie d'une autre séance du catalogue le même jour
  // ne vaut pas saisie de la séance planifiée.
  test(
    'ignores the record of another catalogue session the same day',
    () async {
      await plan(
        'p-demi',
        12,
        group: const GroupId('g1'),
        sheet: 'demi-bille-2',
      );
      await world.session(
        id: 'x-posture',
        dayOfMonth: 12,
        sheet: SheetId('posture-1'),
      );

      expect((await list()).single.recordId, isNull);
    },
  );

  test('links two sessions of the same day to their own records', () async {
    await plan('p-posture', 12, group: const GroupId('g1'), sheet: 'posture-1');
    await plan('p-demi', 12, group: const GroupId('g1'), sheet: 'demi-bille-2');
    await world.session(
      id: 'x-demi',
      dayOfMonth: 12,
      sheet: SheetId('demi-bille-2'),
    );

    final records = {for (final s in await list()) s.session.id: s.recordId};

    expect(records, {'p-posture': null, 'p-demi': const SessionId('x-demi')});
  });

  test(
    'links two identical sessions of the same day to the same record',
    () async {
      await plan('p1', 12, group: const GroupId('g1'), sheet: 'posture-1');
      await plan('p2', 12, group: const GroupId('g1'), sheet: 'posture-1');
      await world.session(dayOfMonth: 12, sheet: SheetId('posture-1'));

      final ids = {for (final s in await list()) s.recordId};

      expect(ids, {const SessionId('x1')});
    },
  );

  test(
    'takes a record without catalogue session for the session of the day',
    () async {
      await plan(
        'p-posture',
        12,
        group: const GroupId('g1'),
        sheet: 'posture-1',
      );
      await world.session(id: 'x-free', dayOfMonth: 12);

      expect((await list()).single.recordId, const SessionId('x-free'));
    },
  );

  test(
    'takes a record for a planned session without catalogue session',
    () async {
      await plan('p-free', 12, group: const GroupId('g1'));
      await world.session(
        id: 'x-posture',
        dayOfMonth: 12,
        sheet: SheetId('posture-1'),
      );

      expect((await list()).single.recordId, const SessionId('x-posture'));
    },
  );

  // D1 résiduel (ADR 0016, U-1) : une saisie sans séance du catalogue est
  // prise pour celle de chaque planifiée du jour, quelle que soit sa séance.
  // Ce test fige le défaut connu : l'inverser quand U-1 sera traité.
  test(
    'takes one record without catalogue session for two planned sessions',
    () async {
      await plan(
        'p-posture',
        12,
        group: const GroupId('g1'),
        sheet: 'posture-1',
      );
      await plan(
        'p-demi',
        12,
        group: const GroupId('g1'),
        sheet: 'demi-bille-2',
      );
      await world.session(id: 'x-free', dayOfMonth: 12);

      final records = {for (final s in await list()) s.session.id: s.recordId};

      expect(records, {
        'p-posture': const SessionId('x-free'),
        'p-demi': const SessionId('x-free'),
      });
    },
  );

  test(
    'takes a record with a catalogue session only for its own planned',
    () async {
      await plan(
        'p-posture',
        12,
        group: const GroupId('g1'),
        sheet: 'posture-1',
      );
      await plan(
        'p-demi',
        12,
        group: const GroupId('g1'),
        sheet: 'demi-bille-2',
      );
      await world.session(
        id: 'x-posture',
        dayOfMonth: 12,
        sheet: SheetId('posture-1'),
      );

      final records = {for (final s in await list()) s.session.id: s.recordId};

      expect(records, {
        'p-posture': const SessionId('x-posture'),
        'p-demi': null,
      });
    },
  );

  test('does not link the record of the old day to a moved session', () async {
    await world.session(
      id: 'x-old',
      dayOfMonth: 12,
      sheet: SheetId('posture-1'),
    );
    await plan('p-old', 12, group: const GroupId('g1'), sheet: 'posture-1');
    expect((await list()).single.recordId, const SessionId('x-old'));

    await world.plannedSessions.delete('p-old');
    await plan('p-new', 19, group: const GroupId('g1'), sheet: 'posture-1');

    final summary = (await list()).single;
    expect(summary.session.id, 'p-new');
    expect(summary.recordId, isNull);
    expect(await world.sessions.forGroup(const GroupId('g1')), hasLength(1));
  });

  test('is unmodifiable', () async {
    final summaries = await list();

    expect(summaries.clear, throwsUnsupportedError);
  });
}
