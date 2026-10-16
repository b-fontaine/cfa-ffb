import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'i_open_the_guide_menu.dart';

/// Usage: I switch the guide to {'review'} mode
///
/// Le menu ⋮ propose « Review mode », une case à cocher : cocher bascule en
/// Relecture, décocher revient à Mener.
Future<void> iSwitchTheGuideToMode(WidgetTester tester, String mode) async {
  await iOpenTheGuideMenu(tester);
  await tester.tap(
    find.ancestor(
      of: find.text('Review mode'),
      matching: find.byType(CheckedPopupMenuItem<int>),
    ),
  );
  await tester.pumpAndSettle();
}
