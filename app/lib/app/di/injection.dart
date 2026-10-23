import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/di/injection.config.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

final GetIt getIt = GetIt.instance;

/// Compose le graphe de dépendances.
///
/// [environment] : `prod` (SQLite drift, identifiants UUID) ou `test`
/// (dépôts en mémoire, identifiants séquentiels). [settings] : emplacement de
/// la base en production (surchargé par les tests d'intégration).
/// [backend] : le backend des données du club ; sans valeur, le réglage du
/// build (`DATA_BACKEND`, défaut Firestore). [localData] : le relevé de la
/// base locale pris **avant** son ouverture (FB7c, `probeLocalStore`) ; sans
/// relevé, aucune donnée locale.
@InjectableInit(
  ignoreUnregisteredTypes: [
    DatabaseSettings,
    LocalDataInventory,
    DataBackendRequest,
  ],
)
Future<void> configureDependencies({
  String environment = Environment.prod,
  DatabaseSettings settings = const DatabaseSettings(),
  LocalDataInventory localData = LocalDataInventory.none,
  DataBackend? backend,
}) async {
  getIt
    ..registerSingleton<DataBackendRequest>(DataBackendRequest(backend))
    ..registerSingleton<DatabaseSettings>(settings)
    ..registerSingleton<LocalDataInventory>(localData);
  await getIt.init(environment: environment);
}
