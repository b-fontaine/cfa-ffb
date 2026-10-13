import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the legend of {6} marks
Future<void> iSeeTheLegendOfMarks(WidgetTester tester, num count) async {
  final legend = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('player-legend-'),
  );

  expect(legend, findsNWidgets(count.toInt()));
}
