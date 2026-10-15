import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/record_results/domain/correct_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/delete_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/get_session_overview.dart';
import 'package:billard_cfa/features/record_results/domain/open_or_resume_session.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/session_overview.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/open_session_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixtures.dart';

class _MockOpenOrResume extends Mock implements OpenOrResumeSession;

class _MockGetSessionOverview extends Mock implements GetSessionOverview;

class _MockRecordAttempt extends Mock implements RecordAttempt;

class _MockCorrectAttempt extends Mock implements CorrectAttempt;

class _MockDeleteAttempt extends Mock implements DeleteAttempt;

void main() {
  setUpAll(() {
    registerFallbackValue(const SessionId('x'));
    registerFallbackValue(const StudentId('s'));
    registerFallbackValue(const AttemptId('a'));
    registerFallbackValue(ref('a', 1));
  });

  group('OpenSessionBloc', () {
    late _MockOpenOrResume open;
    const group = GroupId('g1');
    final date = DateTime(2026, 10, 12);
    final record = SessionRecord(
      id: const SessionId('x1'),
      groupId: group,
      seasonId: const SeasonId('season'),
      date: date,
      audience: Audience.children,
      present: {const StudentId('s1')},
      mainBlockId: 'a',
    );
    setUp(() => open = _MockOpenOrResume());

    blocTest<OpenSessionBloc, OpenSessionState>(
      'opens the session with the chosen blocks',
      build: () {
        when(
          () => open(
            groupId: group,
            date: date,
            present: {const StudentId('s1')},
            mainBlockId: 'a',
            recallBlockId: 'b',
          ),
        ).thenAnswer((_) async => Ok(record));
        return OpenSessionBloc(open);
      },
      act: (bloc) => bloc.add(
        OpenSessionEvent.requested(
          groupId: group,
          date: date,
          present: {const StudentId('s1')},
          mainBlockId: 'a',
          recallBlockId: 'b',
        ),
      ),
      expect: () => [
        const OpenSessionState(status: OpenSessionStatus.opening),
        OpenSessionState(status: OpenSessionStatus.opened, session: record),
      ],
    );

    blocTest<OpenSessionBloc, OpenSessionState>(
      'reports a refused session',
      build: () {
        when(
          () => open(
            groupId: group,
            date: date,
            present: {const StudentId('s1')},
          ),
        ).thenAnswer(
          (_) async =>
              const Err(InvariantViolation(InvariantCode.seasonOutsidePeriod)),
        );
        return OpenSessionBloc(open);
      },
      act: (bloc) => bloc.add(
        OpenSessionEvent.requested(
          groupId: group,
          date: date,
          present: {const StudentId('s1')},
        ),
      ),
      expect: () => [
        const OpenSessionState(status: OpenSessionStatus.opening),
        const OpenSessionState(
          status: OpenSessionStatus.failure,
          failure: InvariantViolation(InvariantCode.seasonOutsidePeriod),
        ),
      ],
    );
  });

  group('RecordResultsBloc', () {
    late _MockGetSessionOverview overview;
    late _MockRecordAttempt record;
    const sessionId = SessionId('x1');
    const studentId = StudentId('s1');
    final lea = Student.enroll(
      id: studentId,
      firstName: 'Léa',
      audience: Audience.children,
      since: DateTime(2026, 9),
    );

    SessionOverview overviewOf({
      String? main,
      List<ExerciseAttempt> attempts = const [],
    }) => SessionOverview(
      session: SessionRecord(
        id: sessionId,
        groupId: const GroupId('g1'),
        seasonId: const SeasonId('season'),
        date: day(12),
        audience: Audience.children,
        present: {studentId},
        mainBlockId: main,
      ),
      groupName: 'Jeunes',
      students: [lea],
      attempts: attempts,
      catalogue: buildCatalogue(),
      maxPassesPerExercise: 2,
      passesRequired: 5,
    );

    RecordedAttempt recordedOf(ExerciseAttempt attempt) {
      final result = ExerciseResult.derive(
        studentId: studentId,
        exercise: attempt.exercise,
        rate: rate(),
        attempts: [attempt],
        config: RulesConfig(),
      );
      return RecordedAttempt(
        attempt: attempt,
        result: result,
        passed: true,
        justValidated: false,
        resumedFromPlacement: false,
        nextExercise: ref('a', 1),
      );
    }

    late _MockCorrectAttempt correct;
    late _MockDeleteAttempt delete;

    setUp(() {
      overview = _MockGetSessionOverview();
      record = _MockRecordAttempt();
      correct = _MockCorrectAttempt();
      delete = _MockDeleteAttempt();
    });

    RecordResultsBloc build() =>
        RecordResultsBloc(overview, record, correct, delete);

    blocTest<RecordResultsBloc, RecordResultsState>(
      'starts on the first exercise of the catalogue',
      build: () {
        when(() => overview(sessionId))
            .thenAnswer((_) async => Ok(overviewOf()));
        return build();
      },
      act: (bloc) =>
          bloc.add(const RecordResultsEvent.started(sessionId: sessionId)),
      expect: () => [
        const RecordResultsState(),
        RecordResultsState(
          status: RecordStatus.ready,
          overview: overviewOf(),
          exercise: ref('a', 1),
        ),
      ],
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'starts on the first exercise of the main block',
      build: () {
        when(() => overview(sessionId))
            .thenAnswer((_) async => Ok(overviewOf(main: 'b')));
        return build();
      },
      act: (bloc) =>
          bloc.add(const RecordResultsEvent.started(sessionId: sessionId)),
      verify: (bloc) => expect(bloc.state.exercise, ref('b', 1)),
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'starts on the exercise of the main block asked for',
      build: () {
        when(() => overview(sessionId))
            .thenAnswer((_) async => Ok(overviewOf(main: 'b')));
        return build();
      },
      act: (bloc) => bloc.add(
        const RecordResultsEvent.started(
          sessionId: sessionId,
          initialExercise: 2,
        ),
      ),
      verify: (bloc) => expect(bloc.state.exercise, ref('b', 2)),
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'ignores an exercise number the main block does not have',
      build: () {
        when(() => overview(sessionId))
            .thenAnswer((_) async => Ok(overviewOf(main: 'b')));
        return build();
      },
      act: (bloc) => bloc.add(
        const RecordResultsEvent.started(
          sessionId: sessionId,
          initialExercise: 9,
        ),
      ),
      verify: (bloc) => expect(bloc.state.exercise, ref('b', 1)),
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'preselects an exercise of another block when it is named (recall)',
      build: () {
        when(() => overview(sessionId))
            .thenAnswer((_) async => Ok(overviewOf(main: 'b')));
        return build();
      },
      act: (bloc) => bloc.add(
        const RecordResultsEvent.started(
          sessionId: sessionId,
          initialExercise: 1,
          initialBlock: 'a',
        ),
      ),
      verify: (bloc) => expect(bloc.state.exercise, ref('a', 1)),
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'ignores an exercise number without a main block',
      build: () {
        when(() => overview(sessionId))
            .thenAnswer((_) async => Ok(overviewOf()));
        return build();
      },
      act: (bloc) => bloc.add(
        const RecordResultsEvent.started(
          sessionId: sessionId,
          initialExercise: 2,
        ),
      ),
      verify: (bloc) => expect(bloc.state.exercise, ref('a', 1)),
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'reports an unknown session',
      build: () {
        when(() => overview(sessionId))
            .thenAnswer((_) async => const Err(NotFound('session', 'x1')));
        return build();
      },
      act: (bloc) =>
          bloc.add(const RecordResultsEvent.started(sessionId: sessionId)),
      expect: () => [
        const RecordResultsState(),
        const RecordResultsState(
          status: RecordStatus.failure,
          failure: NotFound('session', 'x1'),
        ),
      ],
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'changing the exercise clears the feedback',
      build: build,
      seed: () => RecordResultsState(
        status: RecordStatus.ready,
        overview: overviewOf(),
        exercise: ref('a', 1),
        feedback: {studentId: recordedOf(attempt(ref('a', 1), potted: 4))},
        refused: const {
          studentId: InvariantViolation(InvariantCode.passesLimitReached),
        },
      ),
      act: (bloc) =>
          bloc.add(RecordResultsEvent.exerciseSelected(exercise: ref('b', 2))),
      expect: () => [
        RecordResultsState(
          status: RecordStatus.ready,
          overview: overviewOf(),
          exercise: ref('b', 2),
        ),
      ],
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'records a pass, refreshes the session and keeps the feedback',
      build: () {
        final pass = attempt(ref('a', 1), potted: 4);
        when(
          () => record(
            sessionId: sessionId,
            studentId: studentId,
            exercise: ref('a', 1),
            potted: 4,
            total: 5,
          ),
        ).thenAnswer((_) async => Ok(recordedOf(pass)));
        when(() => overview(sessionId))
            .thenAnswer((_) async => Ok(overviewOf(attempts: [pass])));
        return build();
      },
      seed: () => RecordResultsState(
        status: RecordStatus.ready,
        overview: overviewOf(),
        exercise: ref('a', 1),
        refused: const {
          studentId: InvariantViolation(InvariantCode.passesLimitReached),
        },
      ),
      act: (bloc) => bloc.add(
        const RecordResultsEvent.passSubmitted(
          studentId: studentId,
          potted: 4,
          total: 5,
        ),
      ),
      verify: (bloc) {
        final pass = attempt(ref('a', 1), potted: 4);
        expect(bloc.state.overview, overviewOf(attempts: [pass]));
        expect(bloc.state.feedback[studentId]?.attempt, pass);
        expect(bloc.state.refused, isEmpty);
      },
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'keeps the previous overview when the refresh fails',
      build: () {
        final pass = attempt(ref('a', 1), potted: 4);
        when(
          () => record(
            sessionId: sessionId,
            studentId: studentId,
            exercise: ref('a', 1),
            potted: 4,
            total: 5,
          ),
        ).thenAnswer((_) async => Ok(recordedOf(pass)));
        when(() => overview(sessionId))
            .thenAnswer((_) async => const Err(NotFound('session', 'x1')));
        return build();
      },
      seed: () => RecordResultsState(
        status: RecordStatus.ready,
        overview: overviewOf(),
        exercise: ref('a', 1),
      ),
      act: (bloc) => bloc.add(
        const RecordResultsEvent.passSubmitted(
          studentId: studentId,
          potted: 4,
          total: 5,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.overview, overviewOf());
        expect(bloc.state.feedback, hasLength(1));
      },
    );

    blocTest<RecordResultsBloc, RecordResultsState>(
      'shows why a pass is refused',
      build: () {
        when(
          () => record(
            sessionId: sessionId,
            studentId: studentId,
            exercise: ref('a', 1),
            potted: 4,
            total: 5,
          ),
        ).thenAnswer(
          (_) async =>
              const Err(InvariantViolation(InvariantCode.passesLimitReached)),
        );
        return build();
      },
      seed: () => RecordResultsState(
        status: RecordStatus.ready,
        overview: overviewOf(),
        exercise: ref('a', 1),
      ),
      act: (bloc) => bloc.add(
        const RecordResultsEvent.passSubmitted(
          studentId: studentId,
          potted: 4,
          total: 5,
        ),
      ),
      expect: () => [
        RecordResultsState(
          status: RecordStatus.ready,
          overview: overviewOf(),
          exercise: ref('a', 1),
          refused: const {
            studentId: InvariantViolation(InvariantCode.passesLimitReached),
          },
        ),
      ],
    );

    group('correction of a pass (ADR 0006)', () {
      final before = attempt(ref('a', 1), potted: 2);
      final after = attempt(ref('a', 1), potted: 4);
      final seeded = RecordResultsState(
        status: RecordStatus.ready,
        overview: overviewOf(attempts: [before]),
        exercise: ref('a', 1),
        feedback: {studentId: recordedOf(before)},
        refused: const {
          studentId: InvariantViolation(InvariantCode.passesLimitReached),
        },
        attemptRefused: const InvariantViolation(InvariantCode.totalBelowSheet),
      );

      blocTest<RecordResultsBloc, RecordResultsState>(
        'corrects a pass, refreshes the session and clears the feedback',
        build: () {
          when(
            () => correct(
              sessionId: sessionId,
              attemptId: const AttemptId('a1'),
              potted: 4,
              total: 5,
            ),
          ).thenAnswer((_) async => Ok(after));
          when(() => overview(sessionId))
              .thenAnswer((_) async => Ok(overviewOf(attempts: [after])));
          return build();
        },
        seed: () => seeded,
        act: (bloc) => bloc.add(
          const RecordResultsEvent.attemptCorrected(
            attemptId: AttemptId('a1'),
            potted: 4,
            total: 5,
          ),
        ),
        expect: () => [
          RecordResultsState(
            status: RecordStatus.ready,
            overview: overviewOf(attempts: [after]),
            exercise: ref('a', 1),
            attemptChange: AttemptChange.corrected(attempt: after),
          ),
        ],
      );

      blocTest<RecordResultsBloc, RecordResultsState>(
        'shows why a correction is refused and keeps the session',
        build: () {
          when(
            () => correct(
              sessionId: sessionId,
              attemptId: const AttemptId('a1'),
              potted: 4,
              total: 5,
            ),
          ).thenAnswer(
            (_) async =>
                const Err(InvariantViolation(InvariantCode.pottedExceedsTotal)),
          );
          return build();
        },
        seed: () => seeded.copyWith(
          attemptChange: AttemptChange.corrected(attempt: before),
        ),
        act: (bloc) => bloc.add(
          const RecordResultsEvent.attemptCorrected(
            attemptId: AttemptId('a1'),
            potted: 4,
            total: 5,
          ),
        ),
        expect: () => [
          seeded.copyWith(
            attemptChange: null,
            attemptRefused: const InvariantViolation(
              InvariantCode.pottedExceedsTotal,
            ),
          ),
        ],
        verify: (_) => verifyNever(() => overview(any())),
      );

      blocTest<RecordResultsBloc, RecordResultsState>(
        'deletes a pass, refreshes the session and clears the feedback',
        build: () {
          when(
            () =>
                delete(sessionId: sessionId, attemptId: const AttemptId('a1')),
          ).thenAnswer((_) async => const Ok(null));
          when(() => overview(sessionId))
              .thenAnswer((_) async => Ok(overviewOf()));
          return build();
        },
        seed: () => seeded,
        act: (bloc) => bloc.add(
          const RecordResultsEvent.attemptDeleted(attemptId: AttemptId('a1')),
        ),
        expect: () => [
          RecordResultsState(
            status: RecordStatus.ready,
            overview: overviewOf(),
            exercise: ref('a', 1),
            attemptChange: const AttemptChange.deleted(),
          ),
        ],
      );

      blocTest<RecordResultsBloc, RecordResultsState>(
        'shows why a deletion is refused',
        build: () {
          when(
            () =>
                delete(sessionId: sessionId, attemptId: const AttemptId('a1')),
          ).thenAnswer((_) async => const Err(NotFound('attempt', 'a1')));
          return build();
        },
        seed: () => seeded.copyWith(attemptRefused: null),
        act: (bloc) => bloc.add(
          const RecordResultsEvent.attemptDeleted(attemptId: AttemptId('a1')),
        ),
        expect: () => [
          seeded.copyWith(attemptRefused: const NotFound('attempt', 'a1')),
        ],
      );

      blocTest<RecordResultsBloc, RecordResultsState>(
        'a new pass clears the last change',
        build: () {
          when(
            () => record(
              sessionId: sessionId,
              studentId: studentId,
              exercise: ref('a', 1),
              potted: 4,
              total: 5,
            ),
          ).thenAnswer((_) async => Ok(recordedOf(after)));
          when(() => overview(sessionId))
              .thenAnswer((_) async => Ok(overviewOf(attempts: [after])));
          return build();
        },
        seed: () =>
            seeded.copyWith(attemptChange: const AttemptChange.deleted()),
        act: (bloc) => bloc.add(
          const RecordResultsEvent.passSubmitted(
            studentId: studentId,
            potted: 4,
            total: 5,
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.attemptChange, isNull);
          expect(bloc.state.attemptRefused, isNull);
        },
      );

      blocTest<RecordResultsBloc, RecordResultsState>(
        'ignores a change before the session is loaded',
        build: build,
        act: (bloc) => bloc
          ..add(
            const RecordResultsEvent.attemptCorrected(
              attemptId: AttemptId('a1'),
              potted: 4,
              total: 5,
            ),
          )
          ..add(
            const RecordResultsEvent.attemptDeleted(attemptId: AttemptId('a1')),
          ),
        expect: () => <RecordResultsState>[],
        verify: (_) {
          verifyNever(
            () => correct(
              sessionId: any(named: 'sessionId'),
              attemptId: any(named: 'attemptId'),
              potted: any(named: 'potted'),
              total: any(named: 'total'),
            ),
          );
          verifyNever(
            () => delete(
              sessionId: any(named: 'sessionId'),
              attemptId: any(named: 'attemptId'),
            ),
          );
        },
      );
    });

    blocTest<RecordResultsBloc, RecordResultsState>(
      'ignores a pass before the session is loaded',
      build: build,
      act: (bloc) => bloc.add(
        const RecordResultsEvent.passSubmitted(
          studentId: studentId,
          potted: 4,
          total: 5,
        ),
      ),
      expect: () => <RecordResultsState>[],
      verify: (_) => verifyNever(
        () => record(
          sessionId: any(named: 'sessionId'),
          studentId: any(named: 'studentId'),
          exercise: any(named: 'exercise'),
          potted: any(named: 'potted'),
          total: any(named: 'total'),
        ),
      ),
    );
  });
}
