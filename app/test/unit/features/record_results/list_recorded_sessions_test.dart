import 'package:billard_cfa/features/record_results/domain/list_recorded_sessions.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_session_summary.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

Future<(DomainWorld, ListRecordedSessions)> fixture() async {
  final world = DomainWorld();
  await world.seedClub(studentNames: ['s1', 's2']);
  return (
    world,
    ListRecordedSessions(
      world.sessions,
      world.groups,
      world.attempts,
      world.catalogueRepository,
      world.sheets,
    ),
  );
}

void main() {
  test('lists nothing when no session was recorded', () async {
    final (_, list) = await fixture();

    expect(ok(await list()), isEmpty);
  });

  test('describes a session: group, block, presence and passes', () async {
    final (world, list) = await fixture();
    await world.session(dayOfMonth: 3, present: {'s1', 's2'}, main: 'a');
    await world.attempts.add(attempt(ref('a', 1), potted: 3));
    await world.attempts.add(attempt(ref('a', 1), potted: 2, id: 'a2'));

    final summaries = ok(await list());

    expect(summaries, hasLength(1));
    final summary = summaries.single;
    expect(summary.session.id, const SessionId('x1'));
    expect(summary.groupName, 'Groupe');
    expect(summary.mainBlock?.id, 'a');
    expect(summary.presentCount, 2);
    expect(summary.attemptCount, 2);
  });

  test('has no block when the session was opened without one', () async {
    final (world, list) = await fixture();
    await world.session();

    expect(ok(await list()).single.mainBlock, isNull);
  });

  test('names the catalogue session of each recorded session', () async {
    final (world, list) = await fixture();
    await world.session(id: 'known', sheet: SheetId('demi-bille-2'));
    await world.session(
      id: 'gone',
      dayOfMonth: 2,
      sheet: SheetId('inconnue-9'),
    );
    await world.session(id: 'none', dayOfMonth: 3);

    final sheets = {
      for (final summary in ok(await list()))
        summary.session.id.value: summary.sheet?.id.value,
    };

    expect(sheets, {'known': 'demi-bille-2', 'gone': null, 'none': null});
  });

  test('orders the newest session first, then the latest recorded', () async {
    final (world, list) = await fixture();
    await world.session(id: 'old');
    await world.session(id: 'new', dayOfMonth: 9);
    await world.session(id: 'mid-first', dayOfMonth: 5);
    await world.session(id: 'mid-second', dayOfMonth: 5);

    final ids = [
      for (final summary in ok(await list())) summary.session.id.value,
    ];

    expect(ids, ['new', 'mid-second', 'mid-first', 'old']);
  });

  test('counts only the passes of each session', () async {
    final (world, list) = await fixture();
    await world.session();
    await world.session(id: 'x2', dayOfMonth: 2);
    await world.attempts.add(attempt(ref('a', 1), potted: 3));
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, session: 'x2', dayOfMonth: 2, id: 'a2'),
    );
    await world.attempts.add(
      attempt(ref('a', 2), potted: 3, session: 'x2', dayOfMonth: 2, id: 'a3'),
    );

    final counts = {
      for (final summary in ok(await list()))
        summary.session.id.value: summary.attemptCount,
    };

    expect(counts, {'x2': 2, 'x1': 1});
  });

  test('names an unknown group with an empty string', () async {
    final (world, list) = await fixture();
    await world.session();
    await world.groups.delete(const GroupId('g1'));

    expect(ok(await list()).single.groupName, '');
  });

  test('is a value: two equal summaries compare equal', () async {
    final (world, list) = await fixture();
    await world.session();

    final first = ok(await list()).single;
    final second = ok(await list()).single;

    expect(first, equals(second));
    expect(first, isA<RecordedSessionSummary>());
  });
}
