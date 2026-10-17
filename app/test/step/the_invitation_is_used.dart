import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the invitation {'GUARDIANCODE'} is used
Future<void> theInvitationIsUsed(WidgetTester tester, String code) async {
  final stored = UiWorld.documents.read('invitations/$code');
  expect(stored, isNotNull);
  expect(stored!['used'], isTrue);
  expect(stored['usedBy'], isNotNull);
}
