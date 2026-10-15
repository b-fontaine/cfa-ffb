import 'package:billard_cfa/pages/more/presentation/more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/ui/pump_ui.dart';

void main() {
  testWidgets('lists the backup and opens it', (tester) async {
    var opened = 0;
    await pumpUi(tester, MorePage(onOpenBackup: () => opened++));

    expect(find.text('More'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    await tester.tap(find.text('Backup'));

    expect(opened, 1);
  });

  testWidgets('offers only entries that lead somewhere', (tester) async {
    await pumpUi(tester, MorePage(onOpenBackup: () {}));

    expect(find.byType(ListTile), findsOneWidget);
    expect(
      tester.getSize(find.byType(ListTile)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('is in French on a French device', (tester) async {
    await pumpUi(
      tester,
      MorePage(onOpenBackup: () {}),
      locale: const Locale('fr'),
    );

    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('Sauvegarde'), findsOneWidget);
  });
}
