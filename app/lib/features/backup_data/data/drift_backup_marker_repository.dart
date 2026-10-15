import 'package:billard_cfa/features/backup_data/domain/backup_marker.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_marker_repository.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Dernière sauvegarde persistée dans SQLite (drift).
@LazySingleton(as: BackupMarkerRepository, env: [Environment.prod])
class DriftBackupMarkerRepository implements BackupMarkerRepository {
  DriftBackupMarkerRepository(this._db);

  final AppDatabase _db;

  @override
  Future<BackupMarker?> last() async {
    final row =
        await (_db.select(_db.backupExports)
              ..orderBy([(e) => OrderingTerm.desc(e.id)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return (exportedAt: row.exportedAt, attemptCount: row.attemptCount);
  }

  @override
  Future<void> record(BackupMarker marker) async {
    await _db
        .into(_db.backupExports)
        .insert(
          BackupExportsCompanion.insert(
            exportedAt: marker.exportedAt,
            attemptCount: marker.attemptCount,
          ),
        );
  }
}
