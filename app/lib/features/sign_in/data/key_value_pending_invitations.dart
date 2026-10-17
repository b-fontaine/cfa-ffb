import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:billard_cfa/features/sign_in/domain/pending_invitations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:injectable/injectable.dart';

/// Code d'invitation en attente, gardé sur l'appareil sous la clé du compte.
@LazySingleton(as: PendingInvitations)
class KeyValuePendingInvitations implements PendingInvitations {
  KeyValuePendingInvitations(this._store);

  final KeyValueStore _store;

  static String keyFor(UserId user) => 'pending_invitation.${user.value}';

  @override
  Future<void> hold(UserId user, InvitationCode code) =>
      _store.write(keyFor(user), code.value);

  @override
  Future<InvitationCode?> read(UserId user) async {
    final raw = await _store.read(keyFor(user));
    if (raw == null) return null;
    try {
      return InvitationCode.parse(raw);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> clear(UserId user) => _store.remove(keyFor(user));
}
