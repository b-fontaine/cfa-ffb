import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'i_open_the_guide_menu.dart';

/// Usage: I see the session audience {'Children · 90 min'}
///
/// Le public et la durée sont dans la feuille « The session » du menu ⋮ ;
/// elle est refermée ensuite pour la suite du scénario.
Future<void> iSeeTheSessionAudience(WidgetTester tester, String text) async {
  await iOpenTheGuideMenu(tester);
  await tester.tap(find.text('The session'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('session-info')), findsOneWidget);
  expect(
    find.descendant(
      of: find.byKey(const ValueKey('session-info')),
      matching: find.text(text),
    ),
    findsOneWidget,
  );
  // Un tap sur le voile referme la feuille.
  await tester.tapAt(const Offset(2, 2));
  await tester.pumpAndSettle();
}
