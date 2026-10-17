import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'invitation.freezed.dart';

/// Où en est une invitation à un instant donné.
enum InvitationStatus {
  /// Valable : ni utilisée ni expirée.
  waiting,

  /// Consommée par un compte.
  used,

  /// Expirée sans avoir servi.
  expired,
}

/// Règles de durée et de forme des invitations (ADR 0024, décision 24).
abstract final class InvitationPolicy {
  /// Durée de validité d'une invitation de [target] : **48 heures** pour un
  /// rôle plus puissant (enseignant, directeur), **7 jours** pour un élève ou
  /// un parent.
  static Duration validityOf(Role target) => switch (target) {
    Role.teacher || Role.director || Role.admin => const Duration(hours: 48),
    Role.student || Role.guardian => const Duration(days: 7),
  };

  /// Nombre maximal de fiches liées à un parent (identique à
  /// `firestore.rules`).
  static const maxChildren = 4;

  /// Vrai si [issuer] peut inviter [target] dans son club : l'enseignant
  /// invite élèves et parents, le directeur aussi les enseignants (jamais un
  /// directeur : c'est l'administrateur qui invite un directeur).
  static bool canIssue(Role issuer, Role target) =>
      issuer.invitableRoles.contains(target) ||
      (issuer == Role.admin && target == Role.director);
}

/// Une invitation : un code à usage unique lié à un rôle, un club et un
/// périmètre (groupes pour un enseignant ; groupes et fiches pour un élève ou
/// un parent). L'inscription est fermée : sans code, pas de compte dans un
/// club.
@freezed
abstract class Invitation with _$Invitation {
  factory Invitation({
    required InvitationCode code,
    required ClubId clubId,
    required Role role,
    required UserId createdBy,
    required DateTime createdAt,
    required DateTime expiresAt,
    @Default(<GroupId>[]) List<GroupId> groupIds,
    @Default(<StudentId>[]) List<StudentId> studentIds,
    @Default(false) bool used,
    UserId? usedBy,
  }) = _Invitation;

  Invitation._() {
    final valid =
        role != Role.admin &&
        expiresAt.isAfter(createdAt) &&
        switch (role) {
          Role.student => studentIds.length == 1 && groupIds.isNotEmpty,
          Role.guardian =>
            studentIds.isNotEmpty &&
                studentIds.length <= InvitationPolicy.maxChildren &&
                groupIds.isNotEmpty,
          Role.teacher => studentIds.isEmpty,
          Role.director => studentIds.isEmpty && groupIds.isEmpty,
          Role.admin => false,
        };
    if (!valid) throw const InvariantViolation(InvariantCode.invalidInvitation);
  }

  /// Une invitation émise à [now] par [issuerId] (de rôle [issuer]) : durée de
  /// validité de [InvitationPolicy.validityOf], refusée si [issuer] ne peut pas
  /// inviter [role].
  factory Invitation.issue({
    required InvitationCode code,
    required Role issuer,
    required UserId issuerId,
    required ClubId clubId,
    required Role role,
    required DateTime now,
    List<GroupId> groupIds = const [],
    List<StudentId> studentIds = const [],
  }) {
    if (!InvitationPolicy.canIssue(issuer, role)) {
      throw const InvariantViolation(InvariantCode.actionNotAllowed);
    }
    return Invitation(
      code: code,
      clubId: clubId,
      role: role,
      createdBy: issuerId,
      createdAt: now,
      expiresAt: now.add(InvitationPolicy.validityOf(role)),
      groupIds: groupIds,
      studentIds: studentIds,
    );
  }

  /// L'état de l'invitation à [now] (« utilisée » l'emporte sur « expirée »).
  InvitationStatus statusAt(DateTime now) {
    if (used) return InvitationStatus.used;
    return now.isBefore(expiresAt)
        ? InvitationStatus.waiting
        : InvitationStatus.expired;
  }
}
