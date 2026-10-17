import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the PDF was sent to print
Future<void> thePdfWasSentToPrint(WidgetTester tester) async {
  expect(UiWorld.pdfFiles.printed, hasLength(1));
  expect(UiWorld.pdfFiles.printed.single.fileName, endsWith('.pdf'));
}
