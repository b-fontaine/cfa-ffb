import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/sign_in/domain/pending_invitations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the invitation code {'ABCDEFGHJKMN'} is kept for {'new@example.org'}
///
/// Point d'extension de FB3 : le code est gardé sur l'appareil, sous le compte
/// créé ; rien n'est consommé.
Future<void> theInvitationCodeIsKeptFor(
  WidgetTester tester,
  String code,
  String email,
) async {
  final account = UiWorld.auth.accountOf(email)!;
  final kept = await getIt<PendingInvitations>().read(account.id);
  expect(kept?.value, code);
}
