import 'dart:convert';

import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:injectable/injectable.dart';

/// Persistance clé/valeur de [ActiveClubMemory]. Mémoire locale du club actif, **par compte** (ADR 0024, décisions 22 et
/// 23) : préférence de l'appareil, jamais envoyée au serveur ; effacée à la
/// déconnexion. La clé porte l'identifiant du compte : un autre utilisateur du
/// même appareil ne lit rien de celui d'avant. Le nom et le rôle sont gardés
/// avec l'identifiant pour que l'application rouvre hors ligne dans le bon club
/// (démarrage avec session persistée, ADR 0024 décision 31).
@LazySingleton(as: ActiveClubMemory)
class KeyValueActiveClubMemory implements ActiveClubMemory {
  KeyValueActiveClubMemory(this._store);

  final KeyValueStore _store;

  static String keyFor(UserId user) => 'active_club.${user.value}';

  /// Le club retenu pour [user], `null` s'il n'y en a pas ou si la valeur
  /// stockée est illisible (elle est alors ignorée, jamais fatale).
  @override
  Future<ClubMembership?> read(UserId user) async {
    final raw = await _store.read(keyFor(user));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      final club = json['club'];
      final name = json['name'];
      final role = Role.tryParse(json['role'] as String?);
      if (club is! String || club.isEmpty || name is! String || role == null) {
        return null;
      }
      return ClubMembership(
        clubId: ClubId(club),
        clubName: name,
        role: role,
        groupIds: _ids(json['groups'], GroupId.new),
        studentIds: _ids(json['students'], StudentId.new),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(UserId user, ClubMembership club) => _store.write(
    keyFor(user),
    jsonEncode({
      'club': club.clubId.value,
      'name': club.clubName,
      'role': club.role.name,
      'groups': [for (final id in club.groupIds) id.value],
      'students': [for (final id in club.studentIds) id.value],
    }),
  );

  /// Les identifiants d'une liste stockée ; une valeur absente ou illisible
  /// donne une liste vide (anciennes valeurs d'avant FB3).
  static List<T> _ids<T>(Object? raw, T Function(String) make) => [
    if (raw is List<Object?>)
      for (final item in raw)
        if (item is String && item.isNotEmpty) make(item),
  ];

  @override
  Future<void> clear(UserId user) => _store.remove(keyFor(user));
}
