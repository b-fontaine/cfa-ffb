import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/features/manage_students/presentation/ui/club_list.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/club_fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

/// Le bouton (Material) qui porte [text], icône comprise.
Finder buttonWith(String text) => find.ancestor(
  of: find.text(text),
  matching: find.bySubtype<ButtonStyleButton>(),
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    ClubOverview club, {
    ValueChanged<GroupId>? onOpenGroup,
  }) => pumpUi(
    tester,
    SingleChildScrollView(
      child: ClubList(
        club: club,
        onOpenStudent: (_) {},
        onOpenGroup: onOpenGroup ?? (_) {},
      ),
    ),
  );

  group('ClubList', () {
    testWidgets('offers the grid of each group with members', (tester) async {
      GroupId? opened;
      await pump(
        tester,
        ClubOverview(
          groups: [
            groupOverview('g1', 'Jeunes', [summary('s1', 'Léa')]),
          ],
          unassigned: const [],
        ),
        onOpenGroup: (id) => opened = id,
      );

      expect(find.text('Group grid'), findsOneWidget);
      final button = buttonWith('Group grid');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(opened, const GroupId('g1'));
    });

    testWidgets('names the group in the accessible name of the button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        ClubOverview(
          groups: [
            groupOverview('g1', 'Jeunes', [summary('s1', 'Léa')]),
            groupOverview('g2', 'Adultes', [summary('s2', 'Marc')]),
          ],
          unassigned: const [],
        ),
      );

      expect(find.bySemanticsLabel('Open the grid of Jeunes'), findsOneWidget);
      expect(find.bySemanticsLabel('Open the grid of Adultes'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a group without member has no grid to open', (tester) async {
      await pump(
        tester,
        ClubOverview(
          groups: [groupOverview('g1', 'Vide', [])],
          unassigned: const [],
        ),
      );

      expect(find.text('Group grid'), findsNothing);
    });

    testWidgets('a new student has a path to start, not a score of zero', (
      tester,
    ) async {
      final started = StudentSummary(
        student: summary('s2', 'Hugo').student,
        validatedCount: 3,
        exerciseCount: 70,
        alertCount: 0,
      );
      final fresh = StudentSummary(
        student: summary('s1', 'Léa').student,
        validatedCount: 0,
        exerciseCount: 70,
        alertCount: 0,
        toStart: true,
      );
      await pump(
        tester,
        ClubOverview(
          groups: [
            groupOverview('g1', 'Jeunes', [fresh, started]),
          ],
          unassigned: const [],
        ),
      );

      expect(find.text('Path to start'), findsOneWidget);
      expect(find.text('3 exercises validated'), findsOneWidget);
      expect(find.textContaining('of 70'), findsNothing);
    });

    testWidgets('students without a group have no grid', (tester) async {
      await pump(
        tester,
        ClubOverview(groups: const [], unassigned: [summary('s1', 'Léa')]),
      );

      expect(find.text('Group grid'), findsNothing);
    });
  });
}
