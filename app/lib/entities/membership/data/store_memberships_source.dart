import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:injectable/injectable.dart';

/// Appartenances lues dans le stock de documents : les `members` du compte par
/// une requête de groupe de collections (filtrée sur `uid`, seule requête que
/// les règles autorisent à un compte sans club), le nom de chaque club, et
/// pour un administrateur tous les clubs.
///
/// Budget de lectures d'une résolution de session : 1 requête de groupe + 1
/// lecture par club + 1 lecture de `admins/{uid}` (+ 1 liste des clubs si
/// administrateur).
@LazySingleton(as: MembershipsSource)
class StoreMembershipsSource implements MembershipsSource {
  StoreMembershipsSource(this._store);

  final DocumentStore _store;

  @override
  Future<List<ClubMembership>> membershipsOf(UserId user) async {
    try {
      final owned = await _store.collectionGroup(
        'members',
        field: 'uid',
        equalTo: user.value,
      );
      final byClub = <ClubId, ClubMembership>{};
      for (final member in owned) {
        final role = Role.tryParse(member.fields['role'] as String?);
        // `clubs/{club}/members/{uid}` : le club est le deuxième segment.
        if (role == null || role == Role.admin || member.segments.length != 4) {
          continue;
        }
        final club = ClubId(member.segments[1]);
        final name = await _clubName(club);
        if (name == null) continue;
        byClub[club] = ClubMembership(
          clubId: club,
          clubName: name,
          role: role,
          groupIds: _ids(member.fields['groupIds'], GroupId.new),
          studentIds: _ids(member.fields['studentIds'], StudentId.new),
        );
      }
      if (await _isAdmin(user)) {
        for (final document in await _store.list('clubs')) {
          final club = ClubId(document.id);
          final name = document.fields['name'];
          if (byClub.containsKey(club) || name is! String || name.isEmpty) {
            continue;
          }
          byClub[club] = ClubMembership(
            clubId: club,
            clubName: name,
            role: Role.admin,
          );
        }
      }
      return List.unmodifiable(byClub.values);
    } on StoreFailure catch (failure) {
      throw _translate(failure);
    }
  }

  @override
  Future<List<OwnMember>> ownMembers(UserId user) async {
    try {
      final owned = await _store.collectionGroupFromServer(
        'members',
        field: 'uid',
        equalTo: user.value,
      );
      return [
        for (final member in owned)
          // `clubs/{club}/members/{uid}` : le club est le deuxième segment.
          if (member.segments.length == 4 && member.segments.first == 'clubs')
            (
              clubId: ClubId(member.segments[1]),
              role: Role.tryParse(member.fields['role'] as String?),
            ),
      ];
    } on StoreFailure catch (failure) {
      throw _translate(failure);
    }
  }

  @override
  Future<bool> isAdmin(UserId user) async {
    try {
      return await _isAdmin(user);
    } on StoreFailure catch (failure) {
      throw _translate(failure);
    }
  }

  /// Refus du serveur (règle, index) ou service injoignable : l'écran de
  /// l'application n'est pas le même (ADR 0024, notes FB4a).
  static Exception _translate(StoreFailure failure) => switch (failure.code) {
    StoreFailureCode.permissionDenied ||
    StoreFailureCode.failedPrecondition => MembershipsDenied(failure.code.name),
    _ => MembershipsUnavailable(failure.toString()),
  };

  Future<bool> _isAdmin(UserId user) async =>
      await _store.get('admins/${user.value}') != null;

  Future<String?> _clubName(ClubId club) async {
    final document = await _store.get('clubs/${club.value}');
    final name = document?.fields['name'];
    return name is String && name.isNotEmpty ? name : null;
  }

  static List<T> _ids<T>(Object? raw, T Function(String) make) => [
    if (raw is List<Object?>)
      for (final item in raw)
        if (item is String && item.isNotEmpty) make(item),
  ];
}
