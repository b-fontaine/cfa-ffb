import 'package:flutter_test/flutter_test.dart';

import 'the_clipboard_is_available.dart';

/// Usage: the clipboard holds {'Proposal to review: …'}
Future<void> theClipboardHolds(WidgetTester tester, String text) async {
  expect(copiedText, text);
}
