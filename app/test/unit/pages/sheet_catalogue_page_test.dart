import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/bloc/sheet_catalogue_bloc.dart';
import 'package:billard_cfa/pages/sheet_catalogue/presentation/sheet_catalogue_page.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
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

void main() {
  late _MockBloc bloc;

  setUpAll(() => registerFallbackValue(const SheetCatalogueEvent.started()));
  setUp(() => bloc = _MockBloc());

  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<SheetId>? onOpenSheet,
    VoidCallback? onOpenSuggestion,
  }) => pumpUi(
    tester,
    BlocProvider<SheetCatalogueBloc>.value(
      value: bloc,
      child: SheetCataloguePage(
        onOpenSheet: onOpenSheet ?? (_) {},
        onOpenSuggestion: onOpenSuggestion ?? () {},
      ),
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

    testWidgets('keeps the group suggestion at the top', (tester) async {
      var opened = 0;
      await pump(tester, onOpenSuggestion: () => opened++);

      await tester.tap(find.text('Group suggestion'));

      expect(opened, 1);
    });

    testWidgets('opens a session', (tester) async {
      SheetId? opened;
      await pump(tester, onOpenSheet: (id) => opened = id);

      final tile = find.byKey(const ValueKey('sheet:quart-1'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);

      expect(opened, SheetId('quart-1'));
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
