import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : la saison à proposer de clore (U11-15) : la plus ancienne
/// saison non close dont la fin est passée. `null` s'il n'y en a pas.
@injectable
class GetClosableSeason {
  GetClosableSeason(this._seasons);

  final SeasonRepository _seasons;

  Future<Season?> call({required DateTime today}) async {
    final day = today.dateOnly;
    final over = [
      for (final season in await _seasons.all())
        if (!season.isClosed && season.endDate.isBefore(day)) season,
    ]..sort((a, b) => a.startDate.compareTo(b.startDate));
    return over.firstOrNull;
  }
}
