import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Les clubs d'un compte ne peuvent pas être lus (réseau, service).
class MembershipsUnavailable implements Exception {
  const MembershipsUnavailable([this.detail]);

  final String? detail;

  @override
  String toString() => 'MembershipsUnavailable(${detail ?? ''})';
}

/// Port de lecture des appartenances d'un compte (ADR 0024).
///
/// Implémentation : `StoreMembershipsSource` (documents `members` lus par une
/// requête de groupe de collections, plus les clubs que lit un administrateur).
abstract interface class MembershipsSource {
  /// Les clubs de [user], avec son rôle et son périmètre dans chacun ; liste
  /// vide si le compte n'a aucun `member` (et n'est pas administrateur).
  /// Lève [MembershipsUnavailable] si la lecture est impossible.
  ///
  /// Un administrateur voit **tous** les clubs, avec le rôle `admin` dans ceux
  /// où il n'a pas de `member` (le rôle de club l'emporte, ordre des règles).
  Future<List<ClubMembership>> membershipsOf(UserId user);

  /// Vrai si [user] est administrateur de l'application (document
  /// `admins/{uid}`, créé en console). Lève [MembershipsUnavailable] si la
  /// lecture est impossible.
  Future<bool> isAdmin(UserId user);
}
