import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see {10} student rows on the screen
///
/// Les [count] lignes d'élèves sont présentes et leur bas tient dans la
/// hauteur de l'écran, sans défilement.
Future<void> iSeeStudentRowsOnTheScreen(WidgetTester tester, num count) async {
  final rows = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return widget is KeyedSubtree &&
        key is ValueKey<String> &&
        key.value.startsWith('pass-card-');
  });
  expect(rows, findsNWidgets(count.toInt()));
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (final element in rows.evaluate()) {
    final bottom = tester.getBottomLeft(find.byWidget(element.widget)).dy;
    expect(bottom, lessThanOrEqualTo(height), reason: 'ligne hors écran');
  }
}
