import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';

/// Cas d'usage : supprimer **tous les marqueurs du compte courant** dans un
/// club (FB8 partie B, B1 ; ADR 0024 décision 19 ; décision D4 du
/// 2026-10-24). C'est l'étape de la suppression d'un compte (B2) qui précède
/// celle de son `member` : seul l'auteur retrouve et supprime ses marqueurs,
/// et il ne le peut que tant qu'il est membre du club.
final class RemoveOwnMarkers {
  const RemoveOwnMarkers(this._store);

  final OwnMarkerStore _store;

  /// Supprime les marqueurs du compte courant, de rôle [role], dans [club],
  /// par lots de [maxOwnMarkerLot] au plus ; rend combien ont été supprimés.
  ///
  /// - Seules les natures que ce rôle pose sont demandées
  ///   ([MarkerKind.heldBy]) : un parent ou un élève ne lit ni n'écrit rien,
  ///   et aucune liste refusée par les règles n'est tentée.
  /// - Les imports d'abord, puis les opérations.
  /// - Un lot en échec arrête le nettoyage (`ServiceFailure` levé) : les lots
  ///   déjà acceptés restent faits, et **rejouer** l'appel reprend (la liste
  ///   ne rend plus que ce qui reste ; supprimer un marqueur déjà absent est
  ///   accepté par les règles).
  Future<int> call(ClubId club, Role role) async {
    var removed = 0;
    for (final kind in MarkerKind.values) {
      if (!kind.heldBy(role)) continue;
      final markers = await _store.list(club, kind);
      for (var start = 0; start < markers.length; start += maxOwnMarkerLot) {
        final end = start + maxOwnMarkerLot < markers.length
            ? start + maxOwnMarkerLot
            : markers.length;
        await _store.delete(club, markers.sublist(start, end));
        removed += end - start;
      }
    }
    return removed;
  }
}
