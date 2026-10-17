import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : révoquer une invitation de directeur (administrateur
/// seulement).
@injectable
class RevokeDirectorInvitation {
  RevokeDirectorInvitation(this._issued, this._user);

  final IssuedInvitations _issued;
  final CurrentUser _user;

  Future<Result<void>> call(ClubId club, InvitationCode code) =>
      runGuarded(() => _issued.revoke(requireAdmin(_user), club, code));
}
