import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Les clubs d'un compte ne peuvent pas être lus (réseau, service).
class MembershipsUnavailable implements Exception {
  const MembershipsUnavailable([this.detail]);

  final String? detail;

  @override
  String toString() => 'MembershipsUnavailable(${detail ?? ''})';
}

/// Port de lecture des appartenances d'un compte.
///
/// Le lot FB3 en fournit l'implémentation Firestore (`clubs/{c}/members/{uid}`) ;
/// le lot FB2 s'appuie sur ce seul port.
abstract interface class MembershipsSource {
  /// Les clubs de [user] ; liste vide si le compte n'a aucun `member`.
  /// Lève [MembershipsUnavailable] si la lecture est impossible.
  Future<List<ClubMembership>> membershipsOf(UserId user);
}
