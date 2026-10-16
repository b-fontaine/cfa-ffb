import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'i_open_the_guide_menu.dart';

/// Usage: the guide is in {'review'} mode
///
/// Ce que voit l'animateur : la case « Mode relecture » du menu ⋮ est cochée
/// en Relecture et décochée en Mener. Le menu est refermé ensuite.
Future<void> theGuideIsInMode(WidgetTester tester, String mode) async {
  if (mode != 'review' && mode != 'lead') {
    throw ArgumentError('mode inconnu : $mode');
  }
  await iOpenTheGuideMenu(tester);
  final item = find.ancestor(
    of: find.text('Review mode'),
    matching: find.byType(CheckedPopupMenuItem<int>),
  );
  expect(item, findsOneWidget, reason: 'case « Review mode » absente');
  expect(
    tester.widget<CheckedPopupMenuItem<int>>(item).checked,
    mode == 'review',
    reason: 'case « Review mode » : mode $mode attendu',
  );
  await tester.tapAt(const Offset(1, 1));
  await tester.pumpAndSettle();
  expect(find.text('Review mode'), findsNothing, reason: 'menu resté ouvert');
}
