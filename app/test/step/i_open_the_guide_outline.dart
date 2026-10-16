import 'package:flutter_test/flutter_test.dart';

import 'i_open_the_guide_menu.dart';

/// Usage: I open the guide outline
///
/// Ouvre le sommaire par le menu ⋮ de la séance guidée.
Future<void> iOpenTheGuideOutline(WidgetTester tester) async {
  await iOpenTheGuideMenu(tester);
  await tester.tap(find.text('Outline'));
  await tester.pumpAndSettle();
}
