import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/features/manage_club/domain/issue_invitation.dart';
import 'package:billard_cfa/features/manage_club/domain/list_invitable_groups.dart';
import 'package:billard_cfa/features/manage_club/domain/list_invitable_students.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_state.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Formulaire d'invitation : le rôle (parmi ceux que le rôle courant peut
/// inviter), puis les groupes d'un enseignant ou l'élève (ou les enfants) lié,
/// et la case « a 15 ans ou plus » pour un élève. Les règles de fond sont dans
/// `IssueInvitation` : le formulaire ne propose que ce qu'il accepte.
@injectable
class InviteCubit extends Cubit<InviteState> {
  InviteCubit(this._students, this._groups, this._issue, this._scope)
    : super(const InviteState());

  final ListInvitableStudents _students;
  final ListInvitableGroups _groups;
  final IssueInvitation _issue;
  final ActiveClubScope _scope;

  Future<void> load() async {
    final role = _scope.role;
    final roles = role == null ? const <Role>[] : role.invitableRoles;
    final students = await _students();
    final groups = role?.can(Capability.inviteTeachers) ?? false
        ? await _groups()
        : const Ok<List<Group>>([]);
    if (isClosed) return;
    final failure = switch ((students, groups)) {
      (Err(:final failure), _) => failure,
      (_, Err(:final failure)) => failure,
      _ => null,
    };
    emit(
      state.copyWith(
        load: failure == null ? InviteLoad.ready : InviteLoad.failed,
        roles: roles,
        students: switch (students) {
          Ok(:final value) => value,
          Err() => const [],
        },
        groups: switch (groups) {
          Ok(:final value) => value,
          Err() => const [],
        },
        failure: failure,
      ),
    );
  }

  /// Choisit le rôle invité ; les choix propres à un autre rôle sont oubliés.
  void selectRole(Role role) {
    if (!state.roles.contains(role) || state.submitting) return;
    emit(
      state.copyWith(
        role: role,
        selectedGroups: const {},
        selectedStudents: const {},
        ageConfirmed: false,
        failure: null,
      ),
    );
  }

  void toggleGroup(GroupId id) {
    final selected = {...state.selectedGroups};
    if (!selected.remove(id)) selected.add(id);
    emit(state.copyWith(selectedGroups: selected, failure: null));
  }

  /// Coche ou décoche un élève : un élève n'en admet qu'un (le nouveau
  /// remplace), un parent jusqu'à `InvitationPolicy.maxChildren`.
  void toggleStudent(StudentId id) {
    final selected = {...state.selectedStudents};
    if (!selected.remove(id)) {
      if (state.role == Role.student) selected.clear();
      if (selected.length < InvitationPolicy.maxChildren) selected.add(id);
    }
    emit(state.copyWith(selectedStudents: selected, failure: null));
  }

  void setAgeConfirmed({required bool value}) =>
      emit(state.copyWith(ageConfirmed: value, failure: null));

  Future<void> submit() async {
    final role = state.role;
    if (role == null || state.submitting) return;
    emit(state.copyWith(submitting: true, failure: null));
    final result = await _issue(
      role: role,
      groupIds: state.selectedGroups,
      studentIds: state.selectedStudents,
      ageConfirmed: state.ageConfirmed,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(submitting: false, issued: value));
      case Err(:final failure):
        emit(state.copyWith(submitting: false, failure: failure));
    }
  }

  /// Revient au formulaire vide pour inviter quelqu'un d'autre.
  void another() => emit(
    state.copyWith(
      issued: null,
      role: null,
      selectedGroups: const {},
      selectedStudents: const {},
      ageConfirmed: false,
      failure: null,
    ),
  );
}
