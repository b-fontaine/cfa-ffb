import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Double du port `MembershipsSource` pour les tests unitaires de l'`AuthCubit`
/// (sans stock de documents) : appartenances et administrateurs en mémoire.
class InMemoryMembershipsSource implements MembershipsSource {
  final Map<UserId, List<ClubMembership>> _byUser = {};
  final Set<UserId> _admins = {};

  /// Quand il est vrai, la lecture échoue comme sans réseau.
  bool unavailable = false;

  /// Quand il est vrai, le serveur refuse la lecture (règle ou index).
  bool denied = false;

  /// Combien de lectures des clubs ont été demandées (assertions).
  int reads = 0;

  void grant(UserId user, ClubMembership membership) =>
      (_byUser[user] ??= []).add(membership);

  void revokeAll(UserId user) => _byUser.remove(user);

  /// Retire le club [club] des appartenances de [user] (son `member` est
  /// supprimé).
  void revoke(UserId user, ClubId club) =>
      _byUser[user]?.removeWhere((membership) => membership.clubId == club);

  void makeAdmin(UserId user) => _admins.add(user);

  /// Les `members` d'un compte dans un club **supprimé ou sans nom** :
  /// `ownMembers` les rend, `membershipsOf` non (comme le stock réel).
  final Map<UserId, List<OwnMember>> _orphans = {};

  void orphan(UserId user, ClubId club, Role role) =>
      (_orphans[user] ??= []).add((clubId: club, role: role));

  /// Retire le `member` orphelin de [user] dans [club].
  void dropOrphan(UserId user, ClubId club) =>
      _orphans[user]?.removeWhere((member) => member.clubId == club);

  /// Quand il est vrai, la lecture des `members` au serveur échoue comme
  /// hors ligne (le cache, lui, répondrait encore).
  bool serverUnavailable = false;

  @override
  Future<List<OwnMember>> ownMembers(UserId user) async {
    if (denied) throw const MembershipsDenied('refus');
    if (unavailable || serverUnavailable) {
      throw const MembershipsUnavailable('hors ligne');
    }
    return [
      for (final membership in _byUser[user] ?? const <ClubMembership>[])
        (clubId: membership.clubId, role: membership.role),
      ...?_orphans[user],
    ];
  }

  @override
  Future<List<ClubMembership>> membershipsOf(UserId user) async {
    reads++;
    if (denied) throw const MembershipsDenied('refus');
    if (unavailable) throw const MembershipsUnavailable('hors ligne');
    return List.unmodifiable(_byUser[user] ?? const <ClubMembership>[]);
  }

  @override
  Future<bool> isAdmin(UserId user) async {
    if (denied) throw const MembershipsDenied('refus');
    if (unavailable) throw const MembershipsUnavailable('hors ligne');
    return _admins.contains(user);
  }
}
