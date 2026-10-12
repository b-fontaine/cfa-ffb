import 'package:billard_cfa/shared/lib/storage_status.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:billard_cfa/shared/persistence/drift_storage_status.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:injectable/injectable.dart';

/// Câblage de la persistance de production : la base SQLite est ouverte (et
/// migrée) au lancement, avant le premier écran.
@module
abstract class PersistenceModule {
  @Environment(Environment.prod)
  @singleton
  DriftStorageStatus driftStorageStatus() => DriftStorageStatus();

  /// Le domaine ne voit que le port.
  @Environment(Environment.prod)
  @singleton
  StorageStatus storageStatus(DriftStorageStatus status) => status;

  @preResolve
  @Environment(Environment.prod)
  @Singleton(dispose: closeAppDatabase)
  Future<AppDatabase> appDatabase(
    DatabaseSettings settings,
    DriftStorageStatus status,
  ) async {
    final database = openAppDatabase(status: status, settings: settings);
    // Force l'ouverture : migrations jouées et choix du stockage web connu.
    await database.customSelect('SELECT 1').get();
    return database;
  }
}

Future<void> closeAppDatabase(AppDatabase database) => database.close();
