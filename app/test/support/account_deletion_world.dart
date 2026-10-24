import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_world.dart';

/// Ce que les scénarios de suppression d'un compte (FB8 partie B, B2) doivent
/// retrouver **après** la suppression : l'identifiant d'un compte qui n'existe
/// plus (le double d'authentification garde les comptes supprimés) et le code
/// de l'invitation émise depuis l'appareil.
class AccountDeletionWorld {
  AccountDeletionWorld._();

  static final Map<String, String> _codes = {};

  /// L'identifiant du compte [email], qu'il existe encore ou qu'il ait été
  /// supprimé.
  static UserId uidOf(String email) {
    final live = UiWorld.auth.accountOf(email);
    if (live != null) return live.id;
    final deleted = UiWorld.auth.deletedAccounts.where(
      (account) => account.email == email.trim().toLowerCase(),
    );
    expect(deleted, isNotEmpty, reason: 'aucun compte $email, même supprimé');
    return deleted.last.id;
  }

  /// Retient le code de l'invitation émise par [email] (vidé à la fin du
  /// scénario).
  static void rememberInvitation(String email, String code) {
    if (_codes.isEmpty) addTearDown(_codes.clear);
    _codes[email] = code;
  }

  static String invitationOf(String email) =>
      _codes[email] ?? (throw StateError('aucune invitation émise par $email'));
}
