import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Les clubs d'un compte ne peuvent pas être lus (réseau, service).
class MembershipsUnavailable implements Exception {
  const MembershipsUnavailable([this.detail]);

  final String? detail;

  @override
  String toString() => 'MembershipsUnavailable(${detail ?? ''})';
}

/// Le serveur **refuse** de lire les clubs d'un compte (règle de sécurité,
/// index manquant) : un problème d'accès ou de configuration, que réessayer ne
/// corrige pas, à distinguer de [MembershipsUnavailable] (réseau, service).
///
/// Ne porte aucun identifiant de compte : le détail est technique.
class MembershipsDenied implements Exception {
  const MembershipsDenied([this.detail]);

  final String? detail;

  @override
  String toString() => 'MembershipsDenied(${detail ?? ''})';
}

/// Un document `clubs/{club}/members/{uid}` du compte, **sans le nom du
/// club** : `role` est `null` s'il est illisible. Sert à la suppression d'un
/// compte (FB8 partie B), qui retire aussi le `member` d'un club supprimé ou
/// sans nom, que `MembershipsSource.membershipsOf` ne liste pas.
typedef OwnMember = ({ClubId clubId, Role? role});

/// Port de lecture des appartenances d'un compte (ADR 0024).
///
/// Implémentation : `StoreMembershipsSource` (documents `members` lus par une
/// requête de groupe de collections, plus les clubs que lit un administrateur).
abstract interface class MembershipsSource {
  /// Les clubs de [user], avec son rôle et son périmètre dans chacun ; liste
  /// vide si le compte n'a aucun `member` (et n'est pas administrateur).
  /// Lève [MembershipsUnavailable] si la lecture est impossible (réseau), et
  /// [MembershipsDenied] si le serveur la refuse (règle, index).
  ///
  /// Un administrateur voit **tous** les clubs, avec le rôle `admin` dans ceux
  /// où il n'a pas de `member` (le rôle de club l'emporte, ordre des règles).
  Future<List<ClubMembership>> membershipsOf(UserId user);

  /// Vrai si [user] est administrateur de l'application (document
  /// `admins/{uid}`, créé en console). Lève [MembershipsUnavailable] si la
  /// lecture est impossible, [MembershipsDenied] si le serveur la refuse.
  Future<bool> isAdmin(UserId user);

  /// **Tous** les `members` de [user], où qu'ils soient : y compris dans un
  /// club supprimé (Firestore ne supprime pas les sous-collections) ou sans
  /// nom lisible. Lus **au serveur**, jamais dans le cache : la suppression
  /// d'un compte ne supprime son compte d'authentification qu'une fois sûre
  /// qu'il n'en reste aucun. Lève [MembershipsUnavailable] (réseau, hors
  /// ligne) ou [MembershipsDenied] (règle, index).
  Future<List<OwnMember>> ownMembers(UserId user);
}
