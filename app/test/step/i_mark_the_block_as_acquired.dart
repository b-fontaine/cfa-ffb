import 'package:flutter_test/flutter_test.dart';

/// Usage: I mark the block {'Posture, visée et coup de queue'} as acquired
///
/// Ouvre le menu ⋮ de la ligne du bloc (son nom porte le titre du bloc) puis
/// choisit « Mark block as acquired ».
Future<void> iMarkTheBlockAsAcquired(WidgetTester tester, String block) async {
  final menu = find.byTooltip('Placement actions: $block');
  expect(menu, findsOneWidget);
  await tester.ensureVisible(menu);
  await tester.pumpAndSettle();
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mark block as acquired'));
  await tester.pumpAndSettle();
}
