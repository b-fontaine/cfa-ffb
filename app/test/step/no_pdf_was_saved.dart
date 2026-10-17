import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: no PDF was saved
Future<void> noPdfWasSaved(WidgetTester tester) async {
  expect(UiWorld.pdfFiles.saved, isEmpty);
}
