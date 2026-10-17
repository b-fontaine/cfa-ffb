import 'package:flutter_test/flutter_test.dart';

import '../support/pdf_preview.dart';

/// Usage: the PDF preview mentions {'text'}
Future<void> thePdfPreviewMentions(WidgetTester tester, String text) async {
  expect(previewText(tester), contains(text));
}
