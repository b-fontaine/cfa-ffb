import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/sheet_option.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/widgets/session_list/presentation/session_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  const free = Session(id: 'a', title: 'Libre', audience: Audience.children);
  final linked = Session(
    id: 'b',
    title: 'Lié',
    audience: Audience.adults,
    sheetId: SheetId('demi-bille-2'),
  );
  final lost = Session(
    id: 'c',
    title: 'Perdu',
    audience: Audience.children,
    sheetId: SheetId('inconnue-9'),
  );

  Future<void> pump(
    WidgetTester tester,
    List<Session> sessions, {
    void Function(SheetId, Audience)? onOpenSheet,
    VoidCallback? onChooseSheet,
    void Function(SheetId, Audience, String)? onLaunchSheet,
    ValueChanged<Session>? onDelete,
  }) => pumpUi(
    tester,
    SessionList(
      sessions: sessions,
      sheetOptions: [option],
      onOpenSheet: onOpenSheet ?? (_, _) {},
      onChooseSheet: onChooseSheet ?? () {},
      onLaunchSheet: onLaunchSheet ?? (_, _, _) {},
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
    expect(find.text('Children · 90 min'), findsOneWidget);
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
    expect(find.text('Adults · 120 min'), findsOneWidget);
  });

  testWidgets('shows a vanished catalogue session as unavailable', (
    tester,
  ) async {
    await pump(tester, [lost]);

    expect(find.text('Catalogue session unavailable'), findsOneWidget);
    expect(find.text('Choose a session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('deleting a planned session', () {
    testWidgets('offers no delete action without a handler', (tester) async {
      await pump(tester, [linked]);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('asks to confirm, then deletes that session', (tester) async {
      final deleted = <Session>[];
      await pump(tester, [free, linked], onDelete: deleted.add);

      await tester.tap(find.byTooltip('Delete session ${linked.title}'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this planned session?'), findsOneWidget);
      expect(deleted, isEmpty);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(deleted, [linked]);
    });

    testWidgets('keeps the session when the confirmation is cancelled', (
      tester,
    ) async {
      final deleted = <Session>[];
      await pump(tester, [linked], onDelete: deleted.add);

      await tester.tap(find.byTooltip('Delete session ${linked.title}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleted, isEmpty);
      expect(find.text('Delete this planned session?'), findsNothing);
    });
  });
}
