import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the control {'More failures before an alert'}
///
/// Un bouton à icône se trouve par son info-bulle ; la page défile jusqu'à lui.
Future<void> iTapTheControl(WidgetTester tester, String tooltip) async {
  final control = find.byTooltip(tooltip);
  expect(control, findsOneWidget, reason: 'contrôle « $tooltip » introuvable');
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}
