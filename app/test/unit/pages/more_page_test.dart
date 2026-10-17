import 'package:billard_cfa/pages/more/presentation/more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/ui/pump_ui.dart';

void main() {
  testWidgets('lists the backup and opens it', (tester) async {
    var opened = 0;
    await pumpUi(
      tester,
      MorePage(
        onOpenBackup: () => opened++,
        onOpenSettings: () {},
        onOpenSeasons: () {},
      ),
    );

    expect(find.text('More'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    await tester.tap(find.text('Backup'));

    expect(opened, 1);
  });

  testWidgets('lists the settings and opens them', (tester) async {
    var opened = 0;
    await pumpUi(
      tester,
      MorePage(
        onOpenBackup: () {},
        onOpenSettings: () => opened++,
        onOpenSeasons: () {},
      ),
    );

    await tester.tap(find.text('Settings'));

    expect(opened, 1);
  });

  testWidgets('offers only entries that lead somewhere', (tester) async {
    await pumpUi(
      tester,
      MorePage(
        onOpenBackup: () {},
        onOpenSettings: () {},
        onOpenSeasons: () {},
      ),
    );

    expect(find.byType(ListTile), findsNWidgets(3));
    for (final tile in tester.widgetList(find.byType(ListTile))) {
      expect(tile, isA<ListTile>().having((t) => t.onTap, 'onTap', isNotNull));
    }
    expect(
      tester.getSize(find.byType(ListTile).first).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('is in French on a French device', (tester) async {
    await pumpUi(
      tester,
      MorePage(
        onOpenBackup: () {},
        onOpenSettings: () {},
        onOpenSeasons: () {},
      ),
      locale: const Locale('fr'),
    );

    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('Sauvegarde'), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);
  });

  testWidgets('lists the past seasons and opens them', (tester) async {
    var opened = 0;
    await pumpUi(
      tester,
      MorePage(
        onOpenBackup: () {},
        onOpenSettings: () {},
        onOpenSeasons: () => opened++,
      ),
    );

    expect(
      find.text('Figures of closed seasons, without any name'),
      findsOneWidget,
    );
    await tester.tap(find.text('Past seasons'));

    expect(opened, 1);
  });

  testWidgets('shows the account section when there is one', (tester) async {
    await pumpUi(
      tester,
      MorePage(
        onOpenBackup: () {},
        onOpenSettings: () {},
        onOpenSeasons: () {},
        account: const Text('account section'),
      ),
    );

    expect(find.text('account section'), findsOneWidget);
    expect(find.text('Switch club'), findsNothing);
  });

  testWidgets('offers to switch club only when a callback is given', (
    tester,
  ) async {
    var switched = 0;
    await pumpUi(
      tester,
      MorePage(
        onOpenBackup: () {},
        onOpenSettings: () {},
        onOpenSeasons: () {},
        onSwitchClub: () => switched++,
      ),
    );

    await tester.tap(find.text('Switch club'));

    expect(switched, 1);
  });

  testWidgets('shows only the entries that were given an action', (
    tester,
  ) async {
    await pumpUi(tester, const MorePage());

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Backup'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('My club'), findsNothing);
    expect(find.text('Administration'), findsNothing);
  });

  testWidgets('My club and Administration lead where they say', (tester) async {
    var club = 0;
    var administration = 0;
    await pumpUi(
      tester,
      MorePage(
        onOpenClub: () => club++,
        onOpenAdministration: () => administration++,
      ),
    );

    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.tap(find.text('My club'));
    await tester.tap(find.text('Administration'));

    expect([club, administration], [1, 1]);
    expect(
      tester.getSize(find.byType(ListTile).first).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets(
    "a teacher's More has the backup and seasons, never the settings",
    (tester) async {
      await pumpUi(
        tester,
        MorePage(onOpenBackup: () {}, onOpenSeasons: () {}, onOpenClub: () {}),
      );

      expect(find.text('Backup'), findsOneWidget);
      expect(find.text('Past seasons'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    },
  );
}
