import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les invitations de directeur émises depuis cet appareil pour
/// un club, avec leur état (administrateur seulement).
@injectable
class ListDirectorInvitations {
  ListDirectorInvitations(this._issued, this._user);

  final IssuedInvitations _issued;
  final CurrentUser _user;

  Future<Result<List<IssuedInvitationStatus>>> call(ClubId club) =>
      runGuarded(() => _issued.statuses(requireAdmin(_user), club));
}
