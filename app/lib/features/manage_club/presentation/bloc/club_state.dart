import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'club_state.freezed.dart';

/// Où en est le chargement de « Mon club ».
enum ClubStatus { loading, ready, failed }

/// État de « Mon club » : l'équipe et les familles (directeur et
/// administrateur seulement) et les invitations émises depuis cet appareil.
@freezed
abstract class ClubState with _$ClubState {
  const factory ClubState({
    /// Le rôle peut gérer le club (liste des membres, retrait, nom).
    @Default(false) bool canManage,
    @Default(ClubStatus.loading) ClubStatus status,
    @Default(<Member>[]) List<Member> members,

    /// Les membres que le compte connecté peut retirer (règle unique du
    /// domaine, `canRemoveMember`).
    @Default(<UserId>{}) Set<UserId> removableIds,
    @Default(<IssuedInvitationStatus>[])
    List<IssuedInvitationStatus> invitations,

    /// Dernier échec (chargement ou action) ; effacé par l'action suivante.
    Failure? failure,
  }) = _ClubState;

  const ClubState._();

  /// Vrai si le compte connecté peut retirer [member].
  bool removable(Member member) => removableIds.contains(member.uid);
}
