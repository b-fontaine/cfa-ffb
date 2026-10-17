import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/plan_next_session_cubit.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/features/review_session/presentation/bloc/session_review_bloc.dart';
import 'package:billard_cfa/features/suggest_session/domain/next_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/next_sheet_cubit.dart';
import 'package:billard_cfa/pages/session_review/presentation/session_review_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../shared/ui/pump_ui.dart';

class _MockReview extends MockBloc<SessionReviewEvent, SessionReviewState>
    implements SessionReviewBloc;

class _MockNext extends MockCubit<NextSheetState> implements NextSheetCubit;

class _MockPlan extends MockCubit<PlanNextSessionState>
    implements PlanNextSessionCubit;

void main() {
  late _MockReview reviewBloc;
  late _MockNext next;
  late _MockPlan plan;
  var back = 0;
  SheetId? plannerSheet;

  setUpAll(() {
    registerFallbackValue(const GroupId('g'));
    registerFallbackValue(Audience.children);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(<StudentId>{});
  });

  setUp(() {
    reviewBloc = _MockReview();
    next = _MockNext();
    plan = _MockPlan();
    back = 0;
    plannerSheet = null;
    when(
      () => next.load(
        groupId: any(named: 'groupId'),
        present: any(named: 'present'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => plan.plan(
        title: any(named: 'title'),
        date: any(named: 'date'),
        audience: any(named: 'audience'),
        sheetId: any(named: 'sheetId'),
        groupId: any(named: 'groupId'),
      ),
    ).thenAnswer((_) async {});
  });

  SessionReview review({List<Session> upcoming = const []}) => SessionReview(
    record: SessionRecord(
      id: const SessionId('r1'),
      groupId: const GroupId('g1'),
      seasonId: const SeasonId('s'),
      date: DateTime(2026, 10, 12),
      audience: Audience.children,
      present: {const StudentId('lea')},
    ),
    outcome: const SessionOutcome(totalPasses: 1, totalPassed: 1),
    proposedDate: DateTime(2026, 10, 19),
    group: Group(
      id: const GroupId('g1'),
      seasonId: const SeasonId('s'),
      name: 'Jeunes',
      audience: Audience.children,
    ),
    upcoming: upcoming,
  );

  final option = SheetOption(
    id: SheetId('posture-2'),
    technique: 'posture',
    techniqueRank: 1,
    title: 'Posture',
    part: 2,
    partCount: 2,
  );

  NextSheetState nextReady() => NextSheetState(
    status: NextSheetStatus.ready,
    next: NextSheet(
      audience: Audience.children,
      mainBlockId: 'posture',
      sheet: SheetSuggestion(
        option: option,
        kind: SheetSuggestionKind.nextPending,
        exerciseNumbers: const [1],
        headCovered: true,
        head: ExerciseRef(blockId: 'posture', number: 1),
      ),
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    required SessionReviewState state,
    NextSheetState? nextState,
    PlanNextSessionState? planState,
    SessionReviewState? thenEmit,
  }) async {
    whenListen(
      reviewBloc,
      thenEmit == null
          ? const Stream<SessionReviewState>.empty()
          : Stream.value(thenEmit),
      initialState: state,
    );
    whenListen(
      next,
      const Stream<NextSheetState>.empty(),
      initialState: nextState ?? const NextSheetState(),
    );
    whenListen(
      plan,
      const Stream<PlanNextSessionState>.empty(),
      initialState: planState ?? const PlanNextSessionState.idle(),
    );
    await pumpUi(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<SessionReviewBloc>.value(value: reviewBloc),
          BlocProvider<NextSheetCubit>.value(value: next),
          BlocProvider<PlanNextSessionCubit>.value(value: plan),
        ],
        child: SessionReviewPage(
          today: () => DateTime(2026, 10, 12),
          onBackToday: () => back++,
          onOpenRecord: (_) {},
          onEnterResults: (_) {},
          onOpenStudent: (_) {},
          onOpenPlanner: (sheet, _) => plannerSheet = sheet,
          onOpenPlanned: () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a loading indicator while the review loads', (
    tester,
  ) async {
    await pump(tester, state: const SessionReviewState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an unknown record is a missing page leading back to Today', (
    tester,
  ) async {
    await pump(
      tester,
      state: const SessionReviewState(
        status: SessionReviewStatus.failure,
        failure: NotFound('session', 'x'),
      ),
    );

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Back to home'));
    expect(back, 1);
  });

  testWidgets('keeps the review and warns when the labels were not saved', (
    tester,
  ) async {
    await pump(
      tester,
      state: SessionReviewState(
        status: SessionReviewStatus.ready,
        review: review(),
        tagsFailure: const NotFound('session', 'x'),
      ),
    );

    expect(
      find.text('The labels could not be saved. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Session notes'), findsOneWidget);
  });

  testWidgets('shows no label warning without a failure', (tester) async {
    await pump(
      tester,
      state: SessionReviewState(
        status: SessionReviewStatus.ready,
        review: review(),
      ),
    );

    expect(
      find.text('The labels could not be saved. Try again.'),
      findsNothing,
    );
  });

  testWidgets('loads the next sheet for the group and the present students', (
    tester,
  ) async {
    await pump(
      tester,
      state: const SessionReviewState(),
      thenEmit: SessionReviewState(
        status: SessionReviewStatus.ready,
        review: review(),
      ),
    );
    await tester.pump();

    verify(
      () => next.load(
        groupId: const GroupId('g1'),
        present: {const StudentId('lea')},
      ),
    ).called(1);
  });

  testWidgets('plans the proposed sheet at the proposed date for the group', (
    tester,
  ) async {
    await pump(
      tester,
      state: SessionReviewState(
        status: SessionReviewStatus.ready,
        review: review(),
      ),
      nextState: nextReady(),
    );

    await tester.ensureVisible(find.text('Plan'));
    await tester.tap(find.text('Plan'));

    verify(
      () => plan.plan(
        title: 'Posture, session 2/2',
        date: DateTime(2026, 10, 19),
        audience: Audience.children,
        sheetId: SheetId('posture-2'),
        groupId: const GroupId('g1'),
      ),
    ).called(1);
  });

  testWidgets('the date picker spans tomorrow to one year from today, '
      'whatever the date already chosen', (tester) async {
    await pump(
      tester,
      state: SessionReviewState(
        status: SessionReviewStatus.ready,
        review: review(),
      ),
      nextState: nextReady(),
    );

    DatePickerDialog dialog() =>
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));

    await tester.ensureVisible(find.text('Change the date'));
    await tester.tap(find.text('Change the date'));
    await tester.pumpAndSettle();
    expect(dialog().firstDate, DateTime(2026, 10, 13));
    expect(dialog().lastDate, DateTime(2027, 10, 12));
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Change the date'));
    await tester.tap(find.text('Change the date'));
    await tester.pumpAndSettle();
    expect(dialog().initialDate, DateTime(2026, 10, 20));
    expect(dialog().firstDate, DateTime(2026, 10, 13));
    expect(dialog().lastDate, DateTime(2027, 10, 12));
  });

  testWidgets('shows a session already planned instead of the button', (
    tester,
  ) async {
    await pump(
      tester,
      state: SessionReviewState(
        status: SessionReviewStatus.ready,
        review: review(
          upcoming: [
            Session(
              id: 'p1',
              title: 'Cours',
              date: DateTime(2026, 10, 20),
              audience: Audience.children,
              groupId: const GroupId('g1'),
              sheetId: SheetId('posture-2'),
            ),
          ],
        ),
      ),
      nextState: nextReady(),
    );

    expect(find.text('Already planned for Tue, Oct 20'), findsOneWidget);
    expect(find.text('Plan'), findsNothing);
  });

  testWidgets('shows the planned date once planned', (tester) async {
    await pump(
      tester,
      state: SessionReviewState(
        status: SessionReviewStatus.ready,
        review: review(),
      ),
      nextState: nextReady(),
      planState: PlanNextSessionState.planned(
        Session(
          id: 'p2',
          title: 'Posture, session 2/2',
          date: DateTime(2026, 10, 19),
          audience: Audience.children,
          groupId: const GroupId('g1'),
          sheetId: SheetId('posture-2'),
        ),
      ),
    );

    expect(find.text('Planned for Mon, Oct 19'), findsOneWidget);
  });

  testWidgets('a season refusal shows the message and opens the planner', (
    tester,
  ) async {
    await pump(
      tester,
      state: SessionReviewState(
        status: SessionReviewStatus.ready,
        review: review(),
      ),
      nextState: nextReady(),
      planState: const PlanNextSessionState.failed(
        InvariantViolation(InvariantCode.seasonOutsidePeriod),
      ),
    );

    expect(find.text('This date is outside the season.'), findsOneWidget);
    await tester.ensureVisible(find.text('Open the planner'));
    await tester.tap(find.text('Open the planner'));
    expect(plannerSheet, SheetId('posture-2'));
  });
}
