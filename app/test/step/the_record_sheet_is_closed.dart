import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the record sheet is closed
Future<void> theRecordSheetIsClosed(WidgetTester tester) async {
  expect(find.byKey(const ValueKey('record-sheet')), findsNothing);
}
