import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the invitation code no longer exists
///
/// Le dernier code créé pendant le scénario n'existe plus côté serveur
/// (révoqué).
Future<void> theInvitationCodeNoLongerExists(WidgetTester tester) async {
  final codes = [
    for (final path in UiWorld.documents.documents.keys)
      if (path.startsWith('invitations/')) path,
  ];
  expect(codes, isEmpty);
}
