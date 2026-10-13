import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the presentation is open
Future<void> thePresentationIsOpen(WidgetTester tester) async {
  expect(find.byKey(const ValueKey('presentation')), findsOneWidget);
}
