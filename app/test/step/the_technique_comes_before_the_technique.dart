import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the technique {'rebond-bande'} comes before the technique
/// {'rejet-naturel'}
Future<void> theTechniqueComesBeforeTheTechnique(
  WidgetTester tester,
  String first,
  String second,
) async {
  final a = find.byKey(ValueKey('technique:$first'));
  final b = find.byKey(ValueKey('technique:$second'));
  expect(a, findsOneWidget);
  expect(b, findsOneWidget);
  expect(
    tester.getTopLeft(a).dy,
    lessThan(tester.getTopLeft(b).dy),
    reason: '$first doit précéder $second',
  );
}
