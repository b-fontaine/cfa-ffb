import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/sign_in/domain/pending_invitations.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the invitation code {'TEACHERCODE'} is held for {'new@example.org'}
///
/// L'inscription a gardé ce code sur l'appareil sous le compte (point
/// d'extension de FB2, consommé en FB3).
Future<void> theInvitationCodeIsHeldFor(
  WidgetTester tester,
  String code,
  String email,
) async {
  await UiWorld.prepare(tester);
  final account = UiWorld.auth.accountOf(email)!;
  await getIt<PendingInvitations>().hold(
    account.id,
    InvitationCode.tryParse(code)!,
  );
}
