import 'package:billard_cfa/entities/invitation/domain/invitation_repository.dart';
import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:billard_cfa/features/sign_in/domain/pending_invitations.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : rejoindre un club avec un code d'invitation (ADR 0024,
/// décision 24).
///
/// Le code saisi est normalisé (`AuthFailure(invalidInvitationCode)` si sa
/// forme n'est pas celle d'un code), puis `InvitationRepository.accept` crée le
/// `member` et consomme l'invitation dans **un seul lot** ; une invitation
/// introuvable, expirée ou déjà utilisée lève `InvitationFailure`, une panne du
/// service `ServiceFailure`, un nom vide ou trop long `InvariantViolation`. Le
/// code gardé à l'inscription n'est effacé qu'en cas de succès : après un
/// échec, l'utilisateur peut corriger et réessayer.
@injectable
class AcceptInvitation {
  AcceptInvitation(this._invitations, this._pending, this._user);

  final InvitationRepository _invitations;
  final PendingInvitations _pending;
  final CurrentUser _user;

  Future<void> call({required String code, required String displayName}) async {
    final user = _user.id;
    if (user == null) {
      throw const InvariantViolation(InvariantCode.actionNotAllowed);
    }
    await _invitations.accept(
      code: parseInvitationCode(code),
      user: user,
      displayName: displayName,
    );
    await _pending.clear(user);
  }
}
