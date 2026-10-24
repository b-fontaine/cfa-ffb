import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/account_deletion_world.dart';
import '../support/ui_world.dart';

/// Usage: {'coach@example.org'} issued a waiting invitation from this device
/// in the club {'Test club'}
///
/// Une invitation de parent (une fiche, un groupe), valable encore un jour,
/// créée par ce compte : sur le serveur (`invitations/{code}`) et dans le journal local de
/// l'appareil, comme après « Inviter ».
Future<void> issuedAWaitingInvitationFromThisDeviceInTheClub(
  WidgetTester tester,
  String email,
  String club,
) async {
  await UiWorld.prepare(tester);
  final account = UiWorld.auth.accountOf(email)!;
  final clubId = UiWorld.clubIdOf(club);
  const code = 'ABCDEFGHJKLMNPQR';
  final created = UiWorld.today;
  final expires = created.add(const Duration(days: 1));
  UiWorld.documents.seed('invitations/$code', {
    'clubId': clubId.value,
    'role': Role.guardian.name,
    'groupIds': <Object?>['g-children'],
    'studentIds': <Object?>['s-lea'],
    'createdBy': account.id.value,
    'createdAt': created,
    'expiresAt': expires,
    'used': false,
  });
  await tester.runAsync(
    () => getIt<InvitationLog>().add(
      account.id,
      clubId,
      IssuedInvitation(
        code: InvitationCode.tryParse(code)!,
        role: Role.guardian,
        createdAt: created,
        expiresAt: expires,
      ),
    ),
  );
  AccountDeletionWorld.rememberInvitation(email, code);
}
