import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux archives de saisons closes (implémenté dans la couche
/// data). Une archive est un agrégat calculé une fois : elle est remplacée en
/// bloc par saison, jamais modifiée ligne à ligne.
abstract interface class SeasonArchiveRepository {
  /// Remplace tout l'archive de la saison. Une archive sans aucun bloc (saison
  /// sans séance) ne laisse aucune ligne : [bySeason] rend alors `null`.
  Future<void> save(SeasonArchive archive);

  Future<SeasonArchive?> bySeason(SeasonId seasonId);

  /// Toutes les archives, triées par identifiant de saison.
  Future<List<SeasonArchive>> all();

  /// Efface l'archive de la saison ; sans effet s'il n'y en a pas.
  Future<void> delete(SeasonId seasonId);
}
