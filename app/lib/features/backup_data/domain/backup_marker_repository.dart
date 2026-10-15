import 'package:billard_cfa/features/backup_data/domain/backup_marker.dart';

/// Port de la mémoire de la dernière sauvegarde (implémenté dans la couche
/// data). Donnée propre à l'appareil : elle ne fait pas partie du fichier de
/// sauvegarde.
abstract interface class BackupMarkerRepository {
  /// Dernière sauvegarde enregistrée ; `null` si aucune.
  Future<BackupMarker?> last();

  /// Retient [marker] comme dernière sauvegarde.
  Future<void> record(BackupMarker marker);
}
