import 'package:billard_cfa/features/track_progress/domain/get_week_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;

  GetWeekSummary build(DateTime now) => GetWeekSummary(
    world.attempts,
    world.acquisitions,
    world.sessions,
    world.catalogueRepository,
    world.config,
    FixedClock(now),
  );

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    await world.session(id: 'x9', dayOfMonth: 9);
    await world.attempts.add(
      attempt(ref('a', 1), potted: 3, dayOfMonth: 9, session: 'x9'),
    );
    await world.session();
    await world.attempts.add(attempt(ref('a', 1), potted: 3, id: 'a2'));
  });

  test('summarises the seven days ending at the clock day', () async {
    final summary = ok(await build(DateTime(2026, 10, 12, 18))());

    expect(summary.from, day(6));
    expect(summary.passes, 1);
    expect(summary.sessions, 1);
  });

  test('follows the clock', () async {
    final summary = ok(await build(DateTime(2026, 10, 16))());

    expect(summary.passes, 0);
    expect(summary.sessions, 0);
  });
}
