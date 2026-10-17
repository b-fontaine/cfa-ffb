import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/entities/membership/domain/member_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';
import 'package:injectable/injectable.dart';

/// Membres d'un club dans le stock de documents (`clubs/{club}/members/{uid}`).
@LazySingleton(as: MemberRepository)
class StoreMemberRepository implements MemberRepository {
  StoreMemberRepository(this._store);

  final DocumentStore _store;

  static String pathOf(ClubId club, UserId user) =>
      'clubs/${club.value}/members/${user.value}';

  @override
  Future<List<Member>> membersOf(ClubId club) => guardStore(() async {
    final documents = await _store.list('clubs/${club.value}/members');
    final members = [for (final document in documents) ?_member(document)]
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    return members;
  });

  @override
  Future<void> remove(ClubId club, UserId user) =>
      guardStore(() => _store.commit([DeleteOp(pathOf(club, user))]));

  /// Un document illisible (rôle inconnu, nom absent) est ignoré, jamais fatal.
  static Member? _member(StoredDocument document) {
    final role = Role.tryParse(document.fields['role'] as String?);
    final name = document.fields['displayName'];
    if (role == null || name is! String) return null;
    final joined = document.fields['createdAt'];
    try {
      return Member(
        uid: UserId(document.id),
        role: role,
        displayName: name,
        groupIds: _ids(document.fields['groupIds'], GroupId.new),
        studentIds: _ids(document.fields['studentIds'], StudentId.new),
        joinedAt: joined is DateTime ? joined : null,
      );
    } on InvariantViolation {
      return null;
    }
  }

  static List<T> _ids<T>(Object? raw, T Function(String) make) => [
    if (raw is List<Object?>)
      for (final item in raw)
        if (item is String && item.isNotEmpty) make(item),
  ];
}
