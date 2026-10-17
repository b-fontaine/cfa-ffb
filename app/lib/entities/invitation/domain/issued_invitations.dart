import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_repository.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:injectable/injectable.dart';

/// Une invitation émise depuis cet appareil et son état sur le serveur
/// (`null` : inconnu, le service est injoignable).
class IssuedInvitationStatus {
  const IssuedInvitationStatus(this.entry, this.status);

  final IssuedInvitation entry;
  final InvitationStatus? status;
}

/// Les invitations émises depuis cet appareil : le journal local
/// ([InvitationLog]) croisé avec l'état que le serveur connaît.
///
/// Les règles interdisent de **lister** les invitations (lecture par le code
/// seulement) : l'appareil se souvient des codes qu'il crée, les relit un par
/// un, oublie ceux qui n'existent plus (révoqués, purgés) et laisse leur état
/// inconnu quand le service est injoignable.
@injectable
class IssuedInvitations {
  IssuedInvitations(this._log, this._invitations, this._clock);

  final InvitationLog _log;
  final InvitationRepository _invitations;
  final Clock _clock;

  /// Retient [invitation] sur cet appareil pour [user] dans [club].
  Future<void> remember(UserId user, ClubId club, Invitation invitation) =>
      _log.add(
        user,
        club,
        IssuedInvitation(
          code: invitation.code,
          role: invitation.role,
          createdAt: invitation.createdAt,
          expiresAt: invitation.expiresAt,
        ),
      );

  /// Les invitations retenues, les plus récentes d'abord, avec leur état.
  Future<List<IssuedInvitationStatus>> statuses(
    UserId user,
    ClubId club,
  ) async {
    final entries = [...await _log.read(user, club)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final now = _clock.now();
    final result = <IssuedInvitationStatus>[];
    for (final entry in entries) {
      try {
        final invitation = await _invitations.find(entry.code);
        if (invitation == null) {
          await _log.remove(user, club, entry.code);
        } else {
          result.add(IssuedInvitationStatus(entry, invitation.statusAt(now)));
        }
      } on ServiceFailure {
        result.add(IssuedInvitationStatus(entry, null));
      }
    }
    return result;
  }

  /// Révoque l'invitation sur le serveur, puis l'oublie sur l'appareil (si la
  /// révocation échoue, le code reste pour une nouvelle tentative).
  Future<void> revoke(UserId user, ClubId club, InvitationCode code) async {
    await _invitations.revoke(code);
    await _log.remove(user, club, code);
  }
}
