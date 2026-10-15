import 'package:billard_cfa/pages/more/presentation/more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/ui/pump_ui.dart';

void main() {
  testWidgets('lists the backup and opens it', (tester) async {
    var opened = 0;
    await pumpUi(
      tester,
      MorePage(onOpenBackup: () => opened++, onOpenSettings: () {}),
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
      MorePage(onOpenBackup: () {}, onOpenSettings: () => opened++),
    );

    await tester.tap(find.text('Settings'));

    expect(opened, 1);
  });

  testWidgets('offers only entries that lead somewhere', (tester) async {
    await pumpUi(tester, MorePage(onOpenBackup: () {}, onOpenSettings: () {}));

    expect(find.byType(ListTile), findsNWidgets(2));
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
      MorePage(onOpenBackup: () {}, onOpenSettings: () {}),
      locale: const Locale('fr'),
    );

    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('Sauvegarde'), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);
  });
}
