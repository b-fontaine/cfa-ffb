import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: SettingsRepository, env: [Environment.test])
class InMemorySettingsRepository implements SettingsRepository {
  // Une seule ligne, sous la clé 1 : écrite par le journal de l'unité de
  // travail, comme la table SQL.
  final Map<int, ClubSettings> _row = {};

  @override
  Future<ClubSettings> load() async => _row[1] ?? ClubSettings.defaults;

  @override
  Future<void> save(ClubSettings settings) async =>
      _row.journaledPut(1, settings);

  @override
  Future<void> reset() async => _row.journaledRemove(1);
}
