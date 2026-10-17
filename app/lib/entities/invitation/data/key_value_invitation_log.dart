import 'dart:convert';

import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:injectable/injectable.dart';

/// Mémoire locale des invitations émises, dans le stockage clé/valeur de
/// l'appareil : une clé par compte (`issued_invitations.<uid>`), une liste par
/// club. Une valeur illisible est ignorée, jamais fatale.
@LazySingleton(as: InvitationLog)
class KeyValueInvitationLog implements InvitationLog {
  KeyValueInvitationLog(this._store);

  final KeyValueStore _store;

  static String keyFor(UserId user) => 'issued_invitations.${user.value}';

  @override
  Future<List<IssuedInvitation>> read(UserId user, ClubId club) async =>
      (await _load(user))[club.value] ?? const [];

  @override
  Future<void> add(
    UserId user,
    ClubId club,
    IssuedInvitation invitation,
  ) async {
    final all = await _load(user);
    final entries = [
      invitation,
      for (final entry in all[club.value] ?? const <IssuedInvitation>[])
        if (entry.code != invitation.code) entry,
    ];
    all[club.value] = entries.take(InvitationLog.maxEntries).toList();
    await _save(user, all);
  }

  @override
  Future<void> remove(UserId user, ClubId club, InvitationCode code) async {
    final all = await _load(user);
    final entries = all[club.value];
    if (entries == null) return;
    all[club.value] = [
      for (final entry in entries)
        if (entry.code != code) entry,
    ];
    await _save(user, all);
  }

  @override
  Future<void> clear(UserId user) => _store.remove(keyFor(user));

  Future<Map<String, List<IssuedInvitation>>> _load(UserId user) async {
    final raw = await _store.read(keyFor(user));
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return {};
      return {
        for (final entry in json.entries)
          if (entry.value is List<Object?>)
            entry.key: [
              for (final item in entry.value! as List<Object?>) ?_entry(item),
            ],
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> _save(UserId user, Map<String, List<IssuedInvitation>> all) =>
      _store.write(
        keyFor(user),
        jsonEncode({
          for (final club in all.entries)
            club.key: [
              for (final entry in club.value)
                {
                  'code': entry.code.value,
                  'role': entry.role.name,
                  'createdAt': entry.createdAt.toIso8601String(),
                  'expiresAt': entry.expiresAt.toIso8601String(),
                },
            ],
        }),
      );

  static IssuedInvitation? _entry(Object? item) {
    if (item is! Map<String, Object?>) return null;
    final code = InvitationCode.tryParse('${item['code']}');
    final role = Role.tryParse(item['role'] as String?);
    final created = DateTime.tryParse('${item['createdAt']}');
    final expires = DateTime.tryParse('${item['expiresAt']}');
    if (code == null || role == null || created == null || expires == null) {
      return null;
    }
    return IssuedInvitation(
      code: code,
      role: role,
      createdAt: created,
      expiresAt: expires,
    );
  }
}
