import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/features/track_seasons/domain/closed_season.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les saisons closes et leur archive, la plus récente d'abord
/// (lecture seule, aucun prénom). Une saison close sans archive (aucune
/// séance) est listée sans chiffres.
@injectable
class ListSeasonArchives {
  ListSeasonArchives(this._seasons, this._archives, this._catalogue);

  final SeasonRepository _seasons;
  final SeasonArchiveRepository _archives;
  final CatalogueRepository _catalogue;

  Future<Result<List<ClosedSeason>>> call() => runGuarded(() async {
    final catalogue = await _catalogue.load();
    final archives = {
      for (final archive in await _archives.all()) archive.seasonId: archive,
    };
    final closed = [
      for (final season in await _seasons.all())
        if (season.isClosed) season,
    ]..sort((a, b) => b.startDate.compareTo(a.startDate));
    return [
      for (final season in closed)
        ClosedSeason(
          season: season,
          audiences:
              archives[season.id]?.audiences ?? const <AudienceArchive>[],
          exercises: [
            for (final line
                in archives[season.id]?.exercises ?? const <ExerciseArchive>[])
              ExerciseLine(
                audience: line.audience,
                blockTitle:
                    catalogue.blockById(line.exercise.blockId)?.title ??
                    line.exercise.blockId,
                exerciseNumber: line.exercise.number,
                studentCount: line.studentCount,
                attemptCount: line.attemptCount,
                potted: line.potted,
                total: line.total,
              ),
          ],
        ),
    ];
  });
}
