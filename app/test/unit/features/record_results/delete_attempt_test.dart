import 'package:billard_cfa/entities/exercise_result/data/in_memory_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/delete_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

const _session = SessionId('x1');

class Fixture {
  Fixture(this.world, {AttemptRepository? attempts})
    : delete = DeleteAttempt(attempts ?? world.attempts);

  final DomainWorld world;
  final DeleteAttempt delete;

  Future<Result<void>> call(String attempt, {String session = 'x1'}) =>
      delete(sessionId: SessionId(session), attemptId: AttemptId(attempt));

  /// Le rang dérivé de chaque passage restant (rien n'est stocké).
  Future<Map<String, int>> ranks() async => {
    for (final entry in passRanks(await world.attempts.all()).entries)
      entry.key.value: entry.value,
  };
}

/// Séance `x1` (jour 1) : `s1` a deux passages sur `a 1` (`a1`, `a2`) et un
/// sur `a 2` (`a3`) ; `s2` a un passage sur `a 1` dans la séance `x2`.
Future<Fixture> fixture({AttemptRepository? attempts}) async {
  final world = DomainWorld();
  await world.seedClub(studentNames: ['s1', 's2']);
  await world.session(present: {'s1', 's2'});
  await world.session(id: 'x2', dayOfMonth: 2, present: {'s2'});
  final repository = attempts ?? world.attempts;
  await repository.add(attempt(ref('a', 1), potted: 2));
  await repository.add(attempt(ref('a', 1), potted: 3, id: 'a2'));
  await repository.add(attempt(ref('a', 2), potted: 3, id: 'a3'));
  await repository.add(
    attempt(ref('a', 1), potted: 3, student: 's2', session: 'x2', id: 'b1'),
  );
  return Fixture(world, attempts: attempts);
}

/// Dépôt qui compte les écritures : une suppression n'en fait aucune.
class _CountingWrites extends InMemoryAttemptRepository {
  int writes = 0;

  @override
  Future<void> add(ExerciseAttempt attempt) {
    writes++;
    return super.add(attempt);
  }

  @override
  Future<void> correct(ExerciseAttempt attempt) {
    writes++;
    return super.correct(attempt);
  }
}

void main() {
  test('deletes the pass from the session', () async {
    final f = await fixture();

    ok(await f('a1'));

    final remaining = await f.world.attempts.forSession(_session);
    expect(remaining.map((a) => a.id.value), isNot(contains('a1')));
    expect(remaining, hasLength(2));
  });

  test(
    'does not renumber the remaining passes: their rank is derived',
    () async {
      final f = await fixture();
      expect(await f.ranks(), {'a1': 1, 'a2': 2, 'a3': 1, 'b1': 1});

      ok(await f('a1'));

      // `a2` passe au rang 1 sans qu'aucun document soit réécrit (ADR 0024,
      // décision 17 : le rang n'est plus stocké).
      expect(await f.ranks(), {'a2': 1, 'a3': 1, 'b1': 1});
      expect(
        (await f.world.attempts.forSession(_session))
            .firstWhere((a) => a.id.value == 'a2'),
        attempt(ref('a', 1), potted: 3, id: 'a2'),
      );
    },
  );

  test('writes nothing but the deletion', () async {
    final repository = _CountingWrites();
    final f = await fixture(attempts: repository);
    repository.writes = 0;

    ok(await f('a1'));

    expect(repository.writes, 0);
  });

  test('leaves the other passes untouched when the last one goes', () async {
    final f = await fixture();

    ok(await f('a2'));

    expect(await f.ranks(), {'a1': 1, 'a3': 1, 'b1': 1});
  });

  test('lets a new pass be recorded in the freed slot', () async {
    final f = await fixture();
    ok(await f('a1'));
    final record = RecordAttempt(
      f.world.sessions,
      f.world.attempts,
      f.world.acquisitions,
      f.world.catalogueRepository,
      f.world.ids,
      f.world.config,
    );

    final recorded = ok(
      await record(
        sessionId: _session,
        studentId: const StudentId('s1'),
        exercise: ref('a', 1),
        potted: 4,
        total: 5,
      ),
    );

    expect(
      passRanks([
        ...await f.world.attempts.forSession(_session),
      ])[recorded.attempt.id],
      2,
    );
  });

  test('leaves the session empty when its only pass goes', () async {
    final f = await fixture();
    for (final id in ['a1', 'a2']) {
      ok(await f(id));
    }

    ok(await f('a3'));

    expect(await f.world.attempts.forSession(_session), isEmpty);
    expect(await f.ranks(), {'b1': 1});
  });

  test('refuses a pass that is not in the session', () async {
    final f = await fixture();

    final failure = err(await f('b1'));

    expect(failure, isA<NotFound>().having((n) => n.kind, 'kind', 'attempt'));
    expect(await f.world.attempts.all(), hasLength(4));
  });

  test('refuses an unknown pass', () async {
    final f = await fixture();

    expect(err(await f('nope')), isA<NotFound>());
  });
}
