import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
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

void main() {
  setUpAll(() {
    registerFallbackValue(const SessionId('x'));
    registerFallbackValue(const StudentId('s'));
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
        nextExercise: ref('a', 1),
      );
    }

    setUp(() {
      overview = _MockGetSessionOverview();
      record = _MockRecordAttempt();
    });

    RecordResultsBloc build() => RecordResultsBloc(overview, record);

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
