import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/closure_plan.dart';
import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/season_closure_bloc.dart';
import 'package:billard_cfa/features/close_season/presentation/ui/season_closure_view.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<SeasonClosureEvent, SeasonClosureState>
    implements SeasonClosureBloc;

void main() {
  late _MockBloc bloc;
  var seasons = 0;
  var home = 0;

  setUpAll(() {
    registerFallbackValue(const SeasonClosureEvent.confirmed());
  });

  setUp(() {
    bloc = _MockBloc();
    seasons = 0;
    home = 0;
  });

  const lea = StudentId('lea');
  const hugo = StudentId('hugo');
  final season = Season(
    id: const SeasonId('s'),
    label: '2026-2027',
    startDate: day(1),
    endDate: day(31),
  );

  ClosurePlan plan({
    bool early = false,
    int planned = 2,
    List<ClosureProposal>? proposals,
  }) => ClosurePlan(
    season: season,
    closedOn: day(12),
    early: early,
    audiences: [
      AudienceArchive(
        audience: Audience.children,
        sessionCount: 4,
        presenceCount: 9,
        possiblePresenceCount: 12,
        studentCount: 3,
        attemptCount: 5,
      ),
    ],
    proposals:
        proposals ??
        const [
          ClosureProposal(
            studentId: lea,
            firstName: 'Léa',
            audience: Audience.children,
            choice: ClosureChoice.keep,
            reason: ClosureReason.carriedOver,
          ),
          ClosureProposal(
            studentId: hugo,
            firstName: 'Hugo',
            audience: Audience.children,
            choice: ClosureChoice.erase,
            reason: ClosureReason.retentionExpired,
          ),
        ],
    plannedToDrop: planned,
  );

  SeasonClosureState ready(ClosurePlan plan, {Failure? failure}) =>
      SeasonClosureState(
        status: SeasonClosureStatus.ready,
        plan: plan,
        choices: {for (final p in plan.proposals) p.studentId: p.choice},
        failure: failure,
      );

  Future<void> pump(WidgetTester tester, SeasonClosureState state) async {
    // L'assistant est long : une fenêtre haute évite de faire défiler.
    tester.view
      ..physicalSize = const Size(800, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => bloc.state).thenReturn(state);
    await pumpUi(
      tester,
      BlocProvider<SeasonClosureBloc>.value(
        value: bloc,
        child: SingleChildScrollView(
          child: SeasonClosureView(
            backupSection: const Text('backup before'),
            backupAfterSection: const Text('backup after'),
            onSeasons: () => seasons++,
            onHome: () => home++,
          ),
        ),
      ),
    );
  }

  testWidgets('shows a progress indicator while preparing', (tester) async {
    await pump(tester, const SeasonClosureState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a season that cannot be closed leaves through Today', (
    tester,
  ) async {
    await pump(
      tester,
      const SeasonClosureState(
        status: SeasonClosureStatus.failure,
        failure: InvariantViolation(InvariantCode.seasonAlreadyClosed),
      ),
    );

    expect(find.text('This season is already closed.'), findsOneWidget);
  });

  testWidgets('summarises the season and the early closure', (tester) async {
    await pump(tester, ready(plan(early: true)));

    expect(find.text('1. Summary'), findsOneWidget);
    expect(find.text('4 sessions, 9 attendances'), findsOneWidget);
    expect(find.text('2 students in the season'), findsOneWidget);
    expect(find.textContaining('it will be closed today'), findsOneWidget);
    expect(find.text('backup before'), findsOneWidget);
  });

  testWidgets('writes the singular for one session and one attendance', (
    tester,
  ) async {
    await pump(
      tester,
      ready(
        plan().copyWith(
          audiences: [
            AudienceArchive(
              audience: Audience.children,
              sessionCount: 1,
              presenceCount: 1,
              possiblePresenceCount: 2,
              studentCount: 3,
              attemptCount: 0,
            ),
          ],
        ),
      ),
    );

    expect(find.text('1 session, 1 attendance'), findsOneWidget);
  });

  testWidgets('says no attendance when the season had none', (tester) async {
    await pump(tester, ready(plan().copyWith(audiences: const [])));

    expect(find.text('0 sessions, no attendance'), findsOneWidget);
  });

  testWidgets('says nothing about an early closure at the end of the season', (
    tester,
  ) async {
    await pump(tester, ready(plan()));

    expect(find.textContaining('it will be closed today'), findsNothing);
  });

  testWidgets('shows every reason in words', (tester) async {
    await pump(tester, ready(plan()));

    expect(find.text('Active and enrolled this season'), findsOneWidget);
    expect(
      find.text(
        'Enrolled before this season: kept only until the following season',
      ),
      findsOneWidget,
    );
  });

  testWidgets('sends the line, whole-list and option choices', (tester) async {
    await pump(tester, ready(plan()));

    await tester.tap(find.text('Erase everyone'));
    await tester.tap(find.text('Keep everyone'));
    await tester.tap(find.byKey(const ValueKey('closure-tile:lea')));
    await tester.tap(find.byKey(const ValueKey('closure-prepare-next')));
    await tester.tap(find.byKey(const ValueKey('closure-drop-planned')));

    verify(
      () => bloc.add(
        const SeasonClosureEvent.allSet(choice: ClosureChoice.erase),
      ),
    ).called(1);
    verify(
      () =>
          bloc.add(const SeasonClosureEvent.allSet(choice: ClosureChoice.keep)),
    ).called(1);
    verify(
      () => bloc.add(
        const SeasonClosureEvent.choiceSet(
          studentId: lea,
          choice: ClosureChoice.erase,
        ),
      ),
    ).called(1);
    verify(
      () => bloc.add(const SeasonClosureEvent.prepareNextSet(value: false)),
    ).called(1);
    verify(
      () => bloc.add(const SeasonClosureEvent.dropPlannedSet(value: false)),
    ).called(1);
  });

  testWidgets('has no planned session to drop: the option is disabled', (
    tester,
  ) async {
    await pump(tester, ready(plan(planned: 0)));

    expect(
      find.text('No planned session to delete after the closure'),
      findsOneWidget,
    );
    final option = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('closure-drop-planned')),
    );
    expect(option.onChanged, isNull);
  });

  testWidgets('a season without student says so and offers no list buttons', (
    tester,
  ) async {
    await pump(tester, ready(plan(proposals: const [])));

    expect(find.text('No student in this season.'), findsOneWidget);
    expect(find.text('Keep everyone'), findsNothing);
    expect(find.text('Close the season'), findsOneWidget);
  });

  testWidgets('closing without erasure confirms at once', (tester) async {
    await pump(tester, ready(plan(proposals: const [])));

    await tester.tap(find.byKey(const ValueKey('closure-close')));

    verify(() => bloc.add(const SeasonClosureEvent.confirmed())).called(1);
  });

  testWidgets('a refusal is written under the button', (tester) async {
    await pump(
      tester,
      ready(
        plan(),
        failure: const InvariantViolation(InvariantCode.seasonClosed),
      ),
    );

    expect(
      find.text('This season is closed: it accepts no new entry.'),
      findsOneWidget,
    );
  });

  testWidgets('the button is disabled while closing', (tester) async {
    await pump(
      tester,
      ready(plan()).copyWith(status: SeasonClosureStatus.closing),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('closure-close')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the report gives numbers only and leaves by its two buttons', (
    tester,
  ) async {
    await pump(
      tester,
      ready(plan()).copyWith(
        status: SeasonClosureStatus.closed,
        result: const ClosureResult(
          erased: 1,
          kept: 3,
          groupsPrepared: 2,
          plannedDropped: 0,
        ),
      ),
    );

    expect(find.text('Season closed'), findsOneWidget);
    expect(find.text('Season 2026-2027 closed.'), findsOneWidget);
    expect(find.text('1 student erased'), findsOneWidget);
    expect(find.text('3 students kept'), findsOneWidget);
    expect(find.text('2 groups prepared'), findsOneWidget);
    expect(find.text('backup after'), findsOneWidget);
    expect(find.textContaining('Hugo'), findsNothing);
    await tester.tap(find.text('See past seasons'));
    await tester.tap(find.text('Back to Today'));
    expect(seasons, 1);
    expect(home, 1);
  });
}
