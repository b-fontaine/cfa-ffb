import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/features/select_club/presentation/ui/club_choice_list.dart';
import 'package:billard_cfa/pages/select_club/presentation/select_club_page.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../shared/ui/pump_ui.dart';

const _nice = ClubMembership(
  clubId: ClubId('nice'),
  clubName: 'Club Nice',
  role: Role.director,
);
const _lyon = ClubMembership(
  clubId: ClubId('lyon'),
  clubName: 'Club Lyon',
  role: Role.guardian,
);

void main() {
  group('ClubChoiceList', () {
    testWidgets('lists each club with its role and reports the choice', (
      tester,
    ) async {
      final chosen = <ClubMembership>[];
      await pumpUi(
        tester,
        ClubChoiceList(choices: const [_nice, _lyon], onChoose: chosen.add),
      );

      expect(find.text('Club Nice'), findsOneWidget);
      expect(find.text('Director'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);

      await tester.tap(find.text('Club Lyon'));

      expect(chosen, [_lyon]);
    });

    testWidgets('marks the active club with text, icon and selected state', (
      tester,
    ) async {
      await pumpUi(
        tester,
        ClubChoiceList(
          choices: const [_nice, _lyon],
          current: _nice.clubId,
          onChoose: (_) {},
        ),
      );

      expect(find.text('Director · Active club'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tiles.first.selected, isTrue);
      expect(tiles.last.selected, isFalse);
    });

    testWidgets('rows are at least 48 dp high', (tester) async {
      await pumpUi(
        tester,
        ClubChoiceList(choices: const [_nice], onChoose: (_) {}),
      );

      expect(
        tester.getSize(find.byType(ListTile)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('disabled, a tap chooses nothing', (tester) async {
      final chosen = <ClubMembership>[];
      await pumpUi(
        tester,
        ClubChoiceList(
          choices: const [_nice],
          enabled: false,
          onChoose: chosen.add,
        ),
      );

      await tester.tap(find.text('Club Nice'), warnIfMissed: false);

      expect(chosen, isEmpty);
    });
  });

  group('SelectClubPage', () {
    Future<void> pump(
      WidgetTester tester, {
      List<ClubMembership> choices = const [_nice, _lyon],
      bool blocked = false,
      VoidCallback? onBack,
      VoidCallback? onRefresh,
      VoidCallback? onSignOut,
    }) => pumpUi(
      tester,
      SelectClubPage(
        choices: choices,
        blocked: blocked,
        onChoose: (_) {},
        onSignOut: onSignOut ?? () {},
        onRefresh: onRefresh,
        onBack: onBack,
      ),
    );

    testWidgets('at sign-in, offers the choice and signing out', (
      tester,
    ) async {
      var signedOut = 0;
      await pump(tester, onSignOut: () => signedOut++);

      expect(find.text('Choose a club'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      expect(signedOut, 1);
    });

    testWidgets('without a club, says so and offers to refresh', (
      tester,
    ) async {
      var refreshed = 0;
      await pump(tester, choices: const [], onRefresh: () => refreshed++);

      expect(find.text('No club'), findsOneWidget);
      await tester.tap(find.text('Refresh'));
      expect(refreshed, 1);
    });

    testWidgets('from More, goes back and does not offer to sign out', (
      tester,
    ) async {
      var back = 0;
      await pump(tester, onBack: () => back++);

      expect(find.text('Sign out'), findsNothing);
      await tester.tap(find.text('Back to More'));
      expect(back, 1);
    });

    testWidgets('blocked, warns and ignores taps', (tester) async {
      await pump(tester, blocked: true, onBack: () {});

      expect(
        find.text('Finish or leave the current session before switching club.'),
        findsOneWidget,
      );
    });
  });
}
