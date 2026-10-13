import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the phase minutes add up to {90}
///
/// Les en-têtes de phase (`phase:<nom>`) se terminent par « · N min ».
Future<void> thePhaseMinutesAddUpTo(WidgetTester tester, int total) async {
  final headings = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('phase:'),
    description: 'en-tête de phase',
  );
  expect(headings, findsNWidgets(5));
  var sum = 0;
  for (final heading in tester.widgetList<Text>(headings)) {
    final match = RegExp(r'(\d+) min$').firstMatch(heading.data!);
    expect(match, isNotNull, reason: 'minutes absentes de « ${heading.data} »');
    sum += int.parse(match!.group(1)!);
  }
  expect(sum, total);
}
