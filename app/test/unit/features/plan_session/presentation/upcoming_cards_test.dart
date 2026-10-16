import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/upcoming_cards.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

PlannedSessionSummary summary({
  SheetId? sheetId,
  bool withGroup = true,
  bool groupMissing = false,
}) => PlannedSessionSummary(
  session: Session(
    id: 's1',
    title: 'Cours',
    date: DateTime(2026, 10, 14),
    audience: Audience.children,
    groupId: withGroup || groupMissing ? const GroupId('g1') : null,
    sheetId: sheetId,
  ),
  group: withGroup
      ? Group(
          id: const GroupId('g1'),
          seasonId: const SeasonId('season'),
          name: 'Jeunes',
          audience: Audience.children,
        )
      : null,
);

void main() {
  group('NextSessionCard', () {
    testWidgets('shows the title, the date, the group and the actions', (
      tester,
    ) async {
      await pumpUi(
        tester,
        NextSessionCard(
          summary: summary(sheetId: SheetId('posture-1')),
          sameDayOthers: 0,
          onPrepare: (_, _) {},
          onLaunch: (_, _, _) {},
          onOpenPlanned: () {},
        ),
      );

      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Cours'), findsOneWidget);
      expect(
        find.text('Wed, Oct 14 · Jeunes · Children · 90 min'),
        findsOneWidget,
      );
      expect(find.text('Prepare'), findsOneWidget);
      expect(find.text('Launch'), findsOneWidget);
      expect(find.text('Open in Planned'), findsNothing);
    });

    testWidgets('launches with the sheet, the audience and the session', (
      tester,
    ) async {
      (SheetId, Audience, String)? launched;
      await pumpUi(
        tester,
        NextSessionCard(
          summary: summary(sheetId: SheetId('posture-1')),
          sameDayOthers: 0,
          onPrepare: (_, _) {},
          onLaunch: (sheet, audience, session) =>
              launched = (sheet, audience, session),
          onOpenPlanned: () {},
        ),
      );

      await tester.tap(find.text('Launch'));

      expect(launched, (SheetId('posture-1'), Audience.children, 's1'));
    });

    testWidgets('prepares the catalogue session', (tester) async {
      (SheetId, Audience)? prepared;
      await pumpUi(
        tester,
        NextSessionCard(
          summary: summary(sheetId: SheetId('posture-1')),
          sameDayOthers: 0,
          onPrepare: (sheet, audience) => prepared = (sheet, audience),
          onLaunch: (_, _, _) {},
          onOpenPlanned: () {},
        ),
      );

      await tester.tap(find.text('Prepare'));

      expect(prepared, (SheetId('posture-1'), Audience.children));
    });

    testWidgets('offers only Open in Planned without a catalogue session', (
      tester,
    ) async {
      var opened = 0;
      await pumpUi(
        tester,
        NextSessionCard(
          summary: summary(),
          sameDayOthers: 0,
          onPrepare: (_, _) {},
          onLaunch: (_, _, _) {},
          onOpenPlanned: () => opened++,
        ),
      );

      expect(find.text('Prepare'), findsNothing);
      expect(find.text('Launch'), findsNothing);
      await tester.tap(find.text('Open in Planned'));
      expect(opened, 1);
    });

    testWidgets('says the group is unavailable but still launches', (
      tester,
    ) async {
      await pumpUi(
        tester,
        NextSessionCard(
          summary: summary(
            sheetId: SheetId('posture-1'),
            withGroup: false,
            groupMissing: true,
          ),
          sameDayOthers: 0,
          onPrepare: (_, _) {},
          onLaunch: (_, _, _) {},
          onOpenPlanned: () {},
        ),
      );

      expect(find.text('Group unavailable'), findsOneWidget);
      expect(find.text('Launch'), findsOneWidget);
    });

    testWidgets('counts the other sessions of the same day', (tester) async {
      await pumpUi(
        tester,
        NextSessionCard(
          summary: summary(sheetId: SheetId('posture-1')),
          sameDayOthers: 2,
          onPrepare: (_, _) {},
          onLaunch: (_, _, _) {},
          onOpenPlanned: () {},
        ),
      );

      expect(find.text('+ 2 other sessions that day'), findsOneWidget);
    });
  });

  group('EmptyNextSessionCard', () {
    testWidgets('invites to plan and to see the suggestion', (tester) async {
      var suggestion = 0;
      await pumpUi(
        tester,
        EmptyNextSessionCard(
          hasClub: true,
          onSuggestion: () => suggestion++,
          onAddStudents: () {},
        ),
      );

      expect(find.text('Plan the next session'), findsOneWidget);
      expect(find.text('Add a student'), findsNothing);
      await tester.tap(find.text('See the suggestion'));
      expect(suggestion, 1);
    });

    testWidgets('offers to add students when the club is empty', (
      tester,
    ) async {
      var added = 0;
      await pumpUi(
        tester,
        EmptyNextSessionCard(
          hasClub: false,
          onSuggestion: () {},
          onAddStudents: () => added++,
        ),
      );

      await tester.tap(find.text('Add a student'));
      expect(added, 1);
    });
  });

  group('ToRecordList', () {
    testWidgets('lists the sessions to note and opens their record', (
      tester,
    ) async {
      PlannedSessionSummary? recorded;
      final item = summary(sheetId: SheetId('posture-1'));
      await pumpUi(
        tester,
        ToRecordList(sessions: [item], onRecord: (s) => recorded = s),
      );

      expect(find.text('To note'), findsOneWidget);
      expect(find.text('Cours · Wed, Oct 14'), findsOneWidget);
      await tester.tap(find.text('Note the results'));
      expect(recorded, item);
    });
  });
}
