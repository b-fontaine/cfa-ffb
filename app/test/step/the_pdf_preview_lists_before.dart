import 'package:flutter_test/flutter_test.dart';

import '../support/pdf_preview.dart';

/// Usage: the PDF preview lists {'Léa'} before {'Zoé'}
Future<void> thePdfPreviewListsBefore(
  WidgetTester tester,
  String first,
  String second,
) async {
  final lines = previewLines(tester);
  final a = lines.indexWhere((line) => line.contains(first));
  final b = lines.indexWhere((line) => line.contains(second));
  expect(a, greaterThanOrEqualTo(0));
  expect(b, greaterThan(a));
}
