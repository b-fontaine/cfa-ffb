import 'package:flutter_test/flutter_test.dart';

import '../support/invitation_world.dart';
import 'the_clipboard_is_available.dart';

/// Usage: the clipboard holds the invitation code
///
/// Le presse-papiers simulé contient le code affiché, sans tirets.
Future<void> theClipboardHoldsTheInvitationCode(WidgetTester tester) async {
  expect(copiedText, shownInvitationCode(tester));
}
