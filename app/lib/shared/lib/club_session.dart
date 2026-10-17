import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';

/// Qui agit, dans quel club, avec quel rôle et quel périmètre : ce que lit un
/// cas d'usage de club au moment de l'appel (jamais figé dans un singleton).
class ClubSession {
  const ClubSession({
    required this.user,
    required this.club,
    required this.role,
    required this.groupIds,
    required this.studentIds,
  });

  final UserId user;
  final ClubId club;
  final Role role;
  final List<GroupId> groupIds;
  final List<StudentId> studentIds;

  /// Vrai si le rôle a la capacité [capability].
  bool can(Capability capability) => role.can(capability);
}

/// La session courante, ou `InvariantViolation(actionNotAllowed)` si personne
/// n'est connecté ou si aucun club n'est actif. Avec [capability], le rôle
/// doit aussi l'avoir : l'interface ne propose pas ce que le rôle ne peut pas
/// faire, et un cas d'usage appelé quand même refuse (les règles du serveur
/// sont le garde de fond).
ClubSession requireClubSession(
  ActiveClubScope scope,
  CurrentUser user, {
  Capability? capability,
}) {
  final id = user.id;
  final club = scope.clubId;
  final role = scope.role;
  if (id == null || club == null || role == null) {
    throw const InvariantViolation(InvariantCode.actionNotAllowed);
  }
  if (capability != null && !role.can(capability)) {
    throw const InvariantViolation(InvariantCode.actionNotAllowed);
  }
  return ClubSession(
    user: id,
    club: club,
    role: role,
    groupIds: scope.groupIds,
    studentIds: scope.studentIds,
  );
}

/// L'administrateur connecté, ou `InvariantViolation(actionNotAllowed)` : les
/// cas d'usage d'« Administration » n'exigent aucun club actif (un
/// administrateur sans club doit pouvoir créer le premier).
UserId requireAdmin(CurrentUser user) {
  final id = user.id;
  if (id == null || !user.isAdmin) {
    throw const InvariantViolation(InvariantCode.actionNotAllowed);
  }
  return id;
}
