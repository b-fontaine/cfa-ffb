import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// La nature d'un marqueur laissé dans un club par son auteur (FB7, FB8) :
/// `clubs/{c}/imports/{empreinte}_{uid}` ou
/// `clubs/{c}/operations/{empreinte}_{uid}`.
enum MarkerKind {
  /// Marqueur d'import d'une sauvegarde : posé par un enseignant, un
  /// directeur ou un administrateur (`mayImport` des règles).
  import,

  /// Marqueur d'opération reprenable (effacement d'un élève, clôture) : posé
  /// par un directeur ou un administrateur (`manages` des règles).
  operation;

  /// Un compte de rôle [role] peut-il avoir posé (et donc retrouver) un
  /// marqueur de cette nature ? Les règles refusent la liste aux autres.
  bool heldBy(Role role) => switch (this) {
    MarkerKind.import =>
      role == Role.teacher || role == Role.director || role == Role.admin,
    MarkerKind.operation => role == Role.director || role == Role.admin,
  };
}

/// Un marqueur **du compte courant** : sa nature et son empreinte (la partie
/// de l'identifiant avant `_{uid}`). Le chemin se recompose avec l'uid du
/// compte courant : on ne désigne jamais le marqueur d'un autre.
@immutable
final class OwnMarker {
  const OwnMarker(this.kind, this.key);

  final MarkerKind kind;

  /// L'empreinte SHA-256 (64 caractères hexadécimaux) du fichier ou de
  /// l'opération.
  final String key;

  @override
  bool operator ==(Object other) =>
      other is OwnMarker && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);

  @override
  String toString() => 'OwnMarker(${kind.name}, $key)';
}

/// Port : les marqueurs que le **compte courant** a laissés dans un club, et
/// leur suppression (FB8 partie B, B1 : nettoyage à la suppression de son
/// compte). Le club est donné à chaque appel (pas le club actif) : la
/// suppression d'un compte parcourt tous ses clubs.
///
/// Implémenté pour Firestore par `FirestoreOwnMarkerStore` ; un double en
/// mémoire (`InMemoryOwnMarkerStore`) sert les tests et suit le même contrat.
abstract interface class OwnMarkerStore {
  /// Les marqueurs de nature [kind] posés par le compte courant dans [club]
  /// (requête filtrée sur l'auteur : les règles n'en permettent pas d'autre).
  /// Lève `ServiceFailure` : `denied` (aucun compte, rôle sans droit),
  /// `unavailable` (réseau).
  Future<List<OwnMarker>> list(ClubId club, MarkerKind kind);

  /// Supprime [markers] du compte courant dans [club] **en un seul lot
  /// atomique**, après l'accusé du serveur (au plus [maxOwnMarkerLot]).
  /// Supprimer un marqueur déjà absent n'est pas une erreur (reprise).
  /// Lève `ServiceFailure` : `denied`, `unavailable` (réseau, accusé
  /// attendu en vain), `other`.
  Future<void> delete(ClubId club, List<OwnMarker> markers);
}

/// Suppressions d'un lot de nettoyage au plus (comme les lots d'opération :
/// sous la limite de 500 écritures de Firestore).
const int maxOwnMarkerLot = 400;
