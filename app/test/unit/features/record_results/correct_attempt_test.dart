import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/correct_attempt.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

const _session = SessionId('x1');
const _attempt = AttemptId('a1');

class Fixture {
  Fixture(this.world)
    : correct = CorrectAttempt(world.attempts, world.catalogueRepository);

  final DomainWorld world;
  final CorrectAttempt correct;

  Future<Result<ExerciseAttempt>> call({
    SessionId session = _session,
    AttemptId attempt = _attempt,
    int potted = 4,
    int total = 5,
  }) => correct(
    sessionId: session,
    attemptId: attempt,
    potted: potted,
    total: total,
  );

  Future<ExerciseAttempt> stored() async =>
      (await world.attempts.forSession(_session)).single;
}

/// Une séance `x1` avec un passage `a1` de `s1` sur `a 1` : 2 billes sur 5.
Future<Fixture> fixture() async {
  final world = DomainWorld();
  await world.seedClub();
  await world.session();
  await world.attempts.add(attempt(ref('a', 1), potted: 2));
  return Fixture(world);
}

void main() {
  test('replaces the potted balls and the total in place', () async {
    final f = await fixture();

    final corrected = ok(await f(potted: 3, total: 6));

    expect(corrected.id, _attempt);
    expect(corrected.potted, 3);
    expect(corrected.total, 6);
    expect(await f.stored(), corrected);
  });

  test(
    'keeps the date, the pass index, the student and the exercise',
    () async {
      final f = await fixture();

      final corrected = ok(await f(potted: 3));

      expect(corrected.date, day(1));
      expect(corrected.passIndex, 1);
      expect(corrected.studentId, const StudentId('s1'));
      expect(corrected.exercise, ref('a', 1));
      expect(corrected.sessionId, _session);
    },
  );

  test('refuses a pass that is not in the session', () async {
    final f = await fixture();
    await f.world.session(id: 'x2', dayOfMonth: 2);

    final failure = err(await f(session: const SessionId('x2')));

    expect(failure, isA<NotFound>().having((n) => n.kind, 'kind', 'attempt'));
    expect((await f.stored()).potted, 2);
  });

  test('refuses an unknown pass', () async {
    final f = await fixture();

    final failure = err(await f(attempt: const AttemptId('nope')));

    expect(failure, isA<NotFound>().having((n) => n.kind, 'kind', 'attempt'));
  });

  test('refuses a total below the attempts of the sheet', () async {
    final f = await fixture();

    expect(codeOf(await f(potted: 3, total: 4)), InvariantCode.totalBelowSheet);
    expect((await f.stored()).potted, 2);
  });

  test('refuses more potted balls than the total', () async {
    final f = await fixture();

    expect(codeOf(await f(potted: 6)), InvariantCode.pottedExceedsTotal);
    expect((await f.stored()).potted, 2);
  });

  test('accepts the attempts of the sheet as the total', () async {
    final f = await fixture();

    expect(ok(await f(potted: 1)).total, 5);
  });

  test('accepts every ball potted, and none', () async {
    final f = await fixture();

    expect(ok(await f(potted: 5)).potted, 5);
    expect(ok(await f(potted: 0)).potted, 0);
  });

  test('refuses a pass whose exercise left the catalogue', () async {
    final f = await fixture();
    await f.world.attempts.add(
      attempt(ref('zzz', 1), potted: 2, passIndex: 2, id: 'a2'),
    );

    expect(
      codeOf(await f(attempt: const AttemptId('a2'))),
      InvariantCode.unknownExercise,
    );
  });
}
