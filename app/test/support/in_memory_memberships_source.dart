import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Double du port `MembershipsSource` pour les tests unitaires de l'`AuthCubit`
/// (sans stock de documents) : appartenances et administrateurs en mémoire.
class InMemoryMembershipsSource implements MembershipsSource {
  final Map<UserId, List<ClubMembership>> _byUser = {};
  final Set<UserId> _admins = {};

  /// Quand il est vrai, la lecture échoue comme sans réseau.
  bool unavailable = false;

  /// Combien de lectures des clubs ont été demandées (assertions).
  int reads = 0;

  void grant(UserId user, ClubMembership membership) =>
      (_byUser[user] ??= []).add(membership);

  void revokeAll(UserId user) => _byUser.remove(user);

  void makeAdmin(UserId user) => _admins.add(user);

  @override
  Future<List<ClubMembership>> membershipsOf(UserId user) async {
    reads++;
    if (unavailable) throw const MembershipsUnavailable('hors ligne');
    return List.unmodifiable(_byUser[user] ?? const <ClubMembership>[]);
  }

  @override
  Future<bool> isAdmin(UserId user) async {
    if (unavailable) throw const MembershipsUnavailable('hors ligne');
    return _admins.contains(user);
  }
}
