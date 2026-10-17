import 'package:flutter_test/flutter_test.dart';

import '../support/pdf_preview.dart';

/// Usage: the PDF preview does not mention {'text'}
Future<void> thePdfPreviewDoesNotMention(
  WidgetTester tester,
  String text,
) async {
  expect(previewText(tester), isNot(contains(text)));
}
