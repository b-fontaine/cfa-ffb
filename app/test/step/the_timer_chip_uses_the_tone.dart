import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the timer chip uses the {'attention'} tone
///
/// Compare le fond du minuteur aux jetons du thème : `neutral` (surface),
/// `attention` (`StatusColors.attention`), `overdue` (`inverseSurface`, jamais
/// le rouge d'état : ADR 0010).
Future<void> theTimerChipUsesTheTone(WidgetTester tester, String tone) async {
  final theme = Theme.of(tester.element(find.byType(Scaffold).first));
  final status = theme.extension<StatusColors>()!;
  final expected = switch (tone) {
    'attention' => status.attention,
    'overdue' => theme.colorScheme.inverseSurface,
    _ => theme.colorScheme.surfaceContainerHighest,
  };
  final box = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey('timer-chip')),
  );
  expect((box.decoration as BoxDecoration).color, expected);
}
