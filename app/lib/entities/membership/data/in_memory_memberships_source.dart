import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Appartenances en mémoire (tests, BDD) : le double du port que FB3 branchera
/// sur Firestore.
@LazySingleton(as: MembershipsSource, env: [Environment.test])
class InMemoryMembershipsSource implements MembershipsSource {
  final Map<UserId, List<ClubMembership>> _byUser = {};

  /// Quand il est vrai, la lecture échoue comme sans réseau.
  bool unavailable = false;

  /// Combien de lectures ont été demandées (assertions).
  int reads = 0;

  void grant(UserId user, ClubMembership membership) =>
      (_byUser[user] ??= []).add(membership);

  void revokeAll(UserId user) => _byUser.remove(user);

  @override
  Future<List<ClubMembership>> membershipsOf(UserId user) async {
    reads++;
    if (unavailable) throw const MembershipsUnavailable('hors ligne');
    return List.unmodifiable(_byUser[user] ?? const <ClubMembership>[]);
  }
}
