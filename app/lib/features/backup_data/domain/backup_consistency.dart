import 'package:billard_cfa/features/backup_data/domain/backup_references.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_uniqueness.dart';

/// Contrôle d'intégrité d'une sauvegarde décodée : une sauvegarde est
/// autonome (pas d'identifiant en double, aucune référence orpheline).
class BackupConsistency {
  const BackupConsistency();

  void check(BackupSnapshot snapshot) {
    const BackupUniqueness().check(snapshot);
    const BackupReferences().check(snapshot);
  }
}
