import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/theme/app_color_schemes.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

Color _background(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(AppAlert),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('attention alert shows a label, an icon and the message', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const AppAlert(level: AlertLevel.attention, message: 'Check the date.'),
    );

    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Check the date.'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(_background(tester), StatusColors.light.attention);
  });

  testWidgets('persistent alert uses the error container', (tester) async {
    await pumpUi(
      tester,
      const AppAlert(level: AlertLevel.persistent, message: 'Fix the score.'),
    );

    expect(find.text('Action needed'), findsOneWidget);
    expect(find.text('Fix the score.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(_background(tester), AppColorSchemes.light.errorContainer);
  });

  testWidgets('labels are localized', (tester) async {
    await pumpUi(
      tester,
      const AppAlert(level: AlertLevel.persistent, message: 'm'),
      locale: const Locale('fr'),
    );

    expect(find.text('À traiter'), findsOneWidget);
  });

  testWidgets('falls back to the default palette without the extension', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const AppAlert(level: AlertLevel.attention, message: 'm'),
      theme: ThemeData(),
    );

    expect(_background(tester), StatusColors.light.attention);
  });
}
