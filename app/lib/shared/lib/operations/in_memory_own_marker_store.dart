import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';

/// Le double en mémoire de [OwnMarkerStore] (FB8 partie B, B1) : les
/// marqueurs de tous les auteurs, par club ; le compte courant ne voit et ne
/// supprime que les siens, comme sous les règles Firestore. Suit le même
/// contrat que `FirestoreOwnMarkerStore`
/// (`test/contract/own_marker_store_contract.dart`).
final class InMemoryOwnMarkerStore implements OwnMarkerStore {
  InMemoryOwnMarkerStore(this._user);

  final CurrentUser _user;

  final Set<(ClubId, MarkerKind, String, String)> _markers = {};

  /// Pose un marqueur de [author] (amorçage des tests, sans contrôle).
  void seed(ClubId club, MarkerKind kind, String key, String author) =>
      _markers.add((club, kind, key, author));

  /// Le marqueur de [author] existe-t-il ?
  bool contains(ClubId club, MarkerKind kind, String key, String author) =>
      _markers.contains((club, kind, key, author));

  @override
  Future<List<OwnMarker>> list(ClubId club, MarkerKind kind) async {
    final author = _author;
    return [
      for (final (c, k, key, a) in _markers)
        if (c == club && k == kind && a == author) OwnMarker(kind, key),
    ];
  }

  @override
  Future<void> delete(ClubId club, List<OwnMarker> markers) async {
    final author = _author;
    if (markers.length > maxOwnMarkerLot) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        '${markers.length} deletions > $maxOwnMarkerLot',
      );
    }
    for (final marker in markers) {
      _markers.remove((club, marker.kind, marker.key, author));
    }
  }

  String get _author {
    final author = _user.id;
    if (author == null) {
      throw const ServiceFailure(ServiceFailureCode.denied, 'user');
    }
    return author.value;
  }
}
