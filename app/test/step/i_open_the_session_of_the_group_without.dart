import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the session of the group {'Children group'} without {'Hugo'}
///
/// L'onglet Résultats est l'historique : la saisie s'ouvre par
/// « New session ».
Future<void> iOpenTheSessionOfTheGroupWithout(
  WidgetTester tester,
  String group,
  String name,
) async {
  await tester.tap(find.text('Results'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New session'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(group));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open the session'));
  await tester.pumpAndSettle();
}
