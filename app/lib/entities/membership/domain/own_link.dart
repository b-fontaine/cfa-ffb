import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Ce que le serveur dit **maintenant** du lien d'un compte avec les fiches
/// d'un club : son propre `member` (FB6). La session ouverte n'est relue qu'à
/// la connexion : ce lien-ci sert à savoir si l'accès d'un parent ou d'un
/// élève a été retiré **depuis**.
final class OwnLink {
  const OwnLink({
    required this.role,
    required this.studentIds,
    required this.groupIds,
  });

  final Role role;
  final Set<StudentId> studentIds;
  final Set<GroupId> groupIds;
}
