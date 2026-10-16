import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: SeasonArchiveRepository, env: [Environment.test])
class InMemorySeasonArchiveRepository implements SeasonArchiveRepository {
  final Map<SeasonId, SeasonArchive> _archives = {};

  @override
  Future<void> save(SeasonArchive archive) async {
    // Comme en base : une archive sans aucun bloc n'a aucune ligne à garder.
    if (archive.audiences.isEmpty && archive.exercises.isEmpty) {
      _archives.journaledRemove(archive.seasonId);
    } else {
      _archives.journaledPut(archive.seasonId, archive);
    }
  }

  @override
  Future<SeasonArchive?> bySeason(SeasonId seasonId) async =>
      _archives[seasonId];

  @override
  Future<List<SeasonArchive>> all() async =>
      _archives.values.toList()
        ..sort((a, b) => a.seasonId.value.compareTo(b.seasonId.value));

  @override
  Future<void> delete(SeasonId seasonId) async =>
      _archives.journaledRemove(seasonId);
}
