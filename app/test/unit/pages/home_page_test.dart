import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/features/plan_session/domain/upcoming_sessions.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/upcoming_sessions_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_session.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_sessions_cubit.dart';
import 'package:billard_cfa/features/track_progress/domain/week_summary.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/watched_students_cubit.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/week_summary_cubit.dart';
import 'package:billard_cfa/pages/home/presentation/home_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../shared/ui/pump_ui.dart';

class _MockRunning extends MockCubit<List<RunningSession>>
    implements RunningSessionsCubit;

class _MockUpcoming extends MockCubit<UpcomingSessionsState>
    implements UpcomingSessionsCubit;

class _MockWatched extends MockCubit<WatchedStudentsState>
    implements WatchedStudentsCubit;

class _MockWeek extends MockCubit<WeekSummaryState> implements WeekSummaryCubit;

void main() {
  late _MockRunning running;
  late _MockUpcoming upcoming;
  late _MockWatched watched;
  late _MockWeek week;

  setUpAll(() => registerFallbackValue(RunKey(sheetId: SheetId('x'))));

  setUp(() {
    running = _MockRunning();
    upcoming = _MockUpcoming();
    watched = _MockWatched();
    week = _MockWeek();
    when(() => upcoming.load()).thenAnswer((_) async {});
    when(() => watched.load()).thenAnswer((_) async {});
    when(() => week.load()).thenAnswer((_) async {});
  });

  final summary = WeekSummary(
    from: DateTime(2026, 10, 6),
    to: DateTime(2026, 10, 12),
    passes: 2,
    validations: 0,
    sessions: 1,
  );

  Future<void> pump(
    WidgetTester tester, {
    List<RunningSession> runs = const [],
    UpcomingSessionsState? upcomingState,
    WatchedStudentsState? watchedState,
    WeekSummaryState? weekState,
  }) async {
    whenListen(
      running,
      const Stream<List<RunningSession>>.empty(),
      initialState: runs,
    );
    whenListen(
      upcoming,
      const Stream<UpcomingSessionsState>.empty(),
      initialState:
          upcomingState ??
          const UpcomingSessionsState(status: UpcomingStatus.ready),
    );
    whenListen(
      watched,
      const Stream<WatchedStudentsState>.empty(),
      initialState:
          watchedState ??
          const WatchedStudentsState(status: WatchedStatus.ready),
    );
    whenListen(
      week,
      const Stream<WeekSummaryState>.empty(),
      initialState:
          weekState ??
          WeekSummaryState(status: WeekStatus.ready, summary: summary),
    );
    await pumpUi(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<RunningSessionsCubit>.value(value: running),
          BlocProvider<UpcomingSessionsCubit>.value(value: upcoming),
          BlocProvider<WatchedStudentsCubit>.value(value: watched),
          BlocProvider<WeekSummaryCubit>.value(value: week),
        ],
        child: HomePage(
          today: () => DateTime(2026, 10, 12),
          onOpenPlanner: () {},
          onOpenSuggestion: () {},
          onAddStudents: () {},
          onOpenStudents: () {},
          onOpenStudent: (_) {},
          onResume: (_, _) {},
          onPrepare: (_, _) {},
          onLaunch: (_, _, _) {},
          onOpenPlanned: () {},
          onRecord: (_, _, _) {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the empty state with the date in the heading', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Today · Mon, Oct 12'), findsOneWidget);
    expect(find.text('Plan the next session'), findsOneWidget);
    expect(find.text('Nobody needs watching'), findsOneWidget);
  });

  testWidgets('a failing section shows a retry and keeps the others', (
    tester,
  ) async {
    await pump(
      tester,
      upcomingState: const UpcomingSessionsState(
        status: UpcomingStatus.failure,
        failure: NotFound('x', 'y'),
      ),
    );

    expect(find.text('This section could not be loaded.'), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    verify(() => upcoming.load()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('shows nothing for a section while it loads', (tester) async {
    await pump(
      tester,
      upcomingState: const UpcomingSessionsState(),
      weekState: const WeekSummaryState(),
      watchedState: const WatchedStudentsState(),
    );

    expect(find.text('Plan the next session'), findsNothing);
    expect(find.text('Nobody needs watching'), findsNothing);
    expect(find.text('Last 7 days'), findsNothing);
  });

  testWidgets('shows the first running session and lists the others', (
    tester,
  ) async {
    RunningSession run(String sheet, String title) => RunningSession(
      key: RunKey(sheetId: SheetId(sheet)),
      step: 2,
      stepCount: 10,
      phase: SessionPhase.training,
      sheetTitle: title,
      part: 1,
      partCount: 2,
    );
    await pump(
      tester,
      runs: [run('posture-1', 'Posture'), run('posture-2', 'Puissance')],
    );

    expect(find.text('Posture, session 1/2'), findsOneWidget);
    expect(find.text('Resume at step 3'), findsOneWidget);
    expect(
      find.text('Another session under way: Puissance, session 1/2'),
      findsOneWidget,
    );
  });

  testWidgets('abandoning asks for a confirmation', (tester) async {
    when(() => running.abandon(any())).thenAnswer((_) async {});
    await pump(
      tester,
      runs: [
        RunningSession(
          key: RunKey(sheetId: SheetId('posture-1')),
          step: 2,
          stepCount: 10,
          phase: SessionPhase.training,
          sheetTitle: 'Posture',
          part: 1,
          partCount: 2,
        ),
      ],
    );

    await tester.tap(find.text('Abandon'));
    await tester.pumpAndSettle();
    expect(find.text('Abandon this session?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => running.abandon(any()));

    await tester.tap(find.text('Abandon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    verify(() => running.abandon(any())).called(1);
  });

  testWidgets('shows the next session once loaded', (tester) async {
    await pump(
      tester,
      upcomingState: UpcomingSessionsState(
        status: UpcomingStatus.ready,
        upcoming: UpcomingSessions(
          next: PlannedSessionSummary(
            session: Session(
              id: 's1',
              title: 'Cours',
              date: DateTime(2026, 10, 14),
              audience: Audience.children,
              groupId: const GroupId('g1'),
              sheetId: SheetId('posture-1'),
            ),
            group: Group(
              id: const GroupId('g1'),
              seasonId: const SeasonId('s'),
              name: 'Jeunes',
              audience: Audience.children,
            ),
          ),
          groupNames: const {GroupId('g1'): 'Jeunes'},
        ),
      ),
    );

    expect(find.text('Cours'), findsOneWidget);
    expect(find.text('Prepare'), findsOneWidget);
    expect(find.text('Plan the next session'), findsNothing);
  });
}
