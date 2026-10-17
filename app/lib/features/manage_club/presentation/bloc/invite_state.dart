import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/features/manage_club/domain/invitable_students.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_state.freezed.dart';

/// Où en est le chargement du formulaire d'invitation.
enum InviteLoad { loading, ready, failed }

/// État du formulaire « Inviter quelqu'un ».
@freezed
abstract class InviteState with _$InviteState {
  const factory InviteState({
    @Default(InviteLoad.loading) InviteLoad load,

    /// Les rôles que la personne connectée peut inviter.
    @Default(<Role>[]) List<Role> roles,
    Role? role,

    /// Élèves invitables (un enseignant : ceux de ses groupes seulement).
    @Default(<InvitableStudent>[]) List<InvitableStudent> students,

    /// Groupes confiables à un enseignant invité (directeur, administrateur).
    @Default(<Group>[]) List<Group> groups,
    @Default(<GroupId>{}) Set<GroupId> selectedGroups,
    @Default(<StudentId>{}) Set<StudentId> selectedStudents,
    @Default(false) bool ageConfirmed,
    @Default(false) bool submitting,

    /// Dernier échec (chargement ou création), effacé par l'action suivante.
    Failure? failure,

    /// L'invitation créée : le formulaire laisse place au code à remettre.
    Invitation? issued,
  }) = _InviteState;
}
