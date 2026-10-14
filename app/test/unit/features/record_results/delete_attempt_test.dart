import 'package:billard_cfa/entities/exercise_result/data/in_memory_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/delete_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

const _session = SessionId('x1');

class Fixture {
  Fixture(this.world, {AttemptRepository? attempts})
    : delete = DeleteAttempt(attempts ?? world.attempts, InMemoryUnitOfWork());

  final DomainWorld world;
  final DeleteAttempt delete;

  Future<Result<void>> call(String attempt, {String session = 'x1'}) =>
      delete(sessionId: SessionId(session), attemptId: AttemptId(attempt));

  Future<Map<String, int>> passIndexes() async => {
    for (final attempt in await world.attempts.all())
      attempt.id.value: attempt.passIndex,
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
  await repository.add(attempt(ref('a', 1), potted: 3, passIndex: 2, id: 'a2'));
  await repository.add(attempt(ref('a', 2), potted: 3, id: 'a3'));
  await repository.add(
    attempt(ref('a', 1), potted: 3, student: 's2', session: 'x2', id: 'b1'),
  );
  return Fixture(world, attempts: attempts);
}

/// Dépôt dont toute réécriture échoue (après la suppression).
class _FailingRewrite extends InMemoryAttemptRepository {
  bool armed = false;

  @override
  Future<void> add(ExerciseAttempt attempt) {
    if (armed) throw StateError('écriture refusée');
    return super.add(attempt);
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
    'renumbers the remaining passes of the same student and exercise',
    () async {
      final f = await fixture();

      ok(await f('a1'));

      expect(await f.passIndexes(), {'a2': 1, 'a3': 1, 'b1': 1});
    },
  );

  test('leaves the other passes untouched when the last one goes', () async {
    final f = await fixture();

    ok(await f('a2'));

    expect(await f.passIndexes(), {'a1': 1, 'a3': 1, 'b1': 1});
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

    expect(recorded.attempt.passIndex, 2);
  });

  test('leaves the session empty when its only pass goes', () async {
    final f = await fixture();
    for (final id in ['a1', 'a2']) {
      ok(await f(id));
    }

    ok(await f('a3'));

    expect(await f.world.attempts.forSession(_session), isEmpty);
    expect(await f.passIndexes(), {'b1': 1});
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

  test('restores the pass when the renumbering fails', () async {
    final repository = _FailingRewrite();
    final f = await fixture(attempts: repository);
    repository.armed = true;

    await expectLater(f('a1'), throwsStateError);

    final ids = (await repository.forSession(_session)).map((a) => a.id.value);
    expect(ids, containsAll(['a1', 'a2', 'a3']));
    expect(
      (await repository.forSession(_session))
          .firstWhere((a) => a.id.value == 'a2')
          .passIndex,
      2,
    );
  });
}
