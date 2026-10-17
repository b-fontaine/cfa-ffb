import 'package:flutter_test/flutter_test.dart';

import '../support/pdf_preview.dart';

/// Usage: the PDF preview has at least {2} pages
Future<void> thePdfPreviewHasAtLeastPages(
  WidgetTester tester,
  int pages,
) async {
  expect(previewDocument(tester).pages.length, greaterThanOrEqualTo(pages));
}
