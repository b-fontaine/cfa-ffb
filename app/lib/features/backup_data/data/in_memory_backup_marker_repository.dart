import 'package:billard_cfa/features/backup_data/domain/backup_marker.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_marker_repository.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: BackupMarkerRepository, env: [Environment.test])
class InMemoryBackupMarkerRepository implements BackupMarkerRepository {
  BackupMarker? _last;

  @override
  Future<BackupMarker?> last() async => _last;

  @override
  Future<void> record(BackupMarker marker) async => _last = marker;
}
