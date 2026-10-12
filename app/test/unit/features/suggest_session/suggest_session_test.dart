import 'package:billard_cfa/features/suggest_session/domain/suggest_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  final config = RulesConfig(passesRequired: 1);

  Future<(DomainWorld, SuggestSession)> start({
    Audience audience = Audience.adults,
  }) async {
    final world = DomainWorld(config: config);
    await world.seedClub(studentNames: ['s1', 's2'], audience: audience);
    return (
      world,
      SuggestSession(
        world.groups,
        world.sessions,
        world.attempts,
        world.catalogueRepository,
        world.config,
      ),
    );
  }

  test('refuses an unknown group', () async {
    final (_, suggest) = await start();

    final result = await suggest(
      groupId: const GroupId('nope'),
      expectedStudents: {const StudentId('s1')},
    );

    expect(
      err(result),
      isA<NotFound>()
          .having((n) => n.kind, 'kind', 'group')
          .having((n) => n.id, 'id', 'nope'),
    );
  });

  test('refuses an empty list of expected students', () async {
    final (_, suggest) = await start();

    final result = await suggest(
      groupId: const GroupId('g1'),
      expectedStudents: {},
    );

    expect(codeOf(result), InvariantCode.noStudents);
  });

  test('plans from the stored passes of the expected students', () async {
    final (world, suggest) = await start();
    await world.attempts.add(attempt(ref('a', 1), potted: 3, id: 'p1'));
    await world.attempts.add(attempt(ref('a', 2), potted: 3, id: 'p2'));
    await world.attempts.add(attempt(ref('a', 3), potted: 3, id: 'p3'));
    await world.attempts.add(
      attempt(ref('a', 3), potted: 1, dayOfMonth: 2, id: 'p4'),
    );

    final plan = ok(
      await suggest(
        groupId: const GroupId('g1'),
        expectedStudents: {const StudentId('s1'), const StudentId('s2')},
      ),
    );

    expect(plan.durationMinutes, 120);
    expect(plan.mainBlockId, 'a');
    expect(plan.exercises.first, ref('a', 1));
  });

  test('recalls a stale notion using the group sessions', () async {
    final (world, suggest) = await start();
    for (var n = 1; n <= 3; n++) {
      await world.attempts.add(attempt(ref('a', n), potted: 3, id: 'p$n'));
    }
    for (var d = 2; d <= 5; d++) {
      await world.session(id: 'x$d', dayOfMonth: d);
    }

    final plan = ok(
      await suggest(
        groupId: const GroupId('g1'),
        expectedStudents: {const StudentId('s1')},
      ),
    );

    expect(plan.mainBlockId, 'b');
    expect(plan.recallBlockId, 'a');
  });

  test('plans 90 minutes for a children group', () async {
    final (_, suggest) = await start(audience: Audience.children);

    final plan = ok(
      await suggest(
        groupId: const GroupId('g1'),
        expectedStudents: {const StudentId('s1')},
      ),
    );

    expect(plan.durationMinutes, 90);
    expect(plan.recallBlockId, isNull);
  });
}
