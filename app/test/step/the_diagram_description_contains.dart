import 'package:flutter_test/flutter_test.dart';

/// Usage: the diagram description contains {'text'}
Future<void> theDiagramDescriptionContains(
  WidgetTester tester,
  String text,
) async {
  expect(find.bySemanticsLabel(RegExp(RegExp.escape(text))), findsOneWidget);
}
