import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_recall.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late SuggestRecall suggest;
  const student = StudentId('s1');

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    suggest = SuggestRecall(
      world.students,
      world.sessions,
      world.attempts,
      world.catalogueRepository,
      world.config,
    );
  });

  /// Les trois exercices du bloc `a` validés (cinq passages réussis chacun).
  Future<void> validateBlockA() async {
    for (var n = 1; n <= 3; n++) {
      for (var i = 0; i < 5; i++) {
        await world.attempts.add(
          attempt(ref('a', n), potted: 4, id: 'v$n$i', dayOfMonth: 2 + i),
        );
      }
    }
  }

  test('suggests nothing for a new student', () async {
    expect(ok(await suggest(student)), isNull);
  });

  test('does not recall the block being taught', () async {
    await world.attempts.add(attempt(ref('a', 1), potted: 0, id: 'p1'));

    expect(ok(await suggest(student)), isNull);
  });

  test('suggests nothing when the earlier block is still fresh', () async {
    await validateBlockA();
    await world.attempts.add(
      attempt(ref('b', 1), potted: 1, id: 'b1', dayOfMonth: 20),
    );

    expect(ok(await suggest(student)), isNull);
  });

  test('recalls an earlier block whose last pass failed', () async {
    await validateBlockA();
    await world.attempts.add(
      attempt(ref('a', 2), potted: 0, id: 'late', dayOfMonth: 12),
    );

    final advice = ok(await suggest(student));

    expect(advice, isNotNull);
    expect(advice!.blockId, 'a');
    expect(advice.blockTitle, 'Bloc a');
    expect(advice.exercise, ref('a', 2));
    expect(advice.reason, RecallReason.groupFailure);
  });

  test('recalls a block left alone for several sessions', () async {
    await validateBlockA();
    for (var i = 0; i < 4; i++) {
      await world.session(id: 'g$i', dayOfMonth: 10 + i);
    }

    final advice = ok(await suggest(student));

    expect(advice!.blockId, 'a');
    expect(advice.reason, RecallReason.stale);
  });

  test('refuses an unknown student', () async {
    final result = await suggest(const StudentId('nope'));

    expect(err(result), isA<NotFound>());
  });
}
