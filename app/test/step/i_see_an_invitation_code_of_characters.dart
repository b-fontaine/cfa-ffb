import 'package:flutter_test/flutter_test.dart';

import '../support/invitation_world.dart';

/// Usage: I see an invitation code of {12} characters
Future<void> iSeeAnInvitationCodeOfCharacters(
  WidgetTester tester,
  num length,
) async {
  expect(shownInvitationCode(tester), hasLength(length.toInt()));
}
