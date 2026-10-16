import 'package:flutter_test/flutter_test.dart';

import 'i_open_the_guide_menu.dart';

/// Usage: I end the guided session
///
/// Choisit « End session » dans le menu ⋮ du guide : la confirmation suit
/// (l'étape « Confirm » ou « Cancel » est écrite à part).
Future<void> iEndTheGuidedSession(WidgetTester tester) async {
  await iOpenTheGuideMenu(tester);
  await tester.tap(find.text('End session'));
  await tester.pumpAndSettle();
}
