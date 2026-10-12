import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

const _student = StudentId('s1');
const _session = SessionId('x1');

class Fixture {
  Fixture(this.world)
    : recordAttempt = RecordAttempt(
        world.sessions,
        world.attempts,
        world.catalogueRepository,
        world.ids,
        world.config,
      );

  final DomainWorld world;
  final RecordAttempt recordAttempt;

  Future<Result<RecordedAttempt>> record(
    int potted, {
    int total = 5,
    String session = 'x1',
    String student = 's1',
    int exerciseNumber = 1,
    String block = 'a',
  }) => recordAttempt(
    sessionId: SessionId(session),
    studentId: StudentId(student),
    exercise: ref(block, exerciseNumber),
    potted: potted,
    total: total,
  );
}

Future<Fixture> fixture({
  RulesConfig? config,
  int sessions = 1,
  Set<String> present = const {'s1'},
}) async {
  final world = DomainWorld(config: config);
  await world.seedClub(studentNames: ['s1', 's2']);
  for (var i = 1; i <= sessions; i++) {
    await world.session(id: 'x$i', dayOfMonth: i, present: present);
  }
  return Fixture(world);
}

void main() {
  test('records a passed pass and describes it', () async {
    final f = await fixture();

    final recorded = ok(
      await f.recordAttempt(
        sessionId: _session,
        studentId: _student,
        exercise: ref('a', 1),
        potted: 3,
        total: 5,
      ),
    );

    expect(recorded.passed, isTrue);
    expect(recorded.attempt.passIndex, 1);
    expect(recorded.attempt.date, day(1));
    expect(recorded.attempt.id.value, 'id-1');
    expect(recorded.result.status, ExerciseStatus.inProgress);
    expect(recorded.result.passedCount, 1);
    expect(recorded.justValidated, isFalse);
    expect(recorded.nextExercise, ref('a', 1));
    expect(await f.world.attempts.forStudent(_student), hasLength(1));
  });

  test('records a missed pass', () async {
    final f = await fixture();

    final recorded = ok(
      await f.recordAttempt(
        sessionId: _session,
        studentId: _student,
        exercise: ref('a', 1),
        potted: 2,
        total: 5,
      ),
    );

    expect(recorded.passed, isFalse);
    expect(recorded.result.passedCount, 0);
    expect(recorded.result.consecutiveFailures, 1);
  });

  test('numbers passes within the session 1 then 2', () async {
    final f = await fixture();

    final first = ok(
      await f.recordAttempt(
        sessionId: _session,
        studentId: _student,
        exercise: ref('a', 1),
        potted: 3,
        total: 5,
      ),
    );
    final second = ok(
      await f.recordAttempt(
        sessionId: _session,
        studentId: _student,
        exercise: ref('a', 1),
        potted: 3,
        total: 5,
      ),
    );

    expect(first.attempt.passIndex, 1);
    expect(second.attempt.passIndex, 2);
  });

  test('refuses a third pass on the same exercise in a session', () async {
    final f = await fixture();
    await f.record(3);
    await f.record(3);

    final third = await f.record(3);

    expect(codeOf(third), InvariantCode.passesLimitReached);
    expect(await f.world.attempts.forStudent(_student), hasLength(2));
  });

  test('allows a pass on another exercise after two passes', () async {
    final f = await fixture();
    await f.record(3);
    await f.record(3);

    final other = await f.record(3, exerciseNumber: 2);

    expect(other, isA<Ok<RecordedAttempt>>());
  });

  test('allows two passes for another student', () async {
    final f = await fixture(present: {'s1', 's2'});
    await f.record(3);
    await f.record(3);

    expect(await f.record(3, student: 's2'), isA<Ok<RecordedAttempt>>());
  });

  test('follows a configured limit of 1 pass per session', () async {
    final f = await fixture(
      config: RulesConfig(maxPassesPerExercisePerSession: 1),
    );
    await f.record(3);

    expect(codeOf(await f.record(3)), InvariantCode.passesLimitReached);
  });

  test(
    'refuses when a lowered limit is already exceeded by stored passes',
    () async {
      final f = await fixture(
        config: RulesConfig(maxPassesPerExercisePerSession: 1),
      );
      await f.world.attempts.add(attempt(ref('a', 1), potted: 3, id: 'old1'));
      await f.world.attempts.add(
        attempt(ref('a', 1), potted: 3, passIndex: 2, id: 'old2'),
      );

      expect(codeOf(await f.record(3)), InvariantCode.passesLimitReached);
    },
  );

  test('refuses more potted than total and stores nothing', () async {
    final f = await fixture();

    final result = await f.record(6);

    expect(codeOf(result), InvariantCode.pottedExceedsTotal);
    expect(await f.world.attempts.forStudent(_student), isEmpty);
  });

  test('refuses an unknown session', () async {
    final f = await fixture();

    final failure = err(await f.record(3, session: 'nope'));

    expect(failure, isA<NotFound>().having((n) => n.kind, 'kind', 'session'));
  });

  test('refuses a student who is not present', () async {
    final f = await fixture();

    expect(
      codeOf(await f.record(3, student: 's2')),
      InvariantCode.studentNotPresent,
    );
  });

  test('refuses an exercise outside the catalogue', () async {
    final f = await fixture();

    expect(
      codeOf(await f.record(3, exerciseNumber: 4)),
      InvariantCode.unknownExercise,
    );
    expect(
      codeOf(await f.record(3, block: 'zzz')),
      InvariantCode.unknownExercise,
    );
  });

  test('refuses a total below the attempts of the sheet', () async {
    final f = await fixture();

    expect(codeOf(await f.record(4, total: 4)), InvariantCode.totalBelowSheet);
    expect(await f.world.attempts.forStudent(_student), isEmpty);
  });

  test('accepts the attempts of the sheet as the minimum total', () async {
    final f = await fixture();

    expect(ok(await f.record(3)).passed, isTrue);
  });

  test(
    'evaluates a total different from the catalogue by proportion',
    () async {
      final f = await fixture();

      final recorded = ok(
        await f.recordAttempt(
          sessionId: _session,
          studentId: _student,
          exercise: ref('a', 1),
          potted: 6,
          total: 10,
        ),
      );

      expect(recorded.passed, isTrue);
    },
  );

  group('validation after several passed passes', () {
    Future<List<RecordedAttempt>> recordPasses(int count) async {
      final f = await fixture(sessions: 3);
      final recorded = <RecordedAttempt>[];
      for (var i = 0; i < count; i++) {
        final session = 'x${i ~/ 2 + 1}';
        recorded.add(ok(await f.record(3, session: session)));
      }
      return recorded;
    }

    test('4 passed passes: still in progress, not just validated', () async {
      final last = (await recordPasses(4)).last;

      expect(last.result.status, ExerciseStatus.inProgress);
      expect(last.justValidated, isFalse);
      expect(last.nextExercise, ref('a', 1));
    });

    test(
      '5 passed passes: validated by this pass, next exercise moves on',
      () async {
        final last = (await recordPasses(5)).last;

        expect(last.result.status, ExerciseStatus.validated);
        expect(last.justValidated, isTrue);
        expect(last.nextExercise, ref('a', 2));
      },
    );

    test(
      '6 passed passes: stays validated, no longer "just validated"',
      () async {
        final last = (await recordPasses(6)).last;

        expect(last.result.isValidated, isTrue);
        expect(last.justValidated, isFalse);
      },
    );

    test('a single pass validates when 1 pass is configured', () async {
      final f = await fixture(config: RulesConfig(passesRequired: 1));

      final recorded = ok(await f.record(3));

      expect(recorded.justValidated, isTrue);
      expect(recorded.nextExercise, ref('a', 2));
    });
  });

  test('raises the attention alert on the third consecutive failure', () async {
    final f = await fixture(sessions: 2);
    await f.record(2);
    await f.record(2);

    final third = ok(await f.record(2, session: 'x2'));

    expect(third.result.alert, AlertLevel.attention);
  });

  test('reports a finished level with no next exercise', () async {
    final world = DomainWorld(
      catalogue: buildCatalogue([block('a', 1, exercises: 1)]),
      config: RulesConfig(passesRequired: 1),
    );
    await world.seedClub();
    await world.session();
    final f = Fixture(world);

    final recorded = ok(await f.record(3));

    expect(recorded.nextExercise, isNull);
  });
}
