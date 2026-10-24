import 'package:billard_cfa/entities/invitation/data/store_invitation_repository.dart';
import 'package:billard_cfa/entities/invitation/domain/spent_invitations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Les invitations utilisées ou échues du club actif, dans le stock de
/// documents (`invitations/{code}`, à la racine), par les requêtes que
/// `firestore.rules` ouvre (FB8 partie B, décision D3) :
///
/// - l'administrateur : `clubId ==` le club actif, tous les rôles ;
/// - un autre rôle : `clubId ==` et `role ==`, **une requête par rôle qu'il
///   invite** (`RolePolicy.invitableRoles`) ; pour le directeur, jamais une
///   invitation de directeur.
///
/// Égalités seules : Firestore les sert par fusion des index à champ unique,
/// aucun index composite. La suppression passe par le `ClubStore` : dans une
/// opération reprenable, elle part dans le lot atomique du marqueur.
class ClubSpentInvitations implements SpentInvitations {
  ClubSpentInvitations(this._club, this._clock);

  final ClubStore _club;
  final Clock _clock;

  static const _collection = 'invitations';

  @override
  Future<List<InvitationCode>> codes() => guardStore(() async {
    final club = _club.paths.club.value;
    final role = _club.role;
    final filters = role == Role.admin
        ? [FieldEquals('clubId', club)]
        : [
            for (final invited in role?.invitableRoles ?? const <Role>[])
              AllEqual([
                FieldEquals('clubId', club),
                FieldEquals('role', invited.name),
              ]),
          ];
    final now = _clock.now();
    return [
      for (final filter in filters)
        for (final document in await _club.documents.query(_collection, filter))
          ?_spent(document, now),
    ];
  });

  /// Le code de l'invitation [document] si elle est **utilisée**, ou
  /// **échue** à [now] ; `null` si elle est valable, ou si ni l'usage ni
  /// l'échéance ne se lisent (laissée telle quelle, jamais fatal). Seuls ces
  /// deux champs comptent : une invitation au périmètre inattendu se purge
  /// comme une autre.
  static InvitationCode? _spent(StoredDocument document, DateTime now) {
    final code = InvitationCode.tryParse(document.path.split('/').last);
    if (code == null) return null;
    final expiresAt = document.fields['expiresAt'];
    final used = document.fields['used'] == true;
    final expired = expiresAt is DateTime && !now.isBefore(expiresAt);
    return used || expired ? code : null;
  }

  @override
  OperationLot remove(List<InvitationCode> codes) => OperationLot(
    writes: codes.length,
    apply: () => _club.commit([
      for (final code in codes)
        DeleteOp(StoreInvitationRepository.pathOf(code)),
    ]),
  );
}
