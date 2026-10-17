import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/sign_in/domain/pending_invitations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: no invitation code is held for {'new@example.org'}
Future<void> noInvitationCodeIsHeldFor(
  WidgetTester tester,
  String email,
) async {
  final account = UiWorld.auth.accountOf(email)!;
  expect(await getIt<PendingInvitations>().read(account.id), isNull);
}
