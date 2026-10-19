import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';

/// Les clubs et les `members` des scénarios, écrits comme le serveur les
/// stocke dans le double en mémoire du stock de documents : l'application les
/// lit par son vrai `StoreMembershipsSource`.
class MembershipsFixture {
  MembershipsFixture(this._store);

  final InMemoryDocumentStore _store;

  /// Un `member` du club de [membership] pour [user] (et le club s'il
  /// n'existe pas encore).
  void grant(UserId user, ClubMembership membership, {String? displayName}) {
    final now = _store.serverNow();
    final clubPath = 'clubs/${membership.clubId.value}';
    if (_store.read(clubPath) == null) {
      _store.seed(clubPath, {'name': membership.clubName, 'createdAt': now});
    }
    _store.seed('$clubPath/members/${user.value}', {
      'uid': user.value,
      'role': membership.role.name,
      'displayName': displayName ?? user.value,
      'groupIds': [for (final id in membership.groupIds) id.value],
      'studentIds': [for (final id in membership.studentIds) id.value],
      'createdAt': now,
    });
  }

  /// Retire [user] du club [club] (son document `members`) : il n'en est plus
  /// membre, ses abonnements au club ne sont plus autorisés par les règles.
  void remove(UserId user, ClubId club) =>
      _store.remove('clubs/${club.value}/members/${user.value}');

  /// Le club existe (sans aucun membre).
  void club(ClubId id, String name) => _store.seed('clubs/${id.value}', {
    'name': name,
    'createdAt': _store.serverNow(),
  });

  /// Hors ligne : toute lecture ou écriture du stock échoue.
  bool get unavailable => _store.failing == StoreFailureCode.unavailable;

  set unavailable(bool value) =>
      _store.failing = value ? StoreFailureCode.unavailable : null;

  /// Le serveur refuse la lecture (règle) : `permission-denied`.
  bool get denied => _store.failing == StoreFailureCode.permissionDenied;

  set denied(bool value) =>
      _store.failing = value ? StoreFailureCode.permissionDenied : null;

  /// Le serveur exige un index absent : `failed-precondition`.
  bool get missingIndex =>
      _store.failing == StoreFailureCode.failedPrecondition;

  set missingIndex(bool value) =>
      _store.failing = value ? StoreFailureCode.failedPrecondition : null;

  /// Supprime tous les clubs et leurs membres, administrateurs compris.
  void clear() => _store.documents.keys
      .where((path) => path.startsWith('clubs/') || path.startsWith('admins/'))
      .toList()
      .forEach(_store.remove);

  /// Combien de lectures le stock a servies (assertions).
  int get reads => _store.reads;
}
