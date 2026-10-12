import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: SeasonRepository, env: [Environment.test])
class InMemorySeasonRepository implements SeasonRepository {
  final Map<SeasonId, Season> _seasons = {};

  @override
  Future<void> save(Season season) async =>
      _seasons.journaledPut(season.id, season);

  @override
  Future<Season?> byId(SeasonId id) async => _seasons[id];

  @override
  Future<List<Season>> all() async => _seasons.values.toList();

  @override
  Future<void> delete(SeasonId id) async => _seasons.journaledRemove(id);
}
