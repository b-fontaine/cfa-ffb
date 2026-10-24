import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// L'âge à partir duquel un marqueur d'import ou d'opération est réputé
/// **abandonné** (FB8 partie B, B5 ; décision D4 du 2026-10-24) : son dernier
/// lot (`updatedAt`, heure du serveur) date de plus de 90 jours. Un
/// gestionnaire du club peut alors le supprimer, quel qu'en soit l'auteur.
///
/// **Même valeur** que `staleMarkerAge()` de `firestore.rules`, qui fait foi
/// (les règles refusent toute suppression plus précoce) ; durée à valider par
/// le DPO. Une durée plus courte casserait une reprise légitime ; un marqueur
/// d'import terminé effacé permet de rejouer le fichier (l'aperçu de l'import
/// proposerait de rétablir les élèves effacés depuis).
const Duration staleMarkerAge = Duration(days: 90);

/// La marge prise sur l'horloge de l'appareil pour la borne de la requête :
/// les règles comparent à l'heure du **serveur** et refusent une borne plus
/// récente que [staleMarkerAge]. Un appareil en avance d'au plus un jour
/// liste donc encore ; un marqueur de 90 à 91 jours attend le lendemain.
const Duration staleMarkerClockMargin = Duration(days: 1);

/// Un marqueur abandonné du club : sa nature et l'identifiant **complet** de
/// son document (`{empreinte}_{uid de l'auteur}`), quel qu'en soit l'auteur.
/// Aucune donnée personnelle.
@immutable
final class StaleMarker {
  const StaleMarker(this.kind, this.id);

  final MarkerKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is StaleMarker && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'StaleMarker(${kind.name}, $id)';
}

/// Port : les marqueurs **anciens** d'un club, et leur suppression (FB8
/// partie B, B5). Implémenté pour Firestore par `FirestoreStaleMarkerStore`
/// (couche `app`).
abstract interface class StaleMarkerStore {
  /// Les marqueurs de nature [kind] de [club] dont `updatedAt` est
  /// strictement antérieur à [before] (requête de plage bornée : les règles
  /// refusent une borne qui ne prouve pas l'ancienneté). Lève
  /// `ServiceFailure` : `denied`, `unavailable`.
  Future<List<StaleMarker>> list(ClubId club, MarkerKind kind, DateTime before);

  /// Supprime [markers] de [club] **en un seul lot atomique** (au plus
  /// [maxOwnMarkerLot]), après l'accusé du serveur. Un marqueur redevenu
  /// récent entre-temps (son auteur a repris) fait refuser le lot en bloc
  /// (`denied`). Lève `ServiceFailure` : `denied`, `unavailable`, `other`.
  Future<void> delete(ClubId club, List<StaleMarker> markers);
}
