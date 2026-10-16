import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_catalogue_bloc.dart';
import 'package:billard_cfa/features/suggest_session/domain/group_journey.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/group_journey_cubit.dart';
import 'package:billard_cfa/pages/sheet_catalogue/presentation/sheet_catalogue_page.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/journey_marker.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/domain_world.dart';
import '../../support/session_sheet_fixtures.dart';
import '../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<SheetCatalogueEvent, SheetCatalogueState>
    implements SheetCatalogueBloc;

class _MockJourney extends MockCubit<GroupJourneyState>
    implements GroupJourneyCubit;

void main() {
  late _MockBloc bloc;
  late _MockJourney journey;
  const children = GroupChoice(GroupId('g1'), 'Enfants');

  setUpAll(() {
    registerFallbackValue(const SheetCatalogueEvent.started());
    registerFallbackValue(const GroupId('any'));
  });
  setUp(() {
    bloc = _MockBloc();
    journey = _MockJourney();
    whenListen(
      journey,
      const Stream<GroupJourneyState>.empty(),
      initialState: const GroupJourneyState(),
    );
    when(() => journey.select(any())).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    void Function(SheetId id, GroupId? group)? onOpenSheet,
  }) => pumpUi(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider<SheetCatalogueBloc>.value(value: bloc),
        BlocProvider<GroupJourneyCubit>.value(value: journey),
      ],
      child: SheetCataloguePage(onOpenSheet: onOpenSheet ?? (_, _) {}),
    ),
  );

  testWidgets('shows the loading state', (tester) async {
    whenListen(
      bloc,
      const Stream<SheetCatalogueState>.empty(),
      initialState: const SheetCatalogueState(),
    );

    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a message and retries when the catalogue is unreadable', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<SheetCatalogueState>.empty(),
      initialState: const SheetCatalogueState(
        status: SheetCatalogueStatus.failure,
        failure: InvariantViolation(InvariantCode.invalidSheet),
      ),
    );
    await pump(tester);

    await tester.tap(find.text('Retry'));

    verify(() => bloc.add(const SheetCatalogueEvent.started())).called(1);
  });

  group('ready', () {
    late SheetCatalogueState ready;

    setUp(() async {
      final catalogue = ok(
        await ListSheets(FixtureSessionSheetRepository(catalogueFixture()))(),
      );
      ready = SheetCatalogueState(
        status: SheetCatalogueStatus.ready,
        catalogue: catalogue,
      );
      whenListen(
        bloc,
        const Stream<SheetCatalogueState>.empty(),
        initialState: ready,
      );
    });

    testWidgets('titles the catalogue and lists the sessions', (tester) async {
      await pump(tester);

      expect(find.text('Session catalogue'), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet:posture-1')), findsOneWidget);
    });

    testWidgets('has no group suggestion button any more', (tester) async {
      await pump(tester);

      expect(find.text('Group suggestion'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('puts the size of the catalogue in the header subtitle', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('3 techniques · 4 sessions'), findsOneWidget);
    });

    testWidgets('counts only the sessions left by the filter', (tester) async {
      whenListen(
        bloc,
        const Stream<SheetCatalogueState>.empty(),
        initialState: ready.copyWith(reviewFilter: SheetReviewFilter.toReview),
      );
      await pump(tester);

      expect(find.text('2 techniques · 2 sessions'), findsOneWidget);
    });

    testWidgets('opens a session', (tester) async {
      SheetId? opened;
      GroupId? group = const GroupId('unset');
      await pump(
        tester,
        onOpenSheet: (id, chosen) {
          opened = id;
          group = chosen;
        },
      );

      final tile = find.byKey(const ValueKey('sheet:quart-1'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);

      expect(opened, SheetId('quart-1'));
      expect(group, isNull);
    });

    testWidgets('hands the group chosen to the opened session', (tester) async {
      whenListen(
        journey,
        const Stream<GroupJourneyState>.empty(),
        initialState: const GroupJourneyState(
          choices: [children],
          status: GroupJourneyStatus.loading,
          groupId: GroupId('g1'),
        ),
      );
      GroupId? group;
      await pump(tester, onOpenSheet: (_, chosen) => group = chosen);

      final tile = find.byKey(const ValueKey('sheet:quart-1'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);

      expect(group, const GroupId('g1'));
    });

    testWidgets('chooses a group through the cubit, or none', (tester) async {
      whenListen(
        journey,
        const Stream<GroupJourneyState>.empty(),
        initialState: const GroupJourneyState(choices: [children]),
      );
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('catalogue-group:g1')));
      await tester.tap(find.byKey(const ValueKey('catalogue-group:none')));

      verifyInOrder([
        () => journey.select(const GroupId('g1')),
        () => journey.select(null),
      ]);
    });

    testWidgets('marks the sessions from the journey of the group', (
      tester,
    ) async {
      whenListen(
        journey,
        const Stream<GroupJourneyState>.empty(),
        initialState: GroupJourneyState(
          choices: const [children],
          status: GroupJourneyStatus.ready,
          groupId: const GroupId('g1'),
          journey: GroupJourney(
            done: {SheetId('posture-1'): DateTime(2026, 10, 5)},
            next: SheetId('demi-bille-1'),
          ),
        ),
      );
      await pump(tester);

      JourneyMark markOf(String id) =>
          tester.widget<JourneyMarker>(find.byKey(ValueKey('mark:$id'))).mark;
      expect(markOf('posture-1'), JourneyMark.done);
      expect(markOf('demi-bille-1'), JourneyMark.next);
      expect(markOf('quart-1'), JourneyMark.upcoming);
    });

    testWidgets('shows no marker while the journey loads', (tester) async {
      whenListen(
        journey,
        const Stream<GroupJourneyState>.empty(),
        initialState: const GroupJourneyState(
          choices: [children],
          status: GroupJourneyStatus.loading,
          groupId: GroupId('g1'),
        ),
      );
      await pump(tester);

      expect(find.byType(JourneyMarker), findsNothing);
      expect(find.byKey(const ValueKey('sheet:posture-1')), findsOneWidget);
    });

    testWidgets('keeps the list and says so when the journey fails', (
      tester,
    ) async {
      whenListen(
        journey,
        const Stream<GroupJourneyState>.empty(),
        initialState: const GroupJourneyState(
          choices: [children],
          status: GroupJourneyStatus.failure,
          groupId: GroupId('g1'),
          failure: NotFound('group', 'g1'),
        ),
      );
      await pump(tester);

      expect(find.byType(JourneyMarker), findsNothing);
      expect(
        find.byKey(const ValueKey('catalogue-journey-failure')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sheet:posture-1')), findsOneWidget);
    });

    testWidgets('toggles the review filter through the bloc', (tester) async {
      await pump(tester);

      await tester.tap(find.text('To validate only'));

      verify(
        () => bloc.add(
          const SheetCatalogueEvent.reviewFilterSelected(
            filter: SheetReviewFilter.toReview,
          ),
        ),
      ).called(1);
    });

    testWidgets('selects the games filter through the bloc', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Games to validate'));

      verify(
        () => bloc.add(
          const SheetCatalogueEvent.reviewFilterSelected(
            filter: SheetReviewFilter.games,
          ),
        ),
      ).called(1);
    });

    testWidgets('lists only the sessions to validate when filtered', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<SheetCatalogueState>.empty(),
        initialState: ready.copyWith(reviewFilter: SheetReviewFilter.toReview),
      );
      await pump(tester);

      expect(find.byKey(const ValueKey('sheet:posture-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet:demi-bille-1')), findsNothing);
    });
  });
}
