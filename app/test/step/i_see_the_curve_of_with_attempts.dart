import 'package:billard_cfa/shared/ui/progress_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the curve of {'puissance 1'} with {3} attempts
Future<void> iSeeTheCurveOfWithAttempts(
  WidgetTester tester,
  String exercise,
  num count,
) async {
  final finder = find.byKey(ValueKey('curve-${exercise.replaceAll(' ', '-')}'));
  expect(finder, findsOneWidget);
  expect(tester.widget<ProgressChart>(finder).points, hasLength(count.toInt()));
}
