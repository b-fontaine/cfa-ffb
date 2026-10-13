import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the phases appear in the order
/// {'welcome,notionAndInitiation,training,game,review'}
Future<void> thePhasesAppearInTheOrder(
  WidgetTester tester,
  String phases,
) async {
  final names = phases.split(',');
  double? previous;
  for (final name in names) {
    final finder = find.byKey(ValueKey('phase:$name'));
    expect(finder, findsOneWidget, reason: 'phase $name absente');
    final top = tester.getTopLeft(finder).dy;
    if (previous != null) {
      expect(top, greaterThan(previous), reason: 'phase $name hors ordre');
    }
    previous = top;
  }
}
