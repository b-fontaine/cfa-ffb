import 'package:billard_cfa/entities/club/domain/club_repository.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_code_source.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_repository.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : inviter le directeur d'un club (administrateur seulement,
/// ADR 0024 décision 24). Invitation de 48 heures, sans groupe ni fiche ; le
/// code est retenu sur l'appareil pour être copié ou révoqué.
@injectable
class InviteDirector {
  InviteDirector(
    this._clubs,
    this._invitations,
    this._codes,
    this._issued,
    this._clock,
    this._user,
  );

  final ClubRepository _clubs;
  final InvitationRepository _invitations;
  final InvitationCodeSource _codes;
  final IssuedInvitations _issued;
  final Clock _clock;
  final CurrentUser _user;

  Future<Result<Invitation>> call(ClubId club) => runGuarded(() async {
    final admin = requireAdmin(_user);
    if (await _clubs.byId(club) == null) throw NotFound('club', club.value);
    final invitation = Invitation.issue(
      code: _codes.next(),
      issuer: Role.admin,
      issuerId: admin,
      clubId: club,
      role: Role.director,
      now: _clock.now(),
    );
    await _invitations.create(invitation);
    await _issued.remember(admin, club, invitation);
    return invitation;
  });
}
