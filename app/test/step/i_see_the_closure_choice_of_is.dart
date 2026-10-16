import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the closure choice of {'Hugo'} is {'Erase'}
Future<void> iSeeTheClosureChoiceOfIs(
  WidgetTester tester,
  String name,
  String choice,
) async {
  final semantics = tester.ensureSemantics();
  expect(find.bySemanticsLabel('$name: $choice'), findsOneWidget);
  semantics.dispose();
}
