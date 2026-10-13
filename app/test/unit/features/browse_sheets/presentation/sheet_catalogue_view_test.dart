import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_catalogue_view.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/domain_world.dart';
import '../../../../support/session_sheet_fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

void main() {
  late SheetCatalogue catalogue;

  setUp(() async {
    catalogue = ok(
      await ListSheets(FixtureSessionSheetRepository(catalogueFixture()))(),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    SheetCatalogue? shown,
    SheetReviewFilter filter = SheetReviewFilter.none,
    ValueChanged<SheetReviewFilter>? onFilter,
    ValueChanged<SheetId>? onOpen,
    Locale locale = const Locale('en'),
  }) => pumpUi(
    tester,
    SingleChildScrollView(
      child: SheetCatalogueView(
        catalogue: shown ?? catalogue,
        filter: filter,
        onFilter: onFilter ?? (_) {},
        onOpenSheet: onOpen ?? (_) {},
      ),
    ),
    locale: locale,
  );

  testWidgets('writes the summary and one section per technique', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('3 techniques · 4 sessions · read-only'), findsOneWidget);
    expect(find.text('1. Quantité posture'), findsOneWidget);
    expect(find.text('2. Quantité demi-bille'), findsOneWidget);
    expect(find.text('3. Quantité quart'), findsOneWidget);
  });

  testWidgets('numbers the parts of a technique over its whole count', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Session 1/2'), findsOneWidget);
    expect(find.text('Session 2/2'), findsOneWidget);
    expect(find.text('Session 1/1'), findsNWidgets(2));
  });

  testWidgets('keeps the whole count of a technique under the filter', (
    tester,
  ) async {
    await pump(
      tester,
      shown: catalogue.filtered(SheetReviewFilter.toReview),
      filter: SheetReviewFilter.toReview,
    );

    expect(find.text('Session 1/1'), findsNWidgets(2));
    expect(find.text('Session 1/2'), findsNothing);
  });

  testWidgets('says what is to validate, in text, on each session', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.byKey(const ValueKey('review:posture-1:exercise')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('review:quart-1:game')), findsOneWidget);
    expect(find.text('Exercises to validate'), findsOneWidget);
    expect(find.text('Game to validate'), findsOneWidget);
    expect(find.byType(ProposalBadge), findsNWidgets(2));
  });

  testWidgets(
    'signals a link rule on a federal game without a proposal badge',
    (tester) async {
      await pump(tester);

      expect(
        find.byKey(const ValueKey('review:demi-bille-1:gameLink')),
        findsOneWidget,
      );
      expect(find.text('Game link rule to validate'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('review:demi-bille-1:game')),
        findsNothing,
      );
    },
  );

  testWidgets('names the federal source of a sourced session', (tester) async {
    await pump(tester);

    expect(find.text('Federal source'), findsNWidgets(4));
  });

  testWidgets('opens a session on tap', (tester) async {
    SheetId? opened;
    await pump(tester, onOpen: (id) => opened = id);

    final tile = find.byKey(const ValueKey('sheet:demi-bille-2'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);

    expect(opened, SheetId('demi-bille-2'));
  });

  testWidgets('chooses a filter from each chip', (tester) async {
    final chosen = <SheetReviewFilter>[];
    await pump(tester, onFilter: chosen.add);

    await tester.tap(find.text('To validate only'));
    await tester.tap(find.text('Games to validate'));

    expect(chosen, [SheetReviewFilter.toReview, SheetReviewFilter.games]);
    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.selected, isFalse);
    }
  });

  testWidgets('shows the chip of the active filter selected', (tester) async {
    await pump(
      tester,
      shown: catalogue.filtered(SheetReviewFilter.games),
      filter: SheetReviewFilter.games,
    );

    final chips = tester
        .widgetList<FilterChip>(find.byType(FilterChip))
        .map((chip) => chip.selected)
        .toList();
    expect(chips, [false, true]);
  });

  testWidgets('says so for each empty case', (tester) async {
    const empty = SheetCatalogue(groups: []);

    await pump(tester, shown: empty, filter: SheetReviewFilter.toReview);
    expect(find.text('No session has content to validate.'), findsOneWidget);

    await pump(tester, shown: empty, filter: SheetReviewFilter.games);
    expect(find.text('No session has a game to validate.'), findsOneWidget);

    await pump(tester, shown: empty);
    expect(find.text('The catalogue holds no session.'), findsOneWidget);
  });

  testWidgets('announces French content only under the English interface', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('written in French'), findsOneWidget);

    await pump(tester, locale: const Locale('fr'));
    expect(find.textContaining('rédigé en français'), findsNothing);
    expect(
      find.text('3 techniques · 4 séances · lecture seule'),
      findsOneWidget,
    );
  });

  testWidgets('has no input field', (tester) async {
    await pump(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });
}
