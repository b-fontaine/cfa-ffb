import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_catalogue_view.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/journey_marker.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/domain_world.dart';
import '../../../../support/session_sheet_fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

void main() {
  late SheetCatalogue catalogue;
  const children = GroupChoice(GroupId('g1'), 'Enfants');
  const adults = GroupChoice(GroupId('g2'), 'Adultes');

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
    List<GroupChoice> groups = const [],
    GroupId? selected,
    ValueChanged<GroupId?>? onGroup,
    Map<SheetId, JourneyMark> marks = const {},
    bool noStudents = false,
    Failure? journeyFailure,
    Locale locale = const Locale('en'),
  }) => pumpUi(
    tester,
    SingleChildScrollView(
      child: SheetCatalogueView(
        catalogue: shown ?? catalogue,
        filter: filter,
        onFilter: onFilter ?? (_) {},
        onOpenSheet: onOpen ?? (_) {},
        groups: groups,
        selectedGroup: selected,
        onGroupSelected: onGroup ?? (_) {},
        marks: marks,
        noStudents: noStudents,
        journeyFailure: journeyFailure,
      ),
    ),
    locale: locale,
  );

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets('writes one section per technique', (tester) async {
    await pump(tester);

    expect(find.text('1. Quantité posture'), findsOneWidget);
    expect(find.text('2. Quantité demi-bille'), findsOneWidget);
    expect(find.text('3. Quantité quart'), findsOneWidget);
  });

  testWidgets('leaves the size of the catalogue to the page header', (
    tester,
  ) async {
    await pump(tester);

    expect(find.textContaining('techniques'), findsNothing);
    expect(find.textContaining('read-only'), findsNothing);
  });

  testWidgets('titles a row with the evocative name, then part and technique', (
    tester,
  ) async {
    await pump(tester);

    expect(textOf(tester, 'sheet-title:demi-bille-1'), 'Le partage');
    expect(
      textOf(tester, 'sheet-subtitle:demi-bille-1'),
      'Session 1/2 · Quantité demi-bille',
    );
    expect(
      textOf(tester, 'sheet-subtitle:demi-bille-2'),
      'Session 2/2 · Quantité demi-bille',
    );
    expect(
      textOf(tester, 'sheet-subtitle:quart-1'),
      'Session 1/1 · Quantité quart',
    );
  });

  testWidgets('falls back on the part when a session has no name', (
    tester,
  ) async {
    final unnamed = SheetCatalogue(
      groups: [
        catalogue.groups.first.copyWith(
          sheets: [
            catalogue.groups.first.sheets.first.copyWith(
              theme: catalogue.groups.first.sheets.first.theme.copyWith(
                name: '',
              ),
            ),
          ],
        ),
      ],
    );
    await pump(tester, shown: unnamed);

    expect(textOf(tester, 'sheet-title:posture-1'), 'Session 1/1');
  });

  testWidgets('keeps the whole count of a technique under the filter', (
    tester,
  ) async {
    await pump(
      tester,
      shown: catalogue.filtered(SheetReviewFilter.toReview),
      filter: SheetReviewFilter.toReview,
    );

    expect(
      textOf(tester, 'sheet-subtitle:quart-1'),
      'Session 1/1 · Quantité quart',
    );
    expect(find.byKey(const ValueKey('sheet:demi-bille-1')), findsNothing);
  });

  testWidgets('says the names are proposals once, in the header', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.text('Evocative names are proposals, not federal wording.'),
      findsOneWidget,
    );
  });

  group('review badge', () {
    testWidgets('is one single badge with the number of points', (
      tester,
    ) async {
      await pump(tester);

      final badge = tester.widget<StatusBadge>(
        find.byKey(const ValueKey('review-badge:posture-1')),
      );
      expect(badge.label, '1 point to validate');
      expect(badge.tone, BadgeTone.attention);
      for (final id in ['posture-1', 'quart-1']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('sheet:$id')),
            matching: find.byType(StatusBadge),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('is absent when nothing counts, even with a link rule', (
      tester,
    ) async {
      await pump(tester);

      expect(
        find.byKey(const ValueKey('review-badge:demi-bille-1')),
        findsNothing,
      );
    });

    testWidgets('leaves out the proposal and the source badges of the list', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(ProposalBadge), findsNothing);
      expect(find.byType(ProvenanceBadge), findsNothing);
      expect(find.text('Federal source'), findsNothing);
    });

    testWidgets('explains its reasons in a tooltip and in semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final badge = find.byKey(const ValueKey('review-badge:posture-1'));
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: badge, matching: find.byType(Tooltip)).first,
      );
      expect(tooltip.message, contains('1 point to validate'));
      expect(tooltip.message, contains('Exercises to validate'));
      expect(
        tester.getSemantics(badge).label,
        contains('Exercises to validate'),
      );
      handle.dispose();
    });

    testWidgets(
      'signals each minor proposal by a neutral badge, counted apart',
      (tester) async {
        final sheet = buildSheet(
          technique: 'posture',
          order: 1,
          previous: null,
          exercises: [sheetExercise('e1', 1, src: Provenance.prop)],
          theory: [theorySection('t1', src: Provenance.prop)],
        );
        await pump(
          tester,
          shown: SheetCatalogue(
            groups: [
              TechniqueGroup(
                rank: 1,
                technique: 'posture',
                title: sheet.title,
                partCount: 1,
                sheets: [sheet],
              ),
            ],
          ),
        );

        final badge = find.byKey(const ValueKey('review-badge:posture-1'));
        expect(tester.widget<StatusBadge>(badge).label, '1 point to validate');
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(of: badge, matching: find.byType(Tooltip)).first,
        );
        expect(tooltip.message, isNot(contains('Theory: proposal')));
        final minor = tester.widget<StatusBadge>(
          find.byKey(const ValueKey('review:posture-1:theory')),
        );
        expect(minor.label, 'Theory: proposal');
        expect(minor.tone, BadgeTone.neutral);
      },
    );

    testWidgets('signals a minor proposal on a row with nothing to validate', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(
        find.byKey(const ValueKey('review-badge:demi-bille-1')),
        findsNothing,
      );
      final minor = find.byKey(const ValueKey('review:demi-bille-1:gameLink'));
      expect(tester.widget<StatusBadge>(minor).label, contains('proposal'));
      expect(
        tester.getSemantics(minor).label,
        contains('Game link rule: proposal'),
      );
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: minor, matching: find.byType(Tooltip)).first,
      );
      expect(tooltip.message, contains('not counted'));
      handle.dispose();
    });
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
      find.text(
        'Les noms évocateurs sont des propositions, non des termes fédéraux.',
      ),
      findsOneWidget,
    );
    expect(
      textOf(tester, 'sheet-subtitle:demi-bille-2'),
      'Séance 2/2 · Quantité demi-bille',
    );
    expect(
      tester
          .widget<StatusBadge>(
            find.byKey(const ValueKey('review-badge:posture-1')),
          )
          .label,
      '1 point à valider',
    );
  });

  testWidgets('has no input field', (tester) async {
    await pump(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  group('group journey', () {
    testWidgets('shows no group selector and no marker without groups', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(JourneyMarker), findsNothing);
    });

    testWidgets('offers no group, then one chip per group', (tester) async {
      await pump(tester, groups: const [children, adults]);

      expect(
        find.byKey(const ValueKey('catalogue-group:none')),
        findsOneWidget,
      );
      expect(find.text('No group'), findsOneWidget);
      expect(find.text('Enfants'), findsOneWidget);
      expect(find.text('Adultes'), findsOneWidget);
      final selected = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((chip) => chip.selected);
      expect(selected, [true, false, false]);
    });

    testWidgets('selects a group, or none, from the chips', (tester) async {
      final chosen = <GroupId?>[];
      await pump(
        tester,
        groups: const [children, adults],
        selected: children.id,
        onGroup: chosen.add,
      );

      await tester.tap(find.byKey(const ValueKey('catalogue-group:g2')));
      await tester.tap(find.byKey(const ValueKey('catalogue-group:none')));

      expect(chosen, [adults.id, null]);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('catalogue-group:g1')),
            )
            .selected,
        isTrue,
      );
    });

    testWidgets('marks each session by its own mark', (tester) async {
      await pump(
        tester,
        groups: const [children],
        selected: children.id,
        marks: {
          SheetId('posture-1'): JourneyMark.done,
          SheetId('demi-bille-1'): JourneyMark.next,
          SheetId('demi-bille-2'): JourneyMark.upcoming,
          SheetId('quart-1'): JourneyMark.upcoming,
        },
      );

      JourneyMark markOf(String id) =>
          tester.widget<JourneyMarker>(find.byKey(ValueKey('mark:$id'))).mark;
      expect(markOf('posture-1'), JourneyMark.done);
      expect(markOf('demi-bille-1'), JourneyMark.next);
      expect(markOf('demi-bille-2'), JourneyMark.upcoming);
      expect(find.byType(JourneyMarker), findsNWidgets(4));
    });

    testWidgets('explains the three marks once a group is chosen', (
      tester,
    ) async {
      await pump(tester, groups: const [children]);
      expect(find.text('Recommended next'), findsNothing);

      await pump(
        tester,
        groups: const [children],
        selected: children.id,
        marks: {SheetId('posture-1'): JourneyMark.done},
      );

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Recommended next'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
    });

    testWidgets('says a group without student has no recommendation', (
      tester,
    ) async {
      await pump(
        tester,
        groups: const [children],
        selected: children.id,
        noStudents: true,
        marks: {SheetId('posture-1'): JourneyMark.done},
      );

      expect(
        find.text(
          'This group has no student: '
          'only the sessions already given are marked.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a message and keeps the list when the journey fails', (
      tester,
    ) async {
      await pump(
        tester,
        groups: const [children],
        selected: children.id,
        journeyFailure: const NotFound('group', 'g1'),
      );

      expect(find.byType(JourneyMarker), findsNothing);
      expect(find.byKey(const ValueKey('sheet:posture-1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('catalogue-journey-failure')),
        findsOneWidget,
      );
    });
  });

  group('narrow screen', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('does not overflow on 320 dp at ${scale * 100} % text', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(320, 640)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pump(
          tester,
          groups: const [children, adults],
          selected: children.id,
          marks: {
            SheetId('posture-1'): JourneyMark.done,
            SheetId('demi-bille-1'): JourneyMark.next,
            SheetId('demi-bille-2'): JourneyMark.upcoming,
            SheetId('quart-1'): JourneyMark.upcoming,
          },
        );

        expect(tester.takeException(), isNull);
        final tile = tester.getSize(
          find.byKey(const ValueKey('sheet:posture-1')),
        );
        expect(tile.height, greaterThanOrEqualTo(48));
      });
    }
  });
}
