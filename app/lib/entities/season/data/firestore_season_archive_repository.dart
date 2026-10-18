import 'package:billard_cfa/entities/season/data/season_archive_document.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Archives agrégées des saisons closes dans `clubs/{c}/archives/{id}` : lues
/// par les animateurs (enseignant, directeur, administrateur), écrites par le
/// directeur et l'administrateur à la clôture (règles). Choisi par
/// `DataBackend.firestore`.
///
/// `save` remplace **toute** l'archive de la saison : les documents de la
/// saison sont supprimés puis réécrits dans le même envoi (atomique dans une
/// unité de travail ; la clôture reprenable de FB7 découpera en lots
/// idempotents :
/// mêmes identifiants). Une archive sans aucun bloc ne laisse aucun document.
class FirestoreSeasonArchiveRepository implements SeasonArchiveRepository {
  FirestoreSeasonArchiveRepository(this._club);

  final ClubStore _club;

  @override
  Future<void> save(SeasonArchive archive) => guardStore(() async {
    final paths = _club.paths;
    final season = archive.seasonId;
    final wanted = <String, Fields>{
      for (final block in archive.audiences)
        paths.archive(SeasonArchiveDocument.summaryId(season, block.audience)):
            SeasonArchiveDocument.encodeAudience(season, block),
      for (final line in archive.exercises)
        paths.archive(
          SeasonArchiveDocument.exerciseId(
            season,
            line.audience,
            line.exercise,
          ),
        ): SeasonArchiveDocument.encodeExercise(
          season,
          line,
        ),
    };
    final stored = await _stored(season);
    await _club.commit([
      for (final document in stored)
        if (!wanted.containsKey(document.path)) DeleteOp(document.path),
      for (final entry in wanted.entries) SetOp(entry.key, entry.value),
    ]);
  });

  @override
  Future<SeasonArchive?> bySeason(SeasonId seasonId) => guardStore(() async {
    final archives = SeasonArchiveDocument.decodeAll(await _stored(seasonId));
    return archives.firstOrNull;
  });

  @override
  Future<List<SeasonArchive>> all() => guardStore(
    () async => SeasonArchiveDocument.decodeAll(
      await _club.documents.list(_club.paths.archives),
    ),
  );

  @override
  Future<void> delete(SeasonId seasonId) => guardStore(() async {
    await _club.commit([
      for (final document in await _stored(seasonId)) DeleteOp(document.path),
    ]);
  });

  Future<List<StoredDocument>> _stored(SeasonId season) => _club.documents
      .query(_club.paths.archives, FieldEquals('seasonId', season.value));
}
