import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/entities/club/domain/club_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';
import 'package:injectable/injectable.dart';

/// Clubs dans le stock de documents (`clubs/{club}`) : Firestore en
/// production, le double en mémoire dans les tests.
@LazySingleton(as: ClubRepository)
class StoreClubRepository implements ClubRepository {
  StoreClubRepository(this._store);

  final DocumentStore _store;

  static String pathOf(ClubId id) => 'clubs/${id.value}';

  @override
  Future<List<Club>> all() => guardStore(() async {
    final documents = await _store.list('clubs');
    return [for (final document in documents) ?_club(document)];
  });

  @override
  Future<Club?> byId(ClubId id) => guardStore(() async {
    final document = await _store.get(pathOf(id));
    return document == null ? null : _club(document);
  });

  @override
  Future<void> create(Club club) => guardStore(
    () => _store.commit([
      SetOp(pathOf(club.id), {
        'name': club.name,
        'createdAt': serverTimestamp,
        'currentSeasonId': ?club.currentSeasonId?.value,
      }),
    ]),
  );

  @override
  Future<void> rename(ClubId id, String name) => guardStore(
    () => _store.commit([
      UpdateOp(pathOf(id), {'name': Club(id: id, name: name.trim()).name}),
    ]),
  );

  /// Un document illisible (nom absent ou vide) est ignoré, jamais fatal.
  static Club? _club(StoredDocument document) {
    final name = document.fields['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final season = document.fields['currentSeasonId'];
    try {
      return Club(
        id: ClubId(document.id),
        name: name,
        currentSeasonId: season is String && season.isNotEmpty
            ? SeasonId(season)
            : null,
      );
    } on InvariantViolation {
      return null;
    }
  }
}
