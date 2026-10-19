import 'package:billard_cfa/entities/membership/domain/own_link.dart';

/// Port de lecture du **propre** `member` du compte dans le club actif.
///
/// Le seul document que la famille lit sur elle-même : jamais la liste des
/// membres. `null` : plus de `member` (accès retiré) ou lien illisible.
abstract interface class OwnLinkSource {
  /// Le lien aujourd'hui sur le serveur ; `null` si le `member` n'existe plus
  /// ou si le serveur refuse de le lire (une règle refuse la lecture d'un
  /// document supprimé : c'est le signe d'un accès retiré). Lève un
  /// `ServiceFailure` si le service est injoignable.
  Future<OwnLink?> read();

  /// Suit le lien : un état à chaque changement (`null` quand le `member`
  /// disparaît). Une erreur du serveur (règle) arrive sur le flux, qui se
  /// ferme.
  Stream<OwnLink?> watch();
}
