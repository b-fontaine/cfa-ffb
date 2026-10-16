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
}
