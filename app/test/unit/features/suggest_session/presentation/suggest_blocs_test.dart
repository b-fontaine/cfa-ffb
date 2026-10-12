import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/get_exercise_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/recall_advice.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_recall.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_session.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/exercise_sheet_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/student_recall_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/suggested_session_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/default_session_shapes.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixtures.dart';

class _MockSuggestSession extends Mock implements SuggestSession;

class _MockGetExerciseSheet extends Mock implements GetExerciseSheet;

class _MockSuggestRecall extends Mock implements SuggestRecall;

void main() {
  final block1 = block('a', 1);
  ExerciseSheet sheetOf(int number) => ExerciseSheet(
    block: block1,
    spec: ExerciseSpec(ref: ref('a', number), rate: rate()),
  );

  setUpAll(() => registerFallbackValue(ref('a', 1)));

  group('SuggestedSessionBloc', () {
    late _MockSuggestSession suggest;
    late _MockGetExerciseSheet getSheet;
    const group = GroupId('g1');
    const students = {StudentId('s1')};

    SessionPlan plan({bool withRecall = false}) => SessionPlan(
      audience: Audience.adults,
      durationMinutes: 120,
      mainBlockId: 'a',
      exercises: [ref('a', 1), ref('a', 2)],
      phases: defaultSessionShapes[Audience.adults]!.phases,
      maxPassesPerExercise: 2,
      recallBlockId: withRecall ? 'b' : null,
      recallExercise: withRecall ? ref('b', 1) : null,
      recallReason: withRecall ? RecallReason.stale : null,
    );

    setUp(() {
      suggest = _MockSuggestSession();
      getSheet = _MockGetExerciseSheet();
    });

    SuggestedSessionBloc build() => SuggestedSessionBloc(suggest, getSheet);

    const event = SuggestedSessionEvent.requested(
      groupId: group,
      expectedStudents: students,
    );

    blocTest<SuggestedSessionBloc, SuggestedSessionState>(
      'gives the plan with the sheet of every exercise and of the recall',
      build: () {
        when(() => suggest(groupId: group, expectedStudents: students))
            .thenAnswer((_) async => Ok(plan(withRecall: true)));
        when(() => getSheet(ref('a', 1)))
            .thenAnswer((_) async => Ok(sheetOf(1)));
        when(() => getSheet(ref('a', 2)))
            .thenAnswer((_) async => Ok(sheetOf(2)));
        when(() => getSheet(ref('b', 1)))
            .thenAnswer((_) async => Ok(sheetOf(3)));
        return build();
      },
      act: (bloc) => bloc.add(event),
      expect: () => [
        const SuggestedSessionState(status: SuggestedStatus.loading),
        SuggestedSessionState(
          status: SuggestedStatus.ready,
          groupId: group,
          plan: plan(withRecall: true),
          exercises: [sheetOf(1), sheetOf(2)],
          recall: sheetOf(3),
        ),
      ],
    );

    blocTest<SuggestedSessionBloc, SuggestedSessionState>(
      'has no recall sheet without a recall exercise',
      build: () {
        when(() => suggest(groupId: group, expectedStudents: students))
            .thenAnswer((_) async => Ok(plan()));
        when(() => getSheet(any())).thenAnswer((_) async => Ok(sheetOf(1)));
        return build();
      },
      act: (bloc) => bloc.add(event),
      verify: (bloc) {
        expect(bloc.state.recall, isNull);
        expect(bloc.state.exercises, hasLength(2));
      },
    );

    blocTest<SuggestedSessionBloc, SuggestedSessionState>(
      'reports nothing to teach',
      build: () {
        when(() => suggest(groupId: group, expectedStudents: students))
            .thenAnswer(
              (_) async =>
                  const Err(InvariantViolation(InvariantCode.nothingToTeach)),
            );
        return build();
      },
      act: (bloc) => bloc.add(event),
      expect: () => [
        const SuggestedSessionState(status: SuggestedStatus.loading),
        const SuggestedSessionState(
          status: SuggestedStatus.failure,
          failure: InvariantViolation(InvariantCode.nothingToTeach),
        ),
      ],
    );

    blocTest<SuggestedSessionBloc, SuggestedSessionState>(
      'reports an exercise sheet that cannot be read',
      build: () {
        when(() => suggest(groupId: group, expectedStudents: students))
            .thenAnswer((_) async => Ok(plan()));
        when(() => getSheet(any())).thenAnswer(
          (_) async =>
              const Err(InvariantViolation(InvariantCode.unknownExercise)),
        );
        return build();
      },
      act: (bloc) => bloc.add(event),
      verify: (bloc) => expect(bloc.state.status, SuggestedStatus.failure),
    );

    blocTest<SuggestedSessionBloc, SuggestedSessionState>(
      'reports a recall sheet that cannot be read',
      build: () {
        when(() => suggest(groupId: group, expectedStudents: students))
            .thenAnswer((_) async => Ok(plan(withRecall: true)));
        when(() => getSheet(ref('a', 1)))
            .thenAnswer((_) async => Ok(sheetOf(1)));
        when(() => getSheet(ref('a', 2)))
            .thenAnswer((_) async => Ok(sheetOf(2)));
        when(() => getSheet(ref('b', 1))).thenAnswer(
          (_) async =>
              const Err(InvariantViolation(InvariantCode.unknownExercise)),
        );
        return build();
      },
      act: (bloc) => bloc.add(event),
      verify: (bloc) {
        expect(bloc.state.status, SuggestedStatus.failure);
        expect(bloc.state.plan, isNull);
      },
    );
  });

  group('ExerciseSheetBloc', () {
    late _MockGetExerciseSheet getSheet;

    setUp(() => getSheet = _MockGetExerciseSheet());

    blocTest<ExerciseSheetBloc, ExerciseSheetState>(
      'loads the sheet',
      build: () {
        when(() => getSheet(ref('a', 1)))
            .thenAnswer((_) async => Ok(sheetOf(1)));
        return ExerciseSheetBloc(getSheet);
      },
      act: (bloc) =>
          bloc.add(ExerciseSheetEvent.started(exercise: ref('a', 1))),
      expect: () => [
        const ExerciseSheetState(),
        ExerciseSheetState(
          status: ExerciseSheetStatus.ready,
          sheet: sheetOf(1),
        ),
      ],
    );

    blocTest<ExerciseSheetBloc, ExerciseSheetState>(
      'reports an unknown exercise',
      build: () {
        when(() => getSheet(ref('a', 9))).thenAnswer(
          (_) async =>
              const Err(InvariantViolation(InvariantCode.unknownExercise)),
        );
        return ExerciseSheetBloc(getSheet);
      },
      act: (bloc) =>
          bloc.add(ExerciseSheetEvent.started(exercise: ref('a', 9))),
      expect: () => [
        const ExerciseSheetState(),
        const ExerciseSheetState(
          status: ExerciseSheetStatus.failure,
          failure: InvariantViolation(InvariantCode.unknownExercise),
        ),
      ],
    );
  });

  group('StudentRecallBloc', () {
    late _MockSuggestRecall suggest;
    const id = StudentId('s1');
    final advice = RecallAdvice(
      blockId: 'a',
      blockTitle: 'Bloc a',
      exercise: ref('a', 2),
      reason: RecallReason.lastFailed,
    );

    setUp(() => suggest = _MockSuggestRecall());

    blocTest<StudentRecallBloc, StudentRecallState>(
      'gives the notion to recall',
      build: () {
        when(() => suggest(id)).thenAnswer((_) async => Ok(advice));
        return StudentRecallBloc(suggest);
      },
      act: (bloc) => bloc.add(const StudentRecallEvent.started(studentId: id)),
      expect: () => [
        const StudentRecallState(),
        StudentRecallState(status: RecallStatus.ready, advice: advice),
      ],
    );

    blocTest<StudentRecallBloc, StudentRecallState>(
      'is ready without advice when nothing needs recalling',
      build: () {
        when(() => suggest(id)).thenAnswer((_) async => const Ok(null));
        return StudentRecallBloc(suggest);
      },
      act: (bloc) => bloc.add(const StudentRecallEvent.started(studentId: id)),
      expect: () => [
        const StudentRecallState(),
        const StudentRecallState(status: RecallStatus.ready),
      ],
    );

    blocTest<StudentRecallBloc, StudentRecallState>(
      'reports a failure',
      build: () {
        when(() => suggest(id))
            .thenAnswer((_) async => const Err(NotFound('student', 's1')));
        return StudentRecallBloc(suggest);
      },
      act: (bloc) => bloc.add(const StudentRecallEvent.started(studentId: id)),
      expect: () => [
        const StudentRecallState(),
        const StudentRecallState(
          status: RecallStatus.failure,
          failure: NotFound('student', 's1'),
        ),
      ],
    );
  });
}
