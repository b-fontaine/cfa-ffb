import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the saved PDF is named {'session-demi-bille-1-children.pdf'}
Future<void> theSavedPdfIsNamed(WidgetTester tester, String name) async {
  final saved = UiWorld.pdfFiles.lastSaved;
  expect(saved, isNotNull, reason: 'aucun PDF enregistré');
  expect(saved!.fileName, name);
}
