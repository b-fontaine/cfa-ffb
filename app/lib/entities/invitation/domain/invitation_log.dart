import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';

/// Une invitation émise depuis cet appareil, telle que l'appareil s'en
/// souvient.
class IssuedInvitation {
  const IssuedInvitation({
    required this.code,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
  });

  final InvitationCode code;
  final Role role;
  final DateTime createdAt;
  final DateTime expiresAt;
}

/// Mémoire locale des invitations émises depuis cet appareil, **par compte et
/// par club**.
///
/// Les règles interdisent de **lister** les invitations (lecture par le code
/// seulement, contre l'énumération) : c'est donc l'appareil qui se souvient des
/// codes qu'il a créés, pour les montrer, les copier et les révoquer. Une
/// invitation créée sur un autre appareil n'y figure pas ; elle se révoque en
/// saisissant son code. Préférence locale (ADR 0024, décision 23) : jamais
/// envoyée au serveur, effacée à la déconnexion.
abstract interface class InvitationLog {
  /// Les invitations retenues pour [user] dans [club], les plus récentes
  /// d'abord (au plus [maxEntries]).
  Future<List<IssuedInvitation>> read(UserId user, ClubId club);

  Future<void> add(UserId user, ClubId club, IssuedInvitation invitation);

  Future<void> remove(UserId user, ClubId club, InvitationCode code);

  /// Oublie tout ce qui est retenu pour [user] (déconnexion).
  Future<void> clear(UserId user);

  static const maxEntries = 20;
}
