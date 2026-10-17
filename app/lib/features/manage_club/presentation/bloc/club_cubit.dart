import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/entities/membership/domain/member_removal.dart';
import 'package:billard_cfa/features/manage_club/domain/list_issued_invitations.dart';
import 'package:billard_cfa/features/manage_club/domain/list_members.dart';
import 'package:billard_cfa/features/manage_club/domain/remove_member.dart';
import 'package:billard_cfa/features/manage_club/domain/rename_club.dart';
import 'package:billard_cfa/features/manage_club/domain/revoke_invitation.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/club_state.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// « Mon club » : l'équipe et les familles (si le rôle gère le club) et les
/// invitations de cet appareil, avec leurs actions (retirer, révoquer,
/// renommer). Un échec d'action garde les listes et s'affiche ; la réussite
/// suivante l'efface.
@injectable
class ClubCubit extends Cubit<ClubState> {
  ClubCubit(
    this._listMembers,
    this._listInvitations,
    this._removeMember,
    this._revokeInvitation,
    this._renameClub,
    this._scope,
    this._user,
  ) : super(
        ClubState(canManage: _scope.role?.can(Capability.manageClub) ?? false),
      );

  final ListMembers _listMembers;
  final ListIssuedInvitations _listInvitations;
  final RemoveMember _removeMember;
  final RevokeInvitation _revokeInvitation;
  final RenameClub _renameClub;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  /// Charge (ou recharge) les listes.
  Future<void> load() async {
    final members = state.canManage
        ? await _listMembers()
        : const Ok(<Member>[]);
    final invitations = await _listInvitations();
    if (isClosed) return;
    final failure = switch ((members, invitations)) {
      (Err(:final failure), _) => failure,
      (_, Err(:final failure)) => failure,
      _ => null,
    };
    final loaded = switch (members) {
      Ok(:final value) => value,
      Err() => state.members,
    };
    emit(
      state.copyWith(
        status: failure == null ? ClubStatus.ready : ClubStatus.failed,
        members: loaded,
        removableIds: _removable(loaded),
        invitations: switch (invitations) {
          Ok(:final value) => value,
          Err() => state.invitations,
        },
        failure: failure,
      ),
    );
  }

  /// Les membres de [members] que le compte connecté peut retirer.
  Set<UserId> _removable(List<Member> members) {
    final role = _scope.role;
    final viewer = _user.id;
    if (role == null || viewer == null) return const {};
    return {
      for (final member in members)
        if (canRemoveMember(viewerRole: role, viewerId: viewer, member: member))
          member.uid,
    };
  }

  Future<void> removeMember(Member member) async {
    final result = await _removeMember(member);
    if (isClosed) return;
    switch (result) {
      case Ok():
        await load();
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> revoke(InvitationCode code) async {
    final result = await _revokeInvitation(code);
    if (isClosed) return;
    switch (result) {
      case Ok():
        await load();
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  /// Renomme le club ; `true` si le serveur a accepté (l'appelant relit alors
  /// la session pour afficher le nouveau nom).
  Future<bool> rename(String name) async {
    final result = await _renameClub(name);
    if (isClosed) return false;
    switch (result) {
      case Ok():
        emit(state.copyWith(failure: null));
        return true;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return false;
    }
  }
}
