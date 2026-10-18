import 'package:billard_cfa/entities/season/data/season_document.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Saisons du club actif dans `clubs/{c}/seasons/{id}` (ADR 0024, A5) : lues
/// par tout membre, écrites par le directeur et l'administrateur (règles).
/// Choisi par `DataBackend.firestore`.
///
/// - `save` crée la saison (date du serveur) ou la fusionne ; **une saison
///   inchangée n'est pas réécrite** : un enseignant qui inscrit un élève
///   enregistre la saison du cas d'usage sans y avoir droit, et c'est aussi une
///   écriture économisée sur le quota ;
/// - `delete` supprime le document (suppression physique, décision 15) ;
/// - la liste est triée par début de saison puis identifiant (l'ordre de
///   première sauvegarde n'existe pas côté serveur).
///
/// La **saison courante** du club (`currentSeasonId`) vit dans le document du
/// club (`StoreClubRepository`) et ne s'écrit que par l'administrateur : ce
/// dépôt ne la touche pas.
class FirestoreSeasonRepository implements SeasonRepository {
  FirestoreSeasonRepository(this._club);

  final ClubStore _club;

  @override
  Future<void> save(Season season) => guardStore(() async {
    final path = _club.paths.season(season.id);
    final stored = await _club.get(path);
    final fields = SeasonDocument.encode(season);
    if (stored != null && _unchanged(stored.fields, fields)) return;
    await _club.commit([
      SetOp(path, {
        ...fields,
        if (stored == null) ...SeasonDocument.creationOnly(),
      }, merge: true),
    ]);
  });

  @override
  Future<Season?> byId(SeasonId id) => guardStore(() async {
    final document = await _club.get(_club.paths.season(id));
    return document == null ? null : SeasonDocument.decode(document);
  });

  @override
  Future<List<Season>> all() => guardStore(() async {
    final documents = await _club.documents.list(_club.paths.seasons);
    return [for (final document in documents) SeasonDocument.decode(document)]
      ..sort(SeasonDocument.compare);
  });

  @override
  Future<void> delete(SeasonId id) =>
      guardStore(() => _club.commit([DeleteOp(_club.paths.season(id))]));

  static bool _unchanged(Fields stored, Fields wanted) =>
      wanted.entries.every((entry) => stored[entry.key] == entry.value);
}
