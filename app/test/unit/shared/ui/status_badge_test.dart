import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('shows an icon and the label for every tone', (tester) async {
    const icons = {
      BadgeTone.success: Icons.check_circle_outline,
      BadgeTone.attention: Icons.warning_amber_rounded,
      BadgeTone.neutral: Icons.radio_button_unchecked,
    };
    for (final MapEntry(key: tone, value: icon) in icons.entries) {
      await pumpUi(tester, StatusBadge(tone: tone, label: tone.name));

      expect(find.text(tone.name), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
    }
  });

  testWidgets('uses the status colours of the theme', (tester) async {
    await pumpUi(
      tester,
      const StatusBadge(tone: BadgeTone.success, label: 'ok'),
    );

    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(StatusBadge),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, StatusColors.light.success);
  });
}
