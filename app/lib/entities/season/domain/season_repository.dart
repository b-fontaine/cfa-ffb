import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux saisons (implémenté dans la couche data).
///
/// Même contrat que `StudentRepository` : ordre de première sauvegarde,
/// remplacement par id, suppression logique.
abstract interface class SeasonRepository {
  Future<void> save(Season season);

  Future<Season?> byId(SeasonId id);

  Future<List<Season>> all();

  /// Supprime logiquement la saison ; sans effet si elle n'existe pas.
  Future<void> delete(SeasonId id);
}
