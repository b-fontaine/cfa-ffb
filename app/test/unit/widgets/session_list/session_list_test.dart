import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/widgets/session_list/presentation/session_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';
import '../../shared/ui/pump_ui.dart';

void main() {
  final option = SheetOption(
    id: SheetId('demi-bille-2'),
    technique: 'demi-bille',
    techniqueRank: 2,
    title: 'Quantité demi-bille',
    part: 2,
    partCount: 2,
  );
  final jeunes = Group(
    id: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    name: 'Jeunes',
    audience: Audience.children,
  );
  final free = PlannedSessionSummary(
    session: Session(
      id: 'a',
      title: 'Libre',
      date: day(12),
      audience: Audience.children,
    ),
  );
  final linked = PlannedSessionSummary(
    session: Session(
      id: 'b',
      title: 'Lié',
      date: day(19),
      audience: Audience.adults,
      sheetId: SheetId('demi-bille-2'),
    ),
  );
  final lost = PlannedSessionSummary(
    session: Session(
      id: 'c',
      title: 'Perdu',
      date: day(12),
      audience: Audience.children,
      sheetId: SheetId('inconnue-9'),
    ),
  );
  final forGroup = PlannedSessionSummary(
    session: Session(
      id: 'd',
      title: 'Jeunes du samedi',
      date: day(12),
      audience: Audience.children,
      groupId: const GroupId('g1'),
      sheetId: SheetId('demi-bille-2'),
    ),
    group: jeunes,
  );

  Future<void> pump(
    WidgetTester tester,
    List<PlannedSessionSummary> sessions, {
    void Function(SheetId, Audience)? onOpenSheet,
    VoidCallback? onChooseSheet,
    void Function(SheetId, Audience, String)? onLaunchSheet,
    void Function(GroupId, DateTime, SheetId?)? onRecord,
    ValueChanged<SessionId>? onOpenRecord,
    ValueChanged<Session>? onDelete,
  }) => pumpUi(
    tester,
    SessionList(
      sessions: sessions,
      sheetOptions: [option],
      onOpenSheet: onOpenSheet ?? (_, _) {},
      onChooseSheet: onChooseSheet ?? () {},
      onLaunchSheet: onLaunchSheet ?? (_, _, _) {},
      onRecord: onRecord ?? (_, _, _) {},
      onOpenRecord: onOpenRecord ?? (_) {},
      onDelete: onDelete,
    ),
  );

  testWidgets('launches the linked session with its audience and id', (
    tester,
  ) async {
    final launched = <(SheetId, Audience, String)>[];
    await pump(
      tester,
      [linked],
      onLaunchSheet: (id, audience, sessionId) =>
          launched.add((id, audience, sessionId)),
    );

    await tester.tap(find.text('Launch'));

    expect(launched, [(SheetId('demi-bille-2'), Audience.adults, 'b')]);
  });

  testWidgets('does not offer to launch a free or unavailable session', (
    tester,
  ) async {
    await pump(tester, [free, lost]);

    expect(find.text('Launch'), findsNothing);
  });

  testWidgets('says nothing is planned when the list is empty', (tester) async {
    await pump(tester, const []);

    expect(find.text('No session planned yet.'), findsOneWidget);
  });

  testWidgets('offers to choose a session for a free session', (tester) async {
    var chosen = 0;
    await pump(tester, [free], onChooseSheet: () => chosen++);

    await tester.tap(find.text('Choose a session'));

    expect(chosen, 1);
    expect(find.text('Mon, Oct 12 · Children · 90 min'), findsOneWidget);
  });

  testWidgets('opens the linked catalogue session for its audience', (
    tester,
  ) async {
    final opened = <(SheetId, Audience)>[];
    await pump(tester, [
      linked,
    ], onOpenSheet: (id, audience) => opened.add((id, audience)));

    await tester.tap(
      find.text('Catalogue session: Quantité demi-bille, session 2/2'),
    );

    expect(opened, [(SheetId('demi-bille-2'), Audience.adults)]);
    expect(find.text('Mon, Oct 19 · Adults · 120 min'), findsOneWidget);
  });

  testWidgets('shows a vanished catalogue session as unavailable', (
    tester,
  ) async {
    await pump(tester, [lost]);

    expect(find.text('Catalogue session unavailable'), findsOneWidget);
    expect(find.text('Choose a session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('a session planned for a group', () {
    testWidgets('names the group and offers to note the results', (
      tester,
    ) async {
      final recorded = <(GroupId, DateTime, SheetId?)>[];
      await pump(tester, [
        forGroup,
      ], onRecord: (group, date, sheet) => recorded.add((group, date, sheet)));

      expect(
        find.text('Mon, Oct 12 · Jeunes · Children · 90 min'),
        findsOneWidget,
      );
      await tester.tap(find.text('Note the results'));

      expect(recorded, [
        (const GroupId('g1'), day(12), SheetId('demi-bille-2')),
      ]);
    });

    testWidgets('notes a free session without catalogue session', (
      tester,
    ) async {
      final recorded = <SheetId?>[];
      await pump(tester, [
        forGroup.copyWith(session: forGroup.session.copyWith(sheetId: null)),
      ], onRecord: (_, _, sheet) => recorded.add(sheet));

      await tester.tap(find.text('Note the results'));

      expect(recorded, [null]);
    });

    testWidgets('opens the record once the results are recorded', (
      tester,
    ) async {
      final opened = <SessionId>[];
      await pump(tester, [
        forGroup.copyWith(recordId: const SessionId('x1')),
      ], onOpenRecord: opened.add);

      expect(find.text('Note the results'), findsNothing);
      await tester.tap(find.text('Results recorded'));

      expect(opened, [const SessionId('x1')]);
    });

    testWidgets('flags a group the club no longer knows', (tester) async {
      await pump(tester, [forGroup.copyWith(group: null)]);

      expect(find.text('Group unavailable'), findsOneWidget);
      expect(find.text('Note the results'), findsNothing);
      expect(find.text('Mon, Oct 12 · Children · 90 min'), findsOneWidget);
    });
  });

  testWidgets('does not offer to note a session without group', (tester) async {
    await pump(tester, [free, linked]);

    expect(find.text('Note the results'), findsNothing);
    expect(find.text('Results recorded'), findsNothing);
  });

  group('deleting a planned session', () {
    testWidgets('offers no delete action without a handler', (tester) async {
      await pump(tester, [linked]);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('asks to confirm, then deletes that session', (tester) async {
      final deleted = <Session>[];
      await pump(tester, [free, linked], onDelete: deleted.add);

      await tester.tap(
        find.byTooltip('Delete session ${linked.session.title}'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this planned session?'), findsOneWidget);
      expect(deleted, isEmpty);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(deleted, [linked.session]);
    });

    testWidgets('keeps the session when the confirmation is cancelled', (
      tester,
    ) async {
      final deleted = <Session>[];
      await pump(tester, [linked], onDelete: deleted.add);

      await tester.tap(
        find.byTooltip('Delete session ${linked.session.title}'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleted, isEmpty);
      expect(find.text('Delete this planned session?'), findsNothing);
    });
  });
}
